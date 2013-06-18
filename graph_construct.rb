
#route e.g: 795705,100,"8","(BALARD <-> POINTE DU LAC) - Aller",,1,,FFFFFF,000000

def get_routes(line_dir)
    routes = {}

    IO.foreach("#{line_dir}/routes.txt").each_with_index do |route, index|
        next if index == 0

        sroute = route.split(',')
        id_ratp = sroute.at(0)
        line = sroute.at(2).gsub("\"", '').strip
        type = sroute.at(5).gsub("\"", '').strip

        routes[id_ratp] = {:line => line, :direction => direction, :type => type}
    end

    routes
end


def get_trips(path)
    route_trips = {}

    IO.foreach(path).each_with_index do |trip_line, index|
        next if index == 0

        trip_line_s = trip_line.split(',')
        route_id = trip_line_s.at(0)
        trip_id = trip_line_s.at(2)

        next if not route_trips[route_id].nil?

        route_trips[trip_id] = route_id
    end

    route_trips
end


def get_stop_times(path_stops, path_stop_times, trips)
    stop_times = {}
    nb_stops = 0

    IO.foreach(path_stops).each { |line| nb_stops += 1 }

    IO.foreach(path_stop_times).each_with_index do |stop_times_line, index|
        next if index == 0

        break if stop_times.length == nb_stops

        stl_s = stop_times_line.split(',')
        
        trip_id = stl_s.at(0)
        stop_id = stl_s.at(3)

        next if not stop_times[stop_id].nil?

        stop_times[stop_id] = trip_id
    end

    stop_times
end

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

        stops << {
            :id => id,
            :name => name,
            :lat => lat,
            :lon => lon,
            :lines => [],
            :type => "",
            :edges => {},
            :direction => "",
            :visited => 0
        }
    end

    #create the correspondence table
    #   group stops by name
    #   for each group create keep only the first element as reference id
    #   in the form { :id1 => id1, :id2 => id1, :id3 => id1, ...}
    #   e.g {"2399"=>"2399", "1789"=>"2399"}
    #   result is the final table
    #   e.g "2399"=>"2399", "1789"=>"2399", "2339"=>"2339", "1834"=>"2339", ...
    stops_id_table = stops.group_by { |stop| 
        stop[:name] 
    }.inject({}) { |result, (_, group_for_a_name)|
        group_for_a_name.each { |sub_stop|
            result[sub_stop[:id]] = group_for_a_name.first[:id]
        }
        result
    }

    stops_by_id = Hash[ stops.map { |stop| [stop[:id] , stop] } ]

    return stops_by_id, stops_id_table
end






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
                \"lat\": \"#{node[:lat]}\",
                \"lon\": \"#{node[:lon]}\"
            },
            \"line\": \"#{node[:line]}\",
            \"type\": \"#{node[:type]}\",
            \"dir:\": \"#{node[:direction]}\",
            \"edges\": [
                "
        node[:edges].each_with_index { |(dest_id, edge), index|
            output += "," if index > 0
            output +=
                "{
                    \"dest\": \"#{dest_id}\",
                    \"dur\": \"#{edge[:duration]}\",
                    \"begin\": \"#{edge[:begin_time]}\",
                    \"end\": \"#{edge[:end_time]}\",
                    \"type\": \"#{edge[:type]}\"
                }
                "
        }

        output +=
            "]
        }"

        fout.puts(output)
    }
    fout.puts("}")
    fout.close
end


def get_stops_for_line(line_dir)
    routes  = {}
    trips   = {}
    nb_stops_for_line = 0
    stops_current_line = {}

    #routes
    IO.foreach("#{line_dir}/routes.txt").each_with_index do |route_line, index|
        next if index == 0
        route_line = route_line.split(',')
        
        r_id            = route_line.at(0)
        r_line          = route_line.at(2).gsub("\"", '').strip
        r_type          = route_line.at(5).gsub("\"", '').strip
        routes[r_id]    = {:line => r_line, :type => r_type}
    end

    #puts routes
    #puts " "

    #trips
    routes_id = routes.keys
    IO.foreach("#{line_dir}/trips.txt").each_with_index do |trip_line, index|
        next if index == 0
        break if routes_id.length == 0
        trip_line = trip_line.split(',')
        
        trip_route_id   = trip_line.at(0)
        trip_id         = trip_line.at(2)
        
        trips[trip_id] = routes[trip_route_id]
    end

    #stop_times
    IO.foreach("#{line_dir}/stops.txt").each { |line| nb_stops_for_line += 1 }
    nb_stops_for_line -= 1

    IO.foreach("#{line_dir}/stop_times.txt").each_with_index do |stop_line, index|
        next if index == 0
        break if stops_current_line.length == nb_stops_for_line
        stop_line = stop_line.split(',')
        
        stop_trip_id    = stop_line.at(0)
        stop_id         = stop_line.at(3)

        stops_current_line[stop_id] = trips[stop_trip_id] if stops_current_line[stop_id].nil?
    end    

    stops_current_line
end



def add_routes_infos_to_stops!(params)
    root_path_line  = params[:ratp_gtfs_line_path]
    stops           = params[:stops]
    stops_id_table  = params[:stops_id_table]

    #for each line get their belonging stops then add their infos the global stops hash
    Dir.glob("#{root_path_line}/*").each do |line_dir|
        puts "#{line_dir}"

        get_stops_for_line(line_dir).each do |stop_current_line_k, stop_current_line_v|
            corresp_id = stops_id_table[stop_current_line_k]
            if stop_current_line_v.nil?
                puts stop_current_line_k
                puts stop_current_line_v
                puts "#{stop_current_line_k} -> #{corresp_id} unknown"
            end
            stops[corresp_id][:lines].push(stop_current_line_v[:line]).uniq!
            stops[corresp_id][:type] = stop_current_line_v[:type]
        end
    end
end


def parse_edges(params)
    graph = params[:stops]
    stops_id_table = params[:stops_id_table]

    IO.foreach(params[:edges_path]).each_with_index do |line, line_index|
        line = line.split(',')
        
        from_stop_id    = line.at(0)
        to_stop_id      = line.at(1)
        duration        = line.at(2)
        begin_time      = line.at(3)
        end_time        = line.at(4)
        edge_type       = line.at(5).strip #transfer or not

        #transpose ids
        corresp_from_id = stops_id_table[from_stop_id]
        corresp_to_id   = stops_id_table[to_stop_id]

        #edge between two merged nodes
        next if corresp_from_id == corresp_to_id

        node = graph[corresp_from_id]
        edge = graph[corresp_from_id][:edges][corresp_to_id]

        #edge type in edges.txt is not the same as route/stop type...
        if( edge_type == "2" ) #walk
            edge_type = 4
        else
            edge_type = node[:type] #metro, RER or BUS
        end

        #because we have merged nodes with the same name
        #there are multiple redondants edges...
        #keep only the shortest (by walk)
        if (edge.nil?) or (duration.to_i < edge[:duration].to_i and edge_type == 4)
            graph[corresp_from_id][:edges][corresp_to_id] = {
                :duration   => duration,
                :begin_time => begin_time,
                :end_time   => end_time,
                :type       => edge_type
            }
        end
        '
        else
            #keep the shortest edge
            if graph[from_r][:edges][to_r][:duration].to_i > duration.to_i
                    graph[from_r][:edges][to_r] = {
                    :duration => duration,
                    :begin_time => begin_time,
                    :end_time => end_time,
                    :type => edge_type
                }
            end
        end
        '
    end
    
    graph
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


#model :
# stops = { "id1" => { :name => "", :type => "", ...}}, "id2" => {...}, ... }
# stops_id_map = { "id2" => "id1", "id3" => "id1" } == 
# when graph is created all stop_id are transposed using stops_id_table
# graph = stops
# node: stops[:id]
# edge: node[:edges][:dest_node_id]
# next node: graph[ node[ :edges[:dest_node_id] ] ]

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




# Add infos from routes (line, direction, type) to the stops (nodes)
# => Join routes.txt, trips.txt and stop_times.txt then join stop_times with the stops
#puts "Add routes infos to stops (line, type, direction)"


#puts "Recherche des stops sans ligne"
#puts stops.select { |key, stop| stop[:line] == 0 }.length


#puts " "
#puts "Create Graph"
#graph = create_graph("#{ARGV[2]}", stops)
puts graph["3663696"]

puts " "
puts "Output graph in file #{ARGV[3]}"
#output_graph(ARGV[3], graph)



puts " "
puts "Demo"


start = graph["2390"]
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
    
    q += node[:edges].keys.select { |dest_id| 
        graph[dest_id][:type] == "1" and graph[dest_id][:visited] != 1
    }.map { |dest_id| 
        graph[dest_id]
    }
    p q.length
end
