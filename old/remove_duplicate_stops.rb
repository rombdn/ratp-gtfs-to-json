if ARGV.length < 1
    p "Usage: #{$0} <stops.gtfs.txt> <edges.ratp.txt>"
end

stops = []

IO.foreach(ARGV[0]).each_with_index do |line, line_index|
    #e.g 2251,,"Dupleix","Grenelle (terre-plein face au 65/68 boulevard de) - 75115",48.850742650180216,2.292463226824505,0,
    next if line_index == 0
    stops.push({
        :ids => [line.match(/^[0-9]+/)[0]], 
        :name => line.match(/,,"([^"]+)"/)[1], 
        :lat => line.match(/4[0-9]\.[0-9]+/)[0], 
        :lon => line.match(/2\.[0-9]+/)[0]
    })
end

#remove duplicates while keeping their id =
#group the stops by name, e.g {:name => [{:ids, :name, :lat..},{:ids..}]}, {:name =>[{},{}]}
#for each array of duplicates keep only one element containing other's id
stops = stops.group_by { |s| 
    s[:name]
}.map { |k, v|
    #v is the array of duplicates for each name, e.g [{:ids, :name, :lat..},{:ids, :name..}]
    #we only keep {:ids, :name, :lat..} with all ids
    v.inject { |memo, stop| 
        stop[:ids] += memo[:ids]
        stop 
    }

    #same as
    #ids = v.map { |stop| stop[:ids].first }
    #v.first[:ids] = ids
    #v.first
}


conversion_table = stops.collect { |stop| 
    stop[:ids]
}.flat_map { |ids|
    ids.map { |id|
        Hash[id, ids.first]
    }
}


stops_hash = stops.map { |stop| 
    Hash[stop[:ids].first, stop]
}