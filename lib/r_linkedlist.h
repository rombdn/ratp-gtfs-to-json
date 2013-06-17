#ifndef R_LIST
#define R_LIST


typedef struct r_node {
    char *key;
    void *element;
    struct r_node *next;
} r_node;
typedef r_node* r_list;


r_list  r_list_insert   (r_list list, void *element, char *key);
void*   r_list_find     (r_list list, char *key);
void    r_list_destroy  (r_list list, void (*destroyfunction)(void*));
int     r_list_print    (r_list list, void (*printfunction)(void *));

#endif
