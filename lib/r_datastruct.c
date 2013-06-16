#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "r_datastruct.h"

/*
=============
Linked List
=============
*/

r_list r_list_insert(r_list list, void *element, char *key)
{
    r_node *new = NULL;
    printf("r_list_insert: current list: %s\n", (char *)list);

    if( ( new = (r_node*)malloc( (int)sizeof(r_node) ) ) == NULL) {
        fprintf(stderr, "ERROR in r_list_insert: cannot allocate new node\n");
    }

    new->element = element;
    new->next = list;
    new->key = key;

    return new;
}


void* r_list_find(r_list list, char *key)
{
    int i = 0;
    while( list != NULL )
    {
        if( strcmp(list->key, key) == 0 ) {
            printf("r_list_find: key %s found in position %d\n", key, i);
            return list->element;
        }

        list = list->next;
        i += 1;
    }

    return NULL;
}

void r_list_destroy(r_list list)
{
    r_node *temp = NULL;

    while(list != NULL)
    {
        temp = list;
        printf("Deleting element %s with key %s\n", (char *)temp->element, temp->key);
        list = list->next;
        free(temp);
    }
}


/*
=============
Hash Table
=============
*/

r_hashtable* r_hash_create(int size)
{
    int i = 0;
    r_hashtable *hashtable = NULL;

    hashtable = malloc( sizeof(r_hashtable) );
    hashtable->size = size;
    hashtable->buckets = malloc( sizeof(r_list) * size );

    for(i = 0; i < size; ++i)
    {
        hashtable->buckets[i] = NULL;
    }

    return hashtable;
}


unsigned long r_hash_fn(char *key)
{
    unsigned long hash = 5381;
    int c;

    while (c = *key++)
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

    return hash;
}


void r_hash_add(r_hashtable *hashtable, void *element, char *key)
{
    unsigned long hash = 0;
    unsigned long bucket_index = 0;

    hash = r_hash_fn(key);
    bucket_index = hash % hashtable->size;

    printf("r_hash_add: inserting element with key %s in bucket %lu (hash %lu)\n", key, bucket_index, hash);

    hashtable->buckets[bucket_index] = r_list_insert(hashtable->buckets[bucket_index], element, key);
}

void* r_hash_get(r_hashtable *hashtable, char *key)
{
    unsigned long hash = 0;
    unsigned long bucket_index = 0;
    void *element = NULL;

    hash = r_hash_fn(key);
    bucket_index = hash % hashtable->size;  

    element = r_list_find(hashtable->buckets[bucket_index], key);

    printf("r_hash_get: returning element with key %s from index %lu (hash %lu) \n", 
        key,
        bucket_index,
        hash
    );

    return element;
}

void r_hash_destroy(r_hashtable *hashtable)
{
    int i = 0;
    for(i = 0; i < hashtable->size; ++i)
    {
        if(hashtable->buckets[i] != NULL) {
            r_list_destroy(hashtable->buckets[i]);
        }
    }

    free(hashtable->buckets);
    free(hashtable);
}

/*
int main()
{
    r_hashtable *hasht = NULL;
    //r_list list = NULL;

    hasht = r_hash_create(1);

    //printf("Inserting...\n");
    //list = r_list_insert(list, "Hello world!", "dakey");
    //list = r_list_insert(list, "Hello world2!", "dakey2");
    //printf("Element %s\n", (char *)r_list_find(list, "dakey") );
    
    r_hash_add(hasht, "Hello world!", "40254384025439");
    r_hash_add(hasht, "Foobar!", "40254724025434");
    r_hash_add(hasht, "Jumpyjumpa!", "40254724025435");
    printf("Get key %s: %s\n", "40254384025439", (char *)r_hash_get(hasht, "40254384025439"));
    printf("Get key %s: %s\n", "40254724025434", (char *)r_hash_get(hasht, "40254724025434"));
    printf("Get key %s: %s\n", "40254724025435", (char *)r_hash_get(hasht, "40254724025435"));
    

    //r_list_destroy(list);
    //r_list_destroy(hasht->buckets[0]);
    r_hash_destroy(hasht);

    return 0;
}
*/