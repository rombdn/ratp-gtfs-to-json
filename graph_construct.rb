
#route e.g: 795705,100,"8","(BALARD <-> POINTE DU LAC) - Aller",,1,,FFFFFF,000000

def get_routes(path)
    routes = {}

    IO.foreach(path).each_with_index do |route, index|
        next if index == 0

        sroute = route.split(',')

        #*id_ratp*
        id_ratp = sroute.at(0)

        #*line*
        line = sroute.at(2).gsub("\"", '').strip

        #*type*
        type = sroute.at(5).gsub("\"", '').strip

        #*direction*
        direction = sroute.at(3) #"(BALARD <-> POINTE DU LAC) - Aller"
                    .gsub(/[()]| - Aller| - Retour|\"/, '') #BALARD <-> POINTE DU LAC
                    .split('<->')
        if direction.length > 1 #not in case of "(OPERA) - Retour"
            direction = direction.reject.each_with_index do 
                |s, i| route.rindex('Retour') ? i == 1 : i == 0
            end  #POINTE DU LAC for 'Aller', BALARD for 'Retour'
        end
        direction = direction.first.strip

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


def get_stops_all(path, merge = false)
    stops = {}
    stops[:map] = {}
    ids_by_name = {} #:name => id
    ids_map = {} #:id of a duplicate element => id of reference element

    IO.foreach(path).each_with_index do |line, line_index|
        #e.g 2251,,"Dupleix","Grenelle (terre-plein face au 65/68 boulevard de) - 75115",48.850742650180216,2.292463226824505,0,
        next if line_index == 0

        stop_id = line.match(/^[0-9]+/)[0]
        name = line.match(/,,"([^"]+)"/)[1]
        lat = line.match(/4[0-9]\.[0-9]+/)[0]
        lon = line.match(/2\.[0-9]+/)[0]


        if ids_by_name[name].nil?
            ids_by_name[name] = stop_id
            stops[stop_id] = {
                :name => name,
                :lat => lat,
                :lon => lon,
                :line => 0,
                :type => 0,
                :edges => {},
                :direction => "",
                :visited => 0
            }
        end

        stops[:map][stop_id] = ids_by_name[name]


 
    end
    
    stops
end


def r_stops_delete_duplicate_names!(stops)
    stops.inject({}) { |result, (_, v)|
        if result[v[:name]].nil?
            result[v[:name]] = v
        else
            v = result[v[:name]]
        end

        result
    }
end


def create_graph(path, stops)
    graph = stops.reject { |k, v| k == :map }

    IO.foreach(path).each_with_index do |line, line_index|
        #next if line_index == 0

        line = line.split(',')
        from = line.at(0)
        to = line.at(1)
        duration = line.at(2)
        begin_time = line.at(3)
        end_time = line.at(4)
        type = line.at(5).strip

        from_r = stops[:map][from]
        to_r = stops[:map][to]

        next if from_r == to_r

        if graph[from_r][:edges][to_r].nil?
            graph[from_r][:edges][to_r] = {
                :duration => duration,
                :begin_time => begin_time,
                :end_time => end_time,
                :type => graph[from_r][:type]
            }
        else
            #keep the shortest edge
            if graph[from_r][:edges][to_r][:duration].to_i > duration.to_i
                    graph[from_r][:edges][to_r] = {
                    :duration => duration,
                    :begin_time => begin_time,
                    :end_time => end_time,
                    :type => graph[from_r][:type]
                }
            end
        end
    end
    
    graph
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


puts "Get all stops (nodes)"
stops = get_stops_all("#{ARGV[1]}/stops.txt", true)
#r_stops_delete_duplicate_names!(stops)

# Add infos from routes (line, direction, type) to the stops (nodes)
# => Join routes.txt, trips.txt and stop_times.txt then join stop_times with the stops
puts "Add routes infos to stops (line, type, direction)"
Dir.glob("#{ARGV[0]}/*").each  { |line_dir|
    puts "#{line_dir}"

    #puts "Get routes"
    routes = get_routes("#{line_dir}/routes.txt")

    #puts "Get trips"
    trip_id_to_routes_id = get_trips("#{line_dir}/trips.txt")

    #puts "Get stop_times"
    stop_times = get_stop_times("#{line_dir}/stops.txt", "#{line_dir}/stop_times.txt", trip_id_to_routes_id)

    #puts "Number of stops : #{stop_times.length}"

    stop_times.each { |stop_id, trip_id|
        if stops[:map][stop_id].nil?
            puts "ERROR: stop #{stop_id} not in stops_full"
            exit
        end

        stops[stops[:map][stop_id]][:line] = routes[trip_id_to_routes_id[trip_id]][:line]
        stops[stops[:map][stop_id]][:type] = routes[trip_id_to_routes_id[trip_id]][:type]
        stops[stops[:map][stop_id]][:direction] = routes[trip_id_to_routes_id[trip_id]][:direction]
    }
    
    #puts " "
}

puts "Recherche des stops sans ligne"
puts stops.select { |key, stop| stop[:line] == 0 }.length


puts " "
puts "Create Graph"
graph = create_graph("#{ARGV[2]}", stops)
puts graph["4025444"]

puts " "
puts "Output graph in file #{ARGV[3]}"
output_graph(ARGV[3], graph)



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
    
    puts "Station #{node[:name]}, ligne #{node[:line]}"
    
    q += node[:edges].keys.select { |dest_id| 
        graph[dest_id][:type] == "1" and graph[dest_id][:visited] != 1
    }.map { |dest_id| 
        graph[dest_id]
    }
    p q.length
end
