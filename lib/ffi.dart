import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef ModfsDbNewCNode =
    Pointer<Void> Function(
      Pointer<Pointer<Utf8>>,
      Int32,
      Pointer<Pointer<Utf8>>,
      Int32,
      Bool,
    );
typedef ModfsDbNewDart =
    Pointer<Void> Function(
      Pointer<Pointer<Utf8>>,
      int,
      Pointer<Pointer<Utf8>>,
      int,
      bool,
    );

typedef ModfsDbScanCNode = Bool Function(Pointer<Void>);
typedef ModfsDbScanDart = bool Function(Pointer<Void>);

typedef ModfsDbSaveCNode = Bool Function(Pointer<Void>, Pointer<Utf8>);
typedef ModfsDbSaveDart = bool Function(Pointer<Void>, Pointer<Utf8>);

typedef ModfsDbLoadCNode = Bool Function(Pointer<Void>, Pointer<Utf8>);
typedef ModfsDbLoadDart = bool Function(Pointer<Void>, Pointer<Utf8>);

typedef ModfsDbGetNumDocsCNode = Uint32 Function(Pointer<Void>);
typedef ModfsDbGetNumDocsDart = int Function(Pointer<Void>);

typedef ModfsDbFreeCNode = Void Function(Pointer<Void>);
typedef ModfsDbFreeDart = void Function(Pointer<Void>);

typedef ModfsDbSearchCNode =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);
typedef ModfsDbSearchDart =
    Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);

typedef ModfsSearchResultGetCountCNode = Int32 Function(Pointer<Void>);
typedef ModfsSearchResultGetCountDart = int Function(Pointer<Void>);

typedef ModfsSearchResultGetPathCNode =
    Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef ModfsSearchResultGetPathDart =
    Pointer<Utf8> Function(Pointer<Void>, int);

typedef ModfsSearchResultGetInfoCNode = Uint64 Function(Pointer<Void>, Int32);
typedef ModfsSearchResultGetInfoDart = int Function(Pointer<Void>, int);

typedef ModfsFreeStringCNode = Void Function(Pointer<Utf8>);
typedef ModfsFreeStringDart = void Function(Pointer<Utf8>);

/// Bindings to the native ModFS C library via Dart FFI.
///
/// This class handles loading the native shared library and mapping all the required
/// database, scan, save, load, and search operations to Dart methods.
class ModFSBindings {
  /// Creates a new instance of [ModFSBindings] by loading the native library from [libraryPath].
  ModFSBindings(String libraryPath) {
    _lib = DynamicLibrary.open(libraryPath);

    _dbNew = _lib.lookupFunction<ModfsDbNewCNode, ModfsDbNewDart>(
      'modfs_db_new',
    );
    _dbScan = _lib.lookupFunction<ModfsDbScanCNode, ModfsDbScanDart>(
      'modfs_db_scan',
    );
    _dbSave = _lib.lookupFunction<ModfsDbSaveCNode, ModfsDbSaveDart>(
      'modfs_db_save',
    );
    _dbLoad = _lib.lookupFunction<ModfsDbLoadCNode, ModfsDbLoadDart>(
      'modfs_db_load',
    );
    _dbGetNumFiles = _lib
        .lookupFunction<ModfsDbGetNumDocsCNode, ModfsDbGetNumDocsDart>(
          'modfs_db_get_num_files',
        );
    _dbGetNumFolders = _lib
        .lookupFunction<ModfsDbGetNumDocsCNode, ModfsDbGetNumDocsDart>(
          'modfs_db_get_num_folders',
        );
    _dbFree = _lib.lookupFunction<ModfsDbFreeCNode, ModfsDbFreeDart>(
      'modfs_db_free',
    );
    _dbSearch = _lib.lookupFunction<ModfsDbSearchCNode, ModfsDbSearchDart>(
      'modfs_db_search',
    );

    _getFoldersCount = _lib
        .lookupFunction<
          ModfsSearchResultGetCountCNode,
          ModfsSearchResultGetCountDart
        >('modfs_search_result_get_folders_count');
    _getFilesCount = _lib
        .lookupFunction<
          ModfsSearchResultGetCountCNode,
          ModfsSearchResultGetCountDart
        >('modfs_search_result_get_files_count');

    _getFilePath = _lib
        .lookupFunction<
          ModfsSearchResultGetPathCNode,
          ModfsSearchResultGetPathDart
        >('modfs_search_result_get_file_path');
    _getFolderPath = _lib
        .lookupFunction<
          ModfsSearchResultGetPathCNode,
          ModfsSearchResultGetPathDart
        >('modfs_search_result_get_folder_path');
    _getFileSize = _lib
        .lookupFunction<
          ModfsSearchResultGetInfoCNode,
          ModfsSearchResultGetInfoDart
        >('modfs_search_result_get_file_size');
    _getFileMtime = _lib
        .lookupFunction<
          ModfsSearchResultGetInfoCNode,
          ModfsSearchResultGetInfoDart
        >('modfs_search_result_get_file_mtime');

    _freeSearchResult = _lib.lookupFunction<ModfsDbFreeCNode, ModfsDbFreeDart>(
      'modfs_search_result_free',
    );
    _freeString = _lib
        .lookupFunction<ModfsFreeStringCNode, ModfsFreeStringDart>(
          'modfs_free_string',
        );
  }
  late final DynamicLibrary _lib;

  late final ModfsDbNewDart _dbNew;
  late final ModfsDbScanDart _dbScan;
  late final ModfsDbSaveDart _dbSave;
  late final ModfsDbLoadDart _dbLoad;
  late final ModfsDbGetNumDocsDart _dbGetNumFiles;
  late final ModfsDbGetNumDocsDart _dbGetNumFolders;
  late final ModfsDbFreeDart _dbFree;
  late final ModfsDbSearchDart _dbSearch;

  late final ModfsSearchResultGetCountDart _getFoldersCount;
  late final ModfsSearchResultGetCountDart _getFilesCount;

  late final ModfsSearchResultGetPathDart _getFilePath;
  late final ModfsSearchResultGetPathDart _getFolderPath;
  late final ModfsSearchResultGetInfoDart _getFileSize;
  late final ModfsSearchResultGetInfoDart _getFileMtime;

  late final ModfsDbFreeDart _freeSearchResult;
  late final ModfsFreeStringDart _freeString;

  /// Allocates and creates a new native ModFS database instance.
  ///
  /// Takes a list of [includes] paths to scan, [excludes] paths to ignore, and a flag
  /// to [excludeHidden] files and directories. Returns a native pointer to the database.
  Pointer<Void> createDatabase(
    List<String> includes,
    List<String> excludes,
    bool excludeHidden,
  ) {
    final incArgs = _allocateStringArray(includes);
    final excArgs = _allocateStringArray(excludes);
    final db = _dbNew(
      incArgs,
      includes.length,
      excArgs,
      excludes.length,
      excludeHidden,
    );
    malloc.free(incArgs);
    malloc.free(excArgs);
    return db;
  }

  Pointer<Pointer<Utf8>> _allocateStringArray(List<String> strings) {
    if (strings.isEmpty) return nullptr;
    final arr = malloc.allocate<Pointer<Utf8>>(strings.length * sizeOf<Pointer<Utf8>>());
    // Converts Dart string values into native UTF-8 strings.
    for (var index = 0; index < strings.length; index++) {
      arr[index] = strings[index].toNativeUtf8();
    }
    return arr;
  }

  /// Performs a full directory scan for the given database pointer [db].
  ///
  /// Returns `true` if the scan completes successfully, or `false` otherwise.
  bool scanDatabase(Pointer<Void> db) {
    return _dbScan(db);
  }

  /// Saves the serialized state of the database pointer [db] to the specified file [path].
  ///
  /// Returns `true` if saved successfully.
  bool saveDatabase(Pointer<Void> db, String path) {
    final pathUtf8 = path.toNativeUtf8();
    final res = _dbSave(db, pathUtf8);
    malloc.free(pathUtf8);
    return res;
  }

  /// Loads the serialized state into the database pointer [db] from the specified file [path].
  ///
  /// Returns `true` if loaded successfully.
  bool loadDatabase(Pointer<Void> db, String path) {
    final pathUtf8 = path.toNativeUtf8();
    final res = _dbLoad(db, pathUtf8);
    malloc.free(pathUtf8);
    return res;
  }

  /// Returns the total number of indexed files in the database pointer [db].
  int getNumFiles(Pointer<Void> db) => _dbGetNumFiles(db);

  /// Returns the total number of indexed directories/folders in the database pointer [db].
  int getNumFolders(Pointer<Void> db) => _dbGetNumFolders(db);

  /// Executes a search query string against the database pointer [db].
  ///
  /// Returns a native pointer to the search result.
  Pointer<Void> search(Pointer<Void> db, String query) {
    final queryUtf8 = query.toNativeUtf8();
    final res = _dbSearch(db, queryUtf8);
    malloc.free(queryUtf8);
    return res;
  }

  /// Returns the number of directories found in the search result pointer [res].
  int getFoldersCount(Pointer<Void> res) => _getFoldersCount(res);

  /// Returns the number of files found in the search result pointer [res].
  int getFilesCount(Pointer<Void> res) => _getFilesCount(res);

  /// Resolves the file path at the given [index] of the search result [res].
  ///
  /// Frees the allocated native string before returning the Dart [String].
  String? getFilePath(Pointer<Void> res, int index) {
    final ptr = _getFilePath(res, index);
    if (ptr == nullptr) return null;
    final str = ptr.toDartString();
    _freeString(ptr);
    return str;
  }

  /// Resolves the directory path at the given [index] of the search result [res].
  ///
  /// Frees the allocated native string before returning the Dart [String].
  String? getFolderPath(Pointer<Void> res, int index) {
    final ptr = _getFolderPath(res, index);
    if (ptr == nullptr) return null;
    final str = ptr.toDartString();
    _freeString(ptr);
    return str;
  }

  /// Retrieves the file size in bytes for the file at the given [index] of the search result [res].
  int getFileSize(Pointer<Void> res, int index) => _getFileSize(res, index);

  /// Retrieves the modification time timestamp (mtime) for the file at the given [index] of the search result [res].
  int getFileMtime(Pointer<Void> res, int index) => _getFileMtime(res, index);

  /// Frees memory associated with the search result pointer [res].
  void freeSearchResult(Pointer<Void> res) => _freeSearchResult(res);

  /// Frees memory associated with the database pointer [db].
  void freeDatabase(Pointer<Void> db) => _dbFree(db);
}
