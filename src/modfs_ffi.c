#include "modfs_ffi.h"
#include "fsearch_database.h"
#include "fsearch_database_search.h"
#include "fsearch_database_entry.h"
#include "fsearch_query.h"
#include "fsearch_array.h"
#include <glib.h>
#include <stdlib.h>
#include "fsearch_index.h"
#include "fsearch_exclude_path.h"

void* modfs_db_new(const char** includes, int num_includes, const char** excludes, int num_excludes, bool exclude_hidden) {
    GList *g_includes = NULL;
    for (int i = 0; i < num_includes; i++) {
        GDateTime* dt = g_date_time_new_now_local();
        time_t t = g_date_time_to_unix(dt);
        g_date_time_unref(dt);
        FsearchIndex* idx = fsearch_index_new(FSEARCH_INDEX_FOLDER_TYPE, includes[i], true, true, false, t);
        g_includes = g_list_append(g_includes, idx);
    }
    GList *g_excludes = NULL;
    for (int i = 0; i < num_excludes; i++) {
        FsearchExcludePath* idx = fsearch_exclude_path_new(excludes[i], true);
        g_excludes = g_list_append(g_excludes, idx);
    }
    
    FsearchDatabase* db = db_new(g_includes, g_excludes, NULL, exclude_hidden);
    return db;
}

bool modfs_db_scan(void* db_ptr) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    return db_scan(db, NULL, NULL);
}

bool modfs_db_save(void* db_ptr, const char* path) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    return db_save(db, path);
}

bool modfs_db_load(void* db_ptr, const char* path) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    return db_load(db, path, NULL);
}

uint32_t modfs_db_get_num_files(void* db_ptr) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    return db_get_num_files(db);
}

uint32_t modfs_db_get_num_folders(void* db_ptr) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    return db_get_num_folders(db);
}

void modfs_db_free(void* db_ptr) {
    if (db_ptr) {
        db_unref((FsearchDatabase*)db_ptr);
    }
}

void* modfs_db_search(void* db_ptr, const char* query_str) {
    FsearchDatabase* db = (FsearchDatabase*)db_ptr;
    
    // Get db current arrays
    DynamicArray* folders = db_get_folders(db);
    DynamicArray* files = db_get_files(db);
    
    if (!folders || !files) {
        return NULL;
    }
    
    FsearchQuery* query = fsearch_query_new(query_str, NULL, NULL, 0, "1");
    FsearchThreadPool* pool = db_get_thread_pool(db);
    
    DatabaseSearchResult* res = db_search(query, pool, folders, files, DATABASE_INDEX_TYPE_NAME, NULL);
    fsearch_query_unref(query);
    return res;
}

int modfs_search_result_get_folders_count(void* res_ptr) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->folders) return 0;
    return darray_get_num_items(res->folders);
}

int modfs_search_result_get_files_count(void* res_ptr) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->files) return 0;
    return darray_get_num_items(res->files);
}

const char* modfs_search_result_get_file_path(void* res_ptr, int index) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->files) return NULL;
    FsearchDatabaseEntry* entry = darray_get_item(res->files, index);
    if (!entry) return NULL;
    GString* gpath = db_entry_get_path_full(entry);
    return g_string_free(gpath, FALSE);
}

const char* modfs_search_result_get_folder_path(void* res_ptr, int index) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->folders) return NULL;
    FsearchDatabaseEntry* entry = darray_get_item(res->folders, index);
    if (!entry) return NULL;
    GString* gpath = db_entry_get_path_full(entry);
    return g_string_free(gpath, FALSE);
}

uint64_t modfs_search_result_get_file_size(void* res_ptr, int index) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->files) return 0;
    FsearchDatabaseEntry* entry = darray_get_item(res->files, index);
    if (!entry) return 0;
    return (uint64_t)db_entry_get_size(entry);
}

uint64_t modfs_search_result_get_file_mtime(void* res_ptr, int index) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (!res || !res->files) return 0;
    FsearchDatabaseEntry* entry = darray_get_item(res->files, index);
    if (!entry) return 0;
    return (uint64_t)db_entry_get_mtime(entry);
}

void modfs_search_result_free(void* res_ptr) {
    DatabaseSearchResult* res = (DatabaseSearchResult*)res_ptr;
    if (res) {
        if (res->folders) darray_unref(res->folders);
        if (res->files) darray_unref(res->files);
        g_free(res);
    }
}

void modfs_free_string(const char* str) {
    if (str) {
        g_free((gpointer)str);
    }
}
