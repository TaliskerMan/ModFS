#include "src/modfs_ffi.h"
#include <stdio.h>
#include <execinfo.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

void handler(int sig) {
  void *array[10];
  size_t size;

  size = backtrace(array, 10);
  fprintf(stderr, "Error: signal %d:\n", sig);
  backtrace_symbols_fd(array, size, STDERR_FILENO);
  exit(1);
}

int main() {
    signal(SIGSEGV, handler);
    printf("Initializing DB with root / and excludes...\n");
    const char* includes[] = {"/"};
    const char* excludes[] = {"/tmp", "/var/tmp"};
    
    printf("Before modfs_db_new\n");
    void* db = modfs_db_new(includes, 1, excludes, 2, false);
    printf("After modfs_db_new\n");
    
    return 0;
}
