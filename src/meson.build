

libfsearch_sources = [

    'fsearch_array.c',
    'fsearch_config.c',
    'fsearch_database.c',
    'fsearch_database_entry.c',
    'fsearch_database_index.c',
    'fsearch_database_search.c',

    'fsearch_exclude_path.c',
    'fsearch_file_utils.c',
    'fsearch_filter.c',
    'fsearch_filter_manager.c',
    'fsearch_index.c',
    'fsearch_memory_pool.c',
    'fsearch_query.c',
    'fsearch_query_match_data.c',
    'fsearch_query_matchers.c',
    'fsearch_query_node.c',
    'fsearch_query_lexer.c',
    'fsearch_query_parser.c',
    'fsearch_query_tree.c',
    'fsearch_size_utils.c',
    'fsearch_string_utils.c',
    'fsearch_task.c',
    'fsearch_thread_pool.c',
    'fsearch_time_utils.c',
    'fsearch_utf.c',
]

if build_machine.system()=='darwin'
    libfsearch_sources+=['strverscmp.c']
endif

fsearch_deps = [
    cc.find_library('m', required: true),
    dependency('gio-unix-2.0', version: '>= 2.50'),
    dependency('gtk+-3.0', version: '>= 3.18'),
    dependency('libpcre2-8', version: '>= 10.21'),
    dependency('icu-uc', version: '>= 3.8'),
]

libfsearch = static_library(
    'fsearch',
    libfsearch_sources,
    dependencies: fsearch_deps,
    include_directories: fsearch_include_dirs,
)

libfsearch_include_dirs = include_directories('.')

libfsearch_dep = declare_dependency(
    link_with: libfsearch,
    include_directories: [
        fsearch_include_dirs,
        libfsearch_include_dirs
    ],
    dependencies: fsearch_deps
)

libmodfs_core = shared_library('modfs_core',
    'modfs_ffi.c',
    include_directories: fsearch_include_dirs,
    dependencies: fsearch_deps,
    link_with: libfsearch,
    install: true,
)

subdir('tests')
