#ifndef R_HASH
#define R_HASH

#include "r_linkedlist.h"


typedef struct r_hashtable {
    int size;
    r_list *buckets;
} r_hashtable;


r_hashtable*    r_hash_create   (int buckets_nb);
unsigned long   r_hash_fn       (char *key);
void*           r_hash_get      (r_hashtable *hashtable, char *key);
void            r_hash_add      (r_hashtable *hashtable, void *element, char *key);
void            r_hash_destroy  (r_hashtable *hashtable, void (*destroyfunction)(void*));
int             r_hash_print    (r_hashtable *hashtable, void (*printfunction)(void*) );

#endif
