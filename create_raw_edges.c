/*
=================================
Parse `RATP_GTFS_FULL/stop_times.txt` and `RATP_GTFS_FULL/transfers.txt`
Output raw edges, one by line (from_stop_id, to_stop_id, average duration, begin_time, end_time)
More details on http://github.com/rombdn/ratp-gtfs-to-json

@param char* path_to_RATP_GTFS_FULL_directory


(c) 2013 Romain BEAUDON
This code may be freely distributed under the terms of the GNU General Public License
=================================
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "r_hashtable.h"

//10,000,000 buckets minimize collisions
//and is not too memory heavy (sizeof(bucket) = 4 Bytes (pointer))
//10,000,000 * 4 (or 8 in 64bits) => around 40MB (resp. 80MB)
#define HASHTABLE_SIZE 10000000

/*
=================================
edge structure
=================================
*/

typedef struct r_edge {
    int to_stop_id;
    int from_stop_id;
    int duration;
    int debut;
	int last_encounter;
	int encounters_avg;
	int encounters;
    int end;
    int counter;
    int type;
} r_edge;

enum edge_type { 
    METRO = 1,
    CORRESPONDANCE = 2
} edge_type;

/*
==================================
*/
/*
void    r_init_edges            (edge *edges, int max);
int     r_get_index             (edge *edges, cmph_t* hash, int from_stop_id, int to_stop_id);
int     r_create_edge           (edge *edges, int from_stop_id, int to_stop_id, int last_index, int max_index);
void    r_update_edge           (edge *edges, int edge_index, int from_stop_id, int to_stop_id, int type, int start_time, int end_time);
int     r_parse_stop_times_file (char *path, edge *edges, int last_index, int max_index);
int     r_parse_transfers_file  (char *path, edge *edges, int last_index, int max_index);
void    r_print_edges           (edge *edges, int max);
*/
/*
==================================
*/

/*
=============
r_open_file
=============
*/
FILE* r_open_file(char *path, char *mode)
{
    FILE *file = fopen(path, mode);
    if(!file) {
        printf("Unable to open %s\n", path);
        exit(1);
    }
    return file;
}


/*
=============
r_create_edge
=============
*/
r_edge* r_create_edge(int from_stop_id, int to_stop_id, int type)
{    
    r_edge *new = malloc( sizeof(r_edge) );
/*
    if(from_stop_id == 0) {
        fprintf(stderr, "ERROR in r_create_edge: 0 -> : %d\n", to_stop_id);
    }
*/
    new->from_stop_id   = from_stop_id;
    new->to_stop_id     = to_stop_id;
    new->type           = type;
    new->duration       = 0;
    new->counter        = 0;
    new->debut          = 3600*24;
    new->end            = 0;
	new->last_encounter = 0;
	new->encounters		= 0;
	new->encounters_avg = 0;

    return new;
}


/*
=============
r_update_edge
=============
*/
void r_update_edge(r_edge *edge, int start_time, int end_time)
{        
    int delta = 0;
	int temp = 0;
    //used for averaging durations at the end
    edge->counter += 1;
    
    delta = end_time - start_time;

    if(delta <= 0) delta = 60;

    edge->duration += delta;

    if(edge->type == METRO) {
        if(edge->debut > end_time && end_time > 3*3600) 
            edge->debut = end_time;

        if(edge->end < end_time)
            edge->end = end_time;        
    }
    else {
        edge->debut = 0;
        edge->end = 25*3600;
    }
	
	if(edge->last_encounter != 0)
	{
		if(edge->last_encounter < start_time)
		{
			temp = /*abs*/(start_time - edge->last_encounter);
			if(temp < 1200 && temp > 20)
			{
				edge->encounters_avg += temp;
				edge->encounters += 1;
			}
		}

		edge->last_encounter = start_time;
	}
	else
	{
		edge->last_encounter = start_time;
	}
}


/*
=============
r_parse_stop_times_file
=============
*/
void r_parse_stop_times_file(char *path, r_hashtable *edges_table)
{
    int i = 0, j = 0;   
    r_edge *edge = NULL;
    char key[20];

    //file reading buffers
    FILE *fin = NULL;
    char buffer_line[1024];
    char *pch = NULL;

    //inputs buffers
    char trip_id[255];
    int to_stop_id = 0, from_stop_id = 0;
    int dep_time = 0, last_dep_time = 0;


    fin = r_open_file(path, "r");

    fgets(buffer_line, sizeof(buffer_line), fin); //pass header


    //for each line in the file
    //if a new trip starts set everything to 0
    //get dep_time and stop_id fields
    //find the corresponding edge in the edges array with from_stop_id+to_stop_id key
    //update it or create it if it was not found
    while(fgets(buffer_line, sizeof(buffer_line), fin) != NULL)
    {
        pch = strtok(buffer_line, ",");

        //new trip begins
        if(strcmp(trip_id, pch) != 0)
        {
            strcpy(trip_id, pch);
            dep_time = 0;
            to_stop_id = 0;
            last_dep_time = 0;
            from_stop_id = 0;
        }

        //get dep_time and stop_id fields
        //get edge_index from the stop_id and from_stop_id found
        for(i=0; pch = strtok(NULL, ","); i++)
        {
            //departure_time
            if(i == 1) {
                last_dep_time = dep_time;
                dep_time = atoi(&pch[0])*3600+atoi(&pch[3])*60; //HH*3600 + MM*60
            }

            //stop_id
            if(i == 2)
            {
                from_stop_id = to_stop_id;
                to_stop_id = atoi(pch);
            }
        }

        sprintf(key, "%d%d", from_stop_id, to_stop_id);
        if( (edge = r_hash_get(edges_table, key)) == NULL )
        {
            edge = r_create_edge(from_stop_id, to_stop_id, METRO);
            r_hash_add(edges_table, edge, key);
        }
        //todo: test removing else
        //if(last_dep_time != 0)
        {
            r_update_edge( edge, last_dep_time, dep_time );
        }

    }

    fclose(fin);
}


/*
=============
r_parse_transfers_file

pretty straightforward because
origin and dest are on the same line
we just add an edge for each line
=============
*/
void r_parse_transfers_file(char *path, r_hashtable *edges_table)
{
    int i = 0;   
    r_edge *edge = NULL;
    char key[20];

    //file reading buffers
    FILE *fin = NULL;
    char buffer_line[1024];
    char *pch = NULL;

    int from_stop_id = 0, to_stop_id = 0, duration = 0;


    fin = r_open_file(path, "r");

    fgets(buffer_line, sizeof(buffer_line), fin);

    while(fgets(buffer_line, sizeof(buffer_line), fin) != NULL)
    {
        pch = strtok(buffer_line, ",");

        from_stop_id = atoi(pch);

        for(i=0; pch = strtok(NULL, ","); i++)
        {
            if(i == 0) { to_stop_id = atoi(pch); }
            if(i == 2) { duration = atoi(pch); }
        }

        sprintf(key, "%d%d", from_stop_id, to_stop_id);

        edge = r_create_edge(from_stop_id, to_stop_id, CORRESPONDANCE);
        r_hash_add(edges_table, edge, key);
        r_update_edge( edge, 0, duration );
    }

    fclose(fin);
}


/*
=============
r_print_edge
=============
*/
void r_print_edge(void *edge)
{
    int counter = 0;
    int average_duration = 0;
    int start_time = 0;
    int end_time = 0;

    if(edge == NULL) {
        fprintf(stderr, "ERROR in r_print_edge: edge to be printed is NULL\n");
        exit(1);
    }

    if( ((r_edge *)edge)->from_stop_id == 0 ) {
        return;
    }

    counter = ((r_edge *)edge)->counter;
    if( counter > 0 ) {
        average_duration = (((r_edge *)edge)->duration) / counter;
        /*
        if(average_duration < 60) {
            fprintf(stderr, "WARNING: duration: %d, counter: %d for edge %d->%d\n", 
                ((r_edge *)edge)->duration, 
                counter,
                ((r_edge *)edge)->from_stop_id,
                ((r_edge *)edge)->to_stop_id);
            average_duration = 60;
        }*/
    }
    else {
        average_duration = 60;
    }

    start_time = ((r_edge *)edge)->debut;
    end_time = ((r_edge *)edge)->end;

    printf("%d,%d,%d,%dh%d,%dh%d,%d", 
        ((r_edge *)edge)->from_stop_id,
        ((r_edge *)edge)->to_stop_id,
        average_duration,
        start_time/3600, (start_time%3600)/60,
        end_time/3600, (end_time%3600)/60,
        ((r_edge *)edge)->type
    );
	
	if(((r_edge *)edge)->type != CORRESPONDANCE)
	{
		if(((r_edge *)edge)->encounters > 0 && ((r_edge *)edge)->encounters_avg != 0)
			printf(",%d", ((r_edge *)edge)->encounters_avg / ((r_edge *)edge)->encounters);
	}
	
	printf("\n");
}


/*
=============
r_destroy_edge
=============
*/
void r_destroy_edge(void *edge)
{
    #ifdef EDGE_DEBUG
        fprintf(stderr, "Destroying edge %d -> %d\n", 
            ((r_edge *)edge)->from_stop_id, 
            ((r_edge *)edge)->to_stop_id);
    #endif

    free( (r_edge *)edge );
}


/*
=============
main
=============
*/
int main(int argc, char **argv)
{
    char path[1024];
    r_hashtable *edges;
    int edges_nb = 0;

    if(argc < 2) {
        printf("Usage: %s <RATP_GTFS_FULL directory>\n", argv[0]);
        return 1;
    }

    edges = r_hash_create(HASHTABLE_SIZE);

    sprintf(path, "%s/stop_times.txt", argv[1]);
    r_parse_stop_times_file(path, edges);

    sprintf(path, "%s/transfers.txt", argv[1]);
    r_parse_transfers_file(path, edges);

    edges_nb = r_hash_print(edges, &r_print_edge);
    fprintf(stderr, "Edges NB: %d\n", edges_nb);
    
    r_hash_destroy(edges, &r_destroy_edge);

    return 0;
}
