#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "r_linkedlist.h"

//#define LIST_DEBUG

/*
=============
r_list_insert
=============
*/
r_list r_list_insert(r_list list, void *element, char *key)
{
    r_node *new = NULL;

    //key must be copied
    char *keystored = (char *)malloc( sizeof(char) * (strlen(key) + 1)); 
    if( keystored == NULL) {
        fprintf(stderr, "ERROR in r_list_insert: cannot allocate key string\n");
    }
    strcpy(keystored, key);

    if( ( new = (r_node*)malloc( (int)sizeof(r_node) ) ) == NULL) {
        fprintf(stderr, "ERROR in r_list_insert: cannot allocate new node\n");
    }

    #ifdef LIST_DEBUG
        fprintf(stderr, "r_list_insert: current list: %s\n", (char *)list);
    #endif

    new->element = element;
    new->next = list;
    new->key = keystored;

    return new;
}


/*
=============
r_list_find
=============
*/
void* r_list_find(r_list list, char *key)
{
    int i = 0;
    while( list != NULL )
    {
        if( strcmp(list->key, key) == 0 ) {
            #ifdef LIST_DEBUG
                fprintf(stderr, "r_list_find: key %s found in position %d, %s\n", key, i, list->key);
            #endif
            return list->element;
        }

        list = list->next;
        i += 1;
    }

    return NULL;
}

/*
=============
r_list_destroy
=============
*/
void r_list_destroy(r_list list, void (*destroyfunction)(void*))
{
    r_node *temp = NULL;

    while(list != NULL)
    {
        #ifdef LIST_DEBUG
            fprintf(stderr, "Destroying element with key %s\n", list->key);
        #endif
        
        temp = list;
        list = list->next;

        (*destroyfunction)(temp->element);
        free(temp->key);
        free(temp);
    }
}


/*
=============
r_list_print
=============
*/
int r_list_print(r_list list, void (*printfunction)(void *))
{
    int i = 0;
    while(list != NULL)
    {
        (*printfunction)(list->element);
        list = list->next;
        i += 1;
    }

    return i;
}
