
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


def get_stops_all(path)
    stops = {}
    IO.foreach(path).each_with_index do |line, line_index|
        #e.g 2251,,"Dupleix","Grenelle (terre-plein face au 65/68 boulevard de) - 75115",48.850742650180216,2.292463226824505,0,
        next if line_index == 0

        stop_id = line.match(/^[0-9]+/)[0]
        name = line.match(/,,"([^"]+)"/)[1]
        lat = line.match(/4[0-9]\.[0-9]+/)[0]
        lon = line.match(/2\.[0-9]+/)[0]

        stops[stop_id] = {
            :name => name,
            :lat => lat,
            :lon => lon,
            :line => 0,
            :type => 0,
            :edges => [],
            :direction => ""
        }
    end
    stops
end


def create_graph(path, stops)
    graph = stops

    IO.foreach(path).each_with_index do |line, line_index|
        next if line_index == 0

        line = line.split(',')
        from = line.at(0)
        to = line.at(1)
        duration = line.at(2)
        begin_time = line.at(3)
        end_time = line.at(4)
        type = line.at(5)

        graph[from][:edges].push({
            :dest_id => to,
            :duration => duration,
            :begin_time => begin_time,
            :end_time => end_time,
            :type => type
        })
    end
    
    graph
end


def output_graph(path, graph)
    fout = File.open(path, 'w')

    fout.puts("{")
    graph.each { |key, node|
        output = "
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
        node[:edges].each { |edge|
            output +=
                "{
                    \"dest\": \"#{edge[:dest_id]}\",
                    \"dur\": \"#{edge[:duration]}\",
                    \"begin\": \"#{edge[:begin]}\",
                    \"end\": \"#{edge[:end]}\",
                    \"type\": \"#{edge[:type]}\"
                },
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


if ARGV.length < 4
    puts "Usage cmd <RATP_GTFS_LINES> <RATP_GTFS_FULL> <edges.txt> <output.json>"
    exit
end

if not File.directory?("#{ARGV[0]}")
    puts "Unable to open #{ARGV[0]}"
    exit
end

puts "Get all stops"
stops_full = get_stops_all("#{ARGV[1]}/stops.txt")

Dir.glob("#{ARGV[0]}/*").each  { |line_dir|
    puts "#{line_dir}"

    puts "Get routes"
    routes = get_routes("#{line_dir}/routes.txt")

    puts "Get trips"
    trips = get_trips("#{line_dir}/trips.txt")

    puts "Get stop_times"
    stop_times = get_stop_times("#{line_dir}/stops.txt", "#{line_dir}/stop_times.txt", trips)

    puts "Number of stops : #{stop_times.length}"

    stop_times.each { |stop_id, trip_id|
        if stops_full[stop_id].nil?
            puts "ERROR: stop #{stop_id} not in stops_full"
            exit
        end

        stops_full[stop_id][:line] = routes[trips[trip_id]][:line]
        stops_full[stop_id][:type] = routes[trips[trip_id]][:type]
        stops_full[stop_id][:direction] = routes[trips[trip_id]][:direction]
    }
    
    puts " "
}

puts "Recherche des stops sans ligne"
puts stops_full.select { |key, stop| stop[:line] == 0 }.length


puts " "
puts "Create Graph"
graph = create_graph("#{ARGV[2]}", stops_full)


puts " "
puts "Output graph in file #{ARGV[3]}"
output_graph(ARGV[3], graph)






puts " "
puts "Demo"

types = {
    "1" => "Metro",
    "2" => "Bus"
}
'
graph.each { |k, v|
    #puts "line"
    next if v[:line] != "6"

    puts "Ligne #{v[:line]}"
    puts "Station #{v[:name]}"
    puts "Stations accessibles :"

    v[:edges].each { |edge|
        to = edge[:dest_id]
        puts "#{graph[to][:name]}, ligne #{graph[to][:line]}, #{types[graph[to][:type]]}, duree: #{edge[:duration]}"
    }

    puts " "
}
'


start = graph["2390"]
q = []
puts "Ligne #{start[:line]}"
puts "Parcours"
node = start
while not node.nil?
    puts "Station #{node[:name]}"
    next_node = node[:edges].map { |edge| graph[edge[:dest_id]] if graph[edge[:dest_id]][:line] == "6" }.first
    q.push(next_node)
    node = q.pop
    #q.push node[:edges].select { |k, edge| graph[edge[:dest_id]][:line] == "6" }.first
end
