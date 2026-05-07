#include "src/modfs_ffi.h"
#include <stdio.h>

int main() {
    printf("Initializing DB with root /...\n");
    const char* includes[] = {"/"};
    const char* excludes[] = {NULL};
    void* db = modfs_db_new(includes, 1, excludes, 0, false);
    printf("Searching empty string...\n");
    void* res = modfs_db_search(db, "");
    printf("Search result pointer: %p\n", res);
    printf("Done!\n");
    return 0;
}
