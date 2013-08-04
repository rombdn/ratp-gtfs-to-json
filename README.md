ratp-gtfs-to-json
==================

Create a JSON graph from RATP open data (http://data.ratp.fr/fr/les-donnees/fiche-de-jeu-de-donnees/dataset/offre-transport-de-la-ratp-format-gtfs.html)

This graph is the base for fxos-metrobusparis (http://github.com/rombdn/fxos-metrobusparis)


Data Overview
---------------

The goal of these scripts is to parse the GTFS files to create a Graph usable to find shortest paths

The GTFS structure is :

Line X directory

| routes.txt        | trips.txt | stop_times.txt | stops.txt     |
| ----------------- | --------- | -------------- | ------------- |  
| route_id          | route_id  | stop_id        | stop_id       |   
| trip_id           | trip_id   | trip_id        | stop_name     |
| type              |           |                |               |          
| line (directory)  |			|			     |				 |
   
   
And the output is :
{
	<stop_id>: {
		name: <name>,
		loc: {
			lat: <latitude>,
			lon: <longitude>
		}
		zip: <zipcode>,
		edges: [
			{
				"dest": <dest_stop_id>,
				"dur": <edge_duration>,
				"type": <edge_type>,
				"open": <hour_of_opening>,
				"close": <hour_of_closing>,
				"line": <line_number>,
				"dir": <line_direction>,
				"freq": <average_frequency>
			}
		]
	}
}

You can see the full RATP GTFS description in the PDF file in the page linked above (direct link: http://data.ratp.fr/?eID=ics_od_datastoredownload&file=88)



Scripts overview
---------------------


**create_raw_edges.c**

Crunch all the stops informations from stop_times.txt (> 600MB, millions of lines) and output edges with average duration, frequency and open hours


**create_graph.rb**

Create graph nodes by browsing GTFS lines directories to get line informations (line name, directions...) and parse the output of `create_raw_edges.c` above to create final graph

The stops (stations) with identical names are merged to reduce graph size because in the original GTFS files there is one stop_id per line per direction.

See comments in the scripts for further explanations.