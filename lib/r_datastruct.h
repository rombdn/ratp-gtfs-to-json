#ifndef R_HASH
#define R_HASH

/*
=============
Linked List
=============
*/
typedef struct r_node {
    char *key;
    void *element;
    struct r_node *next;
} r_node;
typedef r_node* r_list;

r_list  r_list_insert   (r_list list, void *element, char *key);
void*   r_list_find     (r_list list, char *key);
void    r_list_destroy  (r_list list);

/*
=============
Hash Table
=============
*/
typedef struct r_hashtable {
    int size;
    r_list *buckets;
} r_hashtable;

r_hashtable*    r_hash_create   (int size);
unsigned long   r_hash_fn       (char *key);
void*           r_hash_get      (r_hashtable *hashtable, char *key);
void            r_hash_add      (r_hashtable *hashtable, void *element, char *key);
void            r_hash_destroy  (r_hashtable *hashtable);

#endif