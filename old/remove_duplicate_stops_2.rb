if ARGV.length < 2
    p "Usage: #{$0} <RATP_GTFS_stops.txt> <edges.ratp.txt>"
end

stops = {}
ids_to_replace = {}
ids_found = {}

#for each line of the file
#get fields
#check if name is a duplicate
#if no then add the item
#if yes then add its id to the ids to be replaced table
IO.foreach(ARGV[0]).each_with_index do |line, line_index|
    #e.g 2251,,"Dupleix","Grenelle (terre-plein face au 65/68 boulevard de) - 75115",48.850742650180216,2.292463226824505,0,
    next if line_index == 0

    id = line.match(/^[0-9]+/)[0]
    name = line.match(/,,"([^"]+)"/)[1]
    lat = line.match(/4[0-9]\.[0-9]+/)[0]
    lon = line.match(/2\.[0-9]+/)[0]

    #if its the first time we ecounter name
    if ids_found[name].nil?
        ids_found[name] = id
        stops[line.match(/^[0-9]+/)[0]] = {
            :id => id,
            :name => name,
            :lat => lat,
            :lon => lon
        }        
    #else if name was already encountered
    else
        ids_to_replace[id] = ids_found[name]      
    end
    
end


puts stops.length
#replace edges





#create graph