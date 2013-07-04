######
# 
# Create a graph in the form of an adjacency list using `RATP_GTFS_FULL/stops.txt` as nodes,
#   output of `create_raw_edges` as edges and RATP_GTFS_LINE/* to provide further informations to nodes/stops
# More details below and on http://github.com/rombdn/ratp-gtfs-to-json
#
# (c) 2013 Romain BEAUDON
# This code may be freely distributed under the terms of the GNU General Public License
######

# `read_stops`
# -------------------
# Read the stops (our future nodes) from stops.txt to a hash {:stop_id => {:name, :type...}}
# We have multiple stops with the same name (one per line per direction)
# so we create a table that map stop_ids for stops with the same name to a unique reference stop_id for each name (table[stop_id] = refence stop_id)
#       then we always use this table for future references to the stop_id (stops[stop_id] but stops[ table[stop_id] ])
#       example for { "2098" => { :name => "picpus"}, "1789" => { :name => "picpus"}} 
#           the table will be { "2098" => "1789", "1789" => "1789"}
#           whenever we encounter "2098" the stop "1789" will be accessed ( stops[table["2098"]] === stops["1789"])


# `add_routes_infos_to_stops`
# there is no info about line, type or direction for stop_id in stops.txt
# so let's join routes.txt, trips.txt and stop_times.txt for each line and add these infos to the stops hash
#
#                           Line X directory
# -------------------------------------------------------------
#     routes                       trips            stop_times       **stops hash** 
#   ---------------------       -------------     -------------      -------------   
#   | route_id          |       | route_id  |     | stop_id   |  <-> | stop_id   |   
#   | trip_id           |  <->  | trip_id   | <-> | trip_id   |      | line?     |
#   | type              |                                            | type?     |
#   | line (directory)  |                    
#
# one little trick is to add the line info both in the reference and other stops because we will need it when creating edges


# `parse_edges`
# Create the graph by parsing edges.txt
# For each edge encountered create a node for the current (mapped) from_stop_id if it doesn't exist
# Then create an edge to the stop with id (mapped) to_stop_id
# Because we use mapped ids multiple stops are reduced to one, leading to redundant edges
# I made the choice to only keep the shortest edge...
# Because we have only one stop for multiple lines (consequence of the merge) we must add the line info (:orig_line) to the edges


# variables :
#  - stops = { "id1" => { :name => "", :type => "", ...}}, "id2" => {...}, ... }
#  - stops_id_map = { "id2" => "id1", "id3" => "id1" } == 
#  - graph = stops infos + edges hash
#  - node: stops[:id]
#  - edge: node[:edges][:dest_node_id]
# next node: graph[ node[ :edges[:dest_node_id] ] ]



##
# read_stops
#
# => returns the stops list and a correspondence table between :stops_id => reference stop_id (one by name)
#   correspondence table example : "2399"=>"2399", "1789"=>"2399", "2339"=>"2339", "1834"=>"2339", ...
##
def read_stops(params)
    stops = []
    stops_by_id = {}
    stops_id_table = {} #keys: all stop_ids, values: reference id (one by name)

    IO.foreach("#{params[:ratp_gtfs_full_path]}/stops.txt").each_with_index do |line, line_index|
        #e.g 2251,,"Dupleix","Grenelle (terre-plein face au 65/68 boulevard de) - 75115",48.850742650180216,2.292463226824505,0,
        next if line_index == 0

        id      = line.match(/^[0-9]+/)[0]
        name    = line.match(/,,"([^"]+)"/)[1]
        lat     = line.match(/4[0-9]\.[0-9]+/)[0]
        lon     = line.match(/2\.[0-9]+/)[0]
        zip     = line.match(/- ([0-9]{5})"/)[1]
        addr    = line.match(/"([^"]+ - [0-9]+)",/)[1]

        stops << {
            :id => id,
            :name => name,
            :lat => lat,
            :lon => lon,
            :lines => [],
            :type => 0,
            :orig_line => "",
            :zip => zip,
            :addr => addr
        }
    end

    #create the correspondence table
    #   group stops by name
    #   for each group keep only the first element as reference id
    #   in the form { :id1 => id1, :id2 => id1, :id3 => id1, ...}
    #   e.g "2399"=>"2399", "1789"=>"2399", "2339"=>"2339", "1834"=>"2339", ...
    stops_id_table = stops.group_by { |stop| 
        stop[:name] + stop[:zip]
    }.inject({}) { |result, (_, group_for_a_name)|
        group_for_a_name.each { |sub_stop|
            result[sub_stop[:id]] = group_for_a_name.first[:id]
        }
        result
    }

    #transform stops array [{:id, :name, :type}, {:id2...}] to a hash {:id => {:name, :type...}, :id2 =>...}
    stops_by_id = Hash[ stops.map { |stop| [stop[:id] , stop] } ]

    return stops_by_id, stops_id_table
end

##
# get_stops_for_line
##
def get_stops_for_line(line_dir)
    routes  = {}
    trips   = {}
    nb_stops_for_line = 0
    stops_for_this_line = {}

    #routes
    IO.foreach("#{line_dir}/routes.txt").each_with_index do |route_line, index|
        next if index == 0
        route_line = route_line.split(',')
        
        r_id            = route_line.at(0)
        r_line          = route_line.at(2).gsub("\"", '').strip
        r_type          = route_line.at(5).gsub("\"", '').strip
        routes[r_id]    = {:line => r_line, :type => r_type}
    end

    #trips
    IO.foreach("#{line_dir}/trips.txt").each_with_index do |trip_line, index|
        next if index == 0
        trip_line = trip_line.split(',')
        
        trip_route_id   = trip_line.at(0)
        trip_id         = trip_line.at(2)
        
        trips[trip_id] = routes[trip_route_id]
    end

    #stop_times
    IO.foreach("#{line_dir}/stops.txt").each { |line| nb_stops_for_line += 1 }
    nb_stops_for_line -= 1 #little hack to break next loop as soon as we got infos for each stop

    IO.foreach("#{line_dir}/stop_times.txt").each_with_index do |stop_line, index|
        next if index == 0
        break if stops_for_this_line.length == nb_stops_for_line
        stop_line = stop_line.split(',')
        
        stop_trip_id    = stop_line.at(0)
        stop_id         = stop_line.at(3)

        stops_for_this_line[stop_id] = trips[stop_trip_id] if stops_for_this_line[stop_id].nil?
    end

    stops_for_this_line
end


##
# add_routes_infos_to_stops
##
def add_routes_infos_to_stops!(params)
    root_path_line  = params[:ratp_gtfs_line_path]
    stops           = params[:stops]
    stops_id_table  = params[:stops_id_table]

    #for each line get their belonging stops then add their infos the global stops hash
    Dir.glob("#{root_path_line}/*").each do |line_dir|
        puts "#{line_dir}"

        get_stops_for_line(line_dir).each do |stop_current_line_k, stop_current_line_v|
            mapped_stop_id = stops_id_table[stop_current_line_k]
            if stop_current_line_v.nil?
                puts stop_current_line_k
                puts stop_current_line_v
                puts "#{stop_current_line_k} -> #{mapped_stop_id} unknown"
            end

            stops[mapped_stop_id][:lines].push(stop_current_line_v[:line]).uniq!
            stops[mapped_stop_id][:type] = stop_current_line_v[:type]
            stops[stop_current_line_k][:type] = stop_current_line_v[:type] #used for edges line
            stops[stop_current_line_k][:orig_line] = stop_current_line_v[:line] #used for edges line
        end
    end
end

##
# parse_edges
##
def parse_edges(params)
    stops = params[:stops]
    graph = {}
    stops_id_table = params[:stops_id_table]

    IO.foreach(params[:edges_path]).each_with_index do |line, line_index|
        line = line.split(',')
        
        from_stop_id    = line.at(0)
        to_stop_id      = line.at(1)
        duration        = line.at(2)
        begin_time      = line.at(3)
        end_time        = line.at(4)
        edge_type       = line.at(5).strip #transfer?

        #map ids
        mapped_from_stop_id = stops_id_table[from_stop_id]
        mapped_to_stop_id   = stops_id_table[to_stop_id]

        #create node
        if graph[mapped_from_stop_id].nil?
            graph[mapped_from_stop_id] = stops[mapped_from_stop_id]
            graph[mapped_from_stop_id][:edges] = {}
            graph[mapped_from_stop_id][:visited] = 0
        end

        #edge between two merged nodes
        next if mapped_from_stop_id == mapped_to_stop_id

        node = graph[mapped_from_stop_id]
        edge = graph[mapped_from_stop_id][:edges][mapped_to_stop_id]

        #edge type in edges.txt is not the same as route/stop type...
        if( edge_type == "2" ) #walk
            edge_type = 4
        else
            if stops[to_stop_id][:type] == ""
                puts "WARNING: TYPE empty for node #{stops[to_stop_id][:name]}, line #{stops[to_stop_id][:orig_line]}"
                stops[to_stop_id][:type] = 3 #BUS
            end
            edge_type = stops[to_stop_id][:type] #metro, RER or BUS
        end

        if edge_type == "0" and stops[to_stop_id][:orig_line].index('T') != 0 #type 0 but not tramway
            if graph[mapped_from_stop_id][:name].upcase == graph[mapped_from_stop_id][:name]
                edge_type = 3
            else
                edge_type = 1
            end
        end


        #because we have merged nodes with the same name
        #there are multiple redondants edges...
        #keep only the shortest (by walk)
'        
        if not edge.nil? and mapped_from_stop_id == "3716924"
            #puts edge
            puts ""
            puts ""
            puts "EDGE REDUNDANT"
            puts "Mapped: #{mapped_from_stop_id}->#{mapped_to_stop_id}"
            puts "New: #{from_stop_id}->#{to_stop_id}, type: #{edge_type}, line: #{stops[to_stop_id][:orig_line]}"
            puts ""
            puts ""
        end
'
        graph[mapped_from_stop_id][:edges][mapped_to_stop_id] = [] if edge.nil?

        if edge_type == 4
            result = graph[mapped_from_stop_id][:edges][mapped_to_stop_id].detect { |v|
                v[:type] == 4
            }

            if result.nil?
                graph[mapped_from_stop_id][:edges][mapped_to_stop_id] << {
                    :duration    => duration,
                    :begin_time  => begin_time,
                    :end_time    => end_time,
                    :type        => edge_type,
                    :line        => stops[to_stop_id][:orig_line]
                }
            end
        else
            result = graph[mapped_from_stop_id][:edges][mapped_to_stop_id].detect { |v|
                v[:type] == edge_type and v[:line] == stops[to_stop_id][:orig_line] 
            }

            if result.nil?
                graph[mapped_from_stop_id][:edges][mapped_to_stop_id] << {
                    :duration    => duration,
                    :begin_time  => begin_time,
                    :end_time    => end_time,
                    :type        => edge_type,
                    :line        => stops[to_stop_id][:orig_line]
                }
            end
        end



        #puts " "
        

        #if (edge.nil?) or (duration.to_i < edge[:duration].to_i and edge_type == 4)

'
        if from_stop_id == "3813090"
            puts "ORIG: #{from_stop_id} -> #{to_stop_id}"
            puts "NEW: #{mapped_from_stop_id} -> #{mapped_to_stop_id}"
            puts graph["3716924"]
            puts ""
            puts ""
        end
'
    end


    graph
end


##
# output_graph
##
def output_graph(path, graph)
    fout = File.open(path, 'w')

    fout.puts("{")
    graph.each_with_index { |(key, node), index_node|
        output = ""
        output += "," if index_node > 0
        output += "
        \"#{key}\": {
            \"name\": \"#{node[:name]}\",
            \"loc\": {
                \"lat\": #{node[:lat].to_f.round(5)},
                \"lon\": #{node[:lon].to_f.round(5)}
            },
            \"zip\": \"#{node[:zip]}\",
            \"edges\": [
                "
        node[:edges].each_with_index { |(dest_id, sub_edges), index|
            output += "," if index > 0
            
            sub_edges.each_with_index { |sub_edge, sub_index| 
                output += "," if sub_index > 0
                output +=
                    "   {
                        \"dest\": #{dest_id},
                        \"dur\": #{sub_edge[:duration]},
                        \"type\": #{sub_edge[:type]},
                        \"line\": \"#{sub_edge[:line]}\"
                    }
                    "                
            }
        }

        output +=
            "]
        }"

        fout.puts(output)
    }
    fout.puts("}")
    fout.close
end



###
# main
###

if ARGV.length < 4
    puts "Usage cmd <RATP_GTFS_LINES> <RATP_GTFS_FULL> <edges.txt> <output.json>"
    exit
end

if not File.directory?("#{ARGV[0]}")
    puts "Unable to open #{ARGV[0]}"
    exit
end


puts "Read stops file (nodes)"
stops, stops_id_table = read_stops(ratp_gtfs_full_path: ARGV[1], merge_names: true)

puts "Add routes infos to stops (line, type, direction)"
add_routes_infos_to_stops!(
    ratp_gtfs_full_path: ARGV[1],
    ratp_gtfs_line_path: ARGV[0], 
    stops: stops, 
    stops_id_table: stops_id_table)

puts "Create graph by parsing edges.txt file"
graph = parse_edges(edges_path: ARGV[2], stops: stops, stops_id_table: stops_id_table)


puts " "
puts "Output graph in file #{ARGV[3]}"
output_graph(ARGV[3], graph)


puts " "
puts "Demo"


start = graph["3716924"]
visited = {}
q = [start]
puts "Ligne #{start[:line]}"
puts "Parcours"
node = start

while not node.nil?
    node = q.shift
    next if node[:visited] == 1
    node[:visited] = 1
    
    puts "Station #{node[:name]}, lignes #{node[:lines]}"
    
    q += node[:edges].select { |dest_id, sub_edges| 
        sub_edges.detect { |v| v[:type] == "3" and graph[dest_id][:visited] != 1 and v[:line] == "87" }
    }.map { |dest_id, _| 
        graph[dest_id]
    }
    p q.length
end
