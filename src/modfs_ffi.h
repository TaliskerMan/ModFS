#ifndef MODFS_FFI_H
#define MODFS_FFI_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Creates a new database instance
void* modfs_db_new(const char** includes, int num_includes, const char** excludes, int num_excludes, bool exclude_hidden);

// Starts tracing/indexing the files
bool modfs_db_scan(void* db_ptr);

// Save the DB to the given path
bool modfs_db_save(void* db_ptr, const char* path);

// Load the DB from the given path
bool modfs_db_load(void* db_ptr, const char* path);

// Get the total number of files indexed
uint32_t modfs_db_get_num_files(void* db_ptr);

// Get the total number of folders indexed
uint32_t modfs_db_get_num_folders(void* db_ptr);

// Free the DB instance
void modfs_db_free(void* db_ptr);

// Search files
void* modfs_db_search(void* db_ptr, const char* query_str);

// Gets number of matched folders
int modfs_search_result_get_folders_count(void* res_ptr);

// Gets number of matched files
int modfs_search_result_get_files_count(void* res_ptr);

// Returns a newly allocated string for the full path of the matched file. MUST BE FREED by modfs_free_string!
const char* modfs_search_result_get_file_path(void* res_ptr, int index);

// Returns a newly allocated string for the full path of the matched folder. MUST BE FREED by modfs_free_string!
const char* modfs_search_result_get_folder_path(void* res_ptr, int index);

// Returns the file size
uint64_t modfs_search_result_get_file_size(void* res_ptr, int index);

// Returns the file modification time
uint64_t modfs_search_result_get_file_mtime(void* res_ptr, int index);

// Free search results
void modfs_search_result_free(void* res_ptr);

// Free strings returned by get_path functions
void modfs_free_string(const char* str);

#ifdef __cplusplus
}
#endif

#endif // MODFS_FFI_H
