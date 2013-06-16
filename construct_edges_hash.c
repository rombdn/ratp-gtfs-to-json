/*
=================================
RATP GTFS stop_times.txt and transfers.txt parser
Create edge with pairs stop_id/last line stop_id and average dep_time difference
Output raw edges (from_stop_id, to_stop_id, average duration, begin_time, end_time)

@param char* path_to_RATP_GTFS_FULL_directory
=================================
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "r_datastruct.h"

/*
=================================
//there are 26622 unique stop_id and 76941 transfers
//there should not be more than one edge for each stop_id
//(one stop_id per route (line, direction))
//and one edge per transfer
//26622 + 76941 = 103563
=================================
*/
#define MAX_EDGES 110000

typedef struct r_edge {
    int to_stop_id;
    int from_stop_id;
    int duration;
    int debut;
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

    new->from_stop_id   = from_stop_id;
    new->to_stop_id     = to_stop_id;
    new->type           = type;
    new->duration       = 0;
    new->counter        = 0;
    new->debut          = 3600*24;
    new->end            = 0;

    return new;
}


/*
=============
r_update_edge
=============
*/
void r_update_edge(r_edge *edge, int start_time, int end_time)
{        
    //used for averaging durations at the end
    edge->counter += 1;
    edge->duration += end_time - start_time;

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
}


/*
=============
r_parse_stop_times_file
=============
*/
int r_parse_stop_times_file(char *path, r_hashtable *edges_table)
{
    int i = 0;
    r_edge *edge = NULL;
    
    FILE *fin = NULL;
    char buffer_line[1024];
    char *pch = NULL;

    char trip_id[255];
    int to_stop_id = 0, from_stop_id = 0;
    int dep_time = 0, last_dep_time = 0;
    char key[20];
    

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
        else
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
/*
int r_parse_transfers_file(char *path, edge *edges, int last_index, int max_index)
{
    char buffer_line[1024];
    char *pch;
    FILE *fin;

    int i = 0, index_line = 0, j = 0;

    int from_stop_id = 0, to_stop_id = 0;
    int duration = 0;

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

        last_index = r_create_edge(edges, from_stop_id, to_stop_id, last_index, max_index);
        r_update_edge(edges, last_index, from_stop_id, to_stop_id, CORRESPONDANCE, 0, duration);
    }

    fclose(fin);

    return last_index;
}
*/

/*
=============
r_print_edges
=============
*/
/*
void r_print_edges(edge *edges, int last_index) {
    int i;

    printf("from_stop_id,to_stop_id,avg_duration,first_time,last_time, type\n"); 

    for(i=0; i<last_index; ++i) {
        //end of edges array
        if(edges[i].to_stop_id == 0) 
            break;

        //entry edge, not used
        if(edges[i].from_stop_id == 0)
            continue;

        printf("%d,%d,%d,%dh%d,%dh%d,%d\n", 
            edges[i].from_stop_id,
            edges[i].to_stop_id,
            edges[i].duration / edges[i].counter,
            edges[i].debut/3600,(edges[i].debut%3600)/60,
            edges[i].end/3600,(edges[i].end%3600)/60,
            edges[i].type
            );
    }
}
*/

/*
=============
main
=============
*/
int main(int argc, char **argv)
{
    char path[1024];
    r_hashtable *edges;

    edges = r_hash_create(5000);

    if(argc < 2) {
        printf("Usage: %s <RATP_GTFS_FULL directory>\n", argv[0]);
        return 1;
    }

    strcat(path, argv[1]);
    strcat(path, "/stop_times.txt");
    r_parse_stop_times_file(path, edges);
/*
    path[0] = '\0';
    strcat(path, argv[1]);
    strcat(path, "/transfers.txt");
    //last_index = r_parse_transfers_file(path, edges, last_index, MAX_EDGES);

    r_get_index(edges, hash, 4025388, 4025390);
    //r_print_edges(edges, last_index);
*/
    return 0;
}
