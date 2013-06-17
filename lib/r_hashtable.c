#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "r_linkedlist.h"
#include "r_hashtable.h"

//#define HASH_DEBUG


/*
=============
r_hash_create
=============
*/
r_hashtable* r_hash_create(int buckets_nb)
{
    int i = 0;
    r_hashtable *hashtable = NULL;

    hashtable = malloc( sizeof(r_hashtable) );
    hashtable->size = buckets_nb;
    hashtable->buckets = malloc( sizeof(r_list) * buckets_nb );

    fprintf(stderr, "r_hash_create: creating hashtable of buckets_nb %d KB = %d buckets * %d B per bucket\n", 
        buckets_nb * sizeof(r_list) / 1024,
        buckets_nb, 
        sizeof(r_list));

    for(i = 0; i < buckets_nb; ++i)
    {
        hashtable->buckets[i] = NULL;
    }

    return hashtable;
}


/*
=============
r_hash_fn
=============
*/
unsigned long r_hash_fn(char *key)
{
    unsigned long hash = 5381;
    int c;

    while (c = *key++)
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */

    return hash;
}


/*
=============
r_hash_add
=============
*/
void r_hash_add(r_hashtable *hashtable, void *element, char *key)
{
    unsigned long hash = 0;
    unsigned long bucket_index = 0;

    hash = r_hash_fn(key);
    bucket_index = hash % hashtable->size;

    #ifdef HASH_DEBUG
        fprintf(stderr, "r_hash_add: inserting element with key %s in bucket %lu (hash %lu)\n", key, bucket_index, hash);

        if(hashtable->buckets[bucket_index] != NULL) {
            fprintf(stderr, "r_hash_add: collision in bucket %lu for key %s\n", bucket_index, key);
        }
    #endif

    hashtable->buckets[bucket_index] = r_list_insert(hashtable->buckets[bucket_index], element, key);
}


/*
=============
r_hash_get
=============
*/
void* r_hash_get(r_hashtable *hashtable, char *key)
{
    unsigned long hash = 0;
    unsigned long bucket_index = 0;
    void *element = NULL;

    hash = r_hash_fn(key);
    bucket_index = hash % hashtable->size;  

    element = r_list_find(hashtable->buckets[bucket_index], key);

    #ifdef HASH_DEBUG
        fprintf(stderr, "r_hash_get: returning element with key %s from index %lu (hash %lu) \n", 
            key,
            bucket_index,
            hash
        );
    #endif

    return element;
}


/*
=============
r_hash_destroy
=============
*/
void r_hash_destroy(r_hashtable *hashtable, void (*destroyfunction)(void*))
{
    int i = 0;
    for(i = 0; i < hashtable->size; ++i)
    {
        if(hashtable->buckets[i] != NULL) {
            #ifdef HASH_DEBUG
                fprintf(stderr, "Destroying bucket %d\n", i);
            #endif
            r_list_destroy(hashtable->buckets[i], destroyfunction);
        }
    }

    free(hashtable->buckets);
    free(hashtable);
}


/*
=============
r_hash_print
=============
*/
int r_hash_print( r_hashtable *hashtable, void (*printfunction)(void*) )
{
    int i = 0, j = 0;
    for(i = 0; i < hashtable->size; ++i)
    {
        if(hashtable->buckets[i] != NULL) {
            j += r_list_print(hashtable->buckets[i], printfunction);
        }
    }

    return j;
}
