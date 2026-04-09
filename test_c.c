#include "src/modfs_ffi.h"
#include <stdio.h>

int main() {
    printf("Initializing DB with root /...\n");
    const char* includes[] = {"/"};
    const char* excludes[] = {NULL};
    void* db = modfs_db_new(includes, 1, excludes, 0, false);
    printf("Scanning /...\n");
    modfs_db_scan(db);
    printf("Done!\n");
    return 0;
}
