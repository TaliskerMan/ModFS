import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

typedef ModfsDbNewCNode = Pointer<Void> Function(Pointer<Pointer<Utf8>>, Int32, Pointer<Pointer<Utf8>>, Int32, Bool);
typedef ModfsDbNewDart = Pointer<Void> Function(Pointer<Pointer<Utf8>>, int, Pointer<Pointer<Utf8>>, int, bool);

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

typedef ModfsDbSearchCNode = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);
typedef ModfsDbSearchDart = Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>);

typedef ModfsSearchResultGetCountCNode = Int32 Function(Pointer<Void>);
typedef ModfsSearchResultGetCountDart = int Function(Pointer<Void>);

typedef ModfsSearchResultGetPathCNode = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef ModfsSearchResultGetPathDart = Pointer<Utf8> Function(Pointer<Void>, int);

typedef ModfsSearchResultGetInfoCNode = Uint64 Function(Pointer<Void>, Int32);
typedef ModfsSearchResultGetInfoDart = int Function(Pointer<Void>, int);

typedef ModfsFreeStringCNode = Void Function(Pointer<Utf8>);
typedef ModfsFreeStringDart = void Function(Pointer<Utf8>);

class ModFSBindings {
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

  ModFSBindings(String libraryPath) {
    _lib = DynamicLibrary.open(libraryPath);
    
    _dbNew = _lib.lookupFunction<ModfsDbNewCNode, ModfsDbNewDart>('modfs_db_new');
    _dbScan = _lib.lookupFunction<ModfsDbScanCNode, ModfsDbScanDart>('modfs_db_scan');
    _dbSave = _lib.lookupFunction<ModfsDbSaveCNode, ModfsDbSaveDart>('modfs_db_save');
    _dbLoad = _lib.lookupFunction<ModfsDbLoadCNode, ModfsDbLoadDart>('modfs_db_load');
    _dbGetNumFiles = _lib.lookupFunction<ModfsDbGetNumDocsCNode, ModfsDbGetNumDocsDart>('modfs_db_get_num_files');
    _dbGetNumFolders = _lib.lookupFunction<ModfsDbGetNumDocsCNode, ModfsDbGetNumDocsDart>('modfs_db_get_num_folders');
    _dbFree = _lib.lookupFunction<ModfsDbFreeCNode, ModfsDbFreeDart>('modfs_db_free');
    _dbSearch = _lib.lookupFunction<ModfsDbSearchCNode, ModfsDbSearchDart>('modfs_db_search');
    
    _getFoldersCount = _lib.lookupFunction<ModfsSearchResultGetCountCNode, ModfsSearchResultGetCountDart>('modfs_search_result_get_folders_count');
    _getFilesCount = _lib.lookupFunction<ModfsSearchResultGetCountCNode, ModfsSearchResultGetCountDart>('modfs_search_result_get_files_count');
    
    _getFilePath = _lib.lookupFunction<ModfsSearchResultGetPathCNode, ModfsSearchResultGetPathDart>('modfs_search_result_get_file_path');
    _getFolderPath = _lib.lookupFunction<ModfsSearchResultGetPathCNode, ModfsSearchResultGetPathDart>('modfs_search_result_get_folder_path');
    _getFileSize = _lib.lookupFunction<ModfsSearchResultGetInfoCNode, ModfsSearchResultGetInfoDart>('modfs_search_result_get_file_size');
    _getFileMtime = _lib.lookupFunction<ModfsSearchResultGetInfoCNode, ModfsSearchResultGetInfoDart>('modfs_search_result_get_file_mtime');
    
    _freeSearchResult = _lib.lookupFunction<ModfsDbFreeCNode, ModfsDbFreeDart>('modfs_search_result_free');
    _freeString = _lib.lookupFunction<ModfsFreeStringCNode, ModfsFreeStringDart>('modfs_free_string');
  }

  Pointer<Void> createDatabase(List<String> includes, List<String> excludes, bool excludeHidden) {
    final incArgs = _allocateStringArray(includes);
    final excArgs = _allocateStringArray(excludes);
    final db = _dbNew(incArgs, includes.length, excArgs, excludes.length, excludeHidden);
    malloc.free(incArgs);
    malloc.free(excArgs);
    return db;
  }

  Pointer<Pointer<Utf8>> _allocateStringArray(List<String> strings) {
    if (strings.isEmpty) return nullptr;
    final Pointer<Pointer<Utf8>> arr = malloc.allocate(strings.length * sizeOf<Pointer<Utf8>>());
    for (int i = 0; i < strings.length; i++) {
        arr[i] = strings[i].toNativeUtf8();
    }
    return arr;
  }

  bool scanDatabase(Pointer<Void> db) {
    return _dbScan(db);
  }

  bool saveDatabase(Pointer<Void> db, String path) {
    var pathUtf8 = path.toNativeUtf8();
    var res = _dbSave(db, pathUtf8);
    malloc.free(pathUtf8);
    return res;
  }

  bool loadDatabase(Pointer<Void> db, String path) {
    var pathUtf8 = path.toNativeUtf8();
    var res = _dbLoad(db, pathUtf8);
    malloc.free(pathUtf8);
    return res;
  }
  
  int getNumFiles(Pointer<Void> db) => _dbGetNumFiles(db);
  int getNumFolders(Pointer<Void> db) => _dbGetNumFolders(db);

  Pointer<Void> search(Pointer<Void> db, String query) {
    var queryUtf8 = query.toNativeUtf8();
    var res = _dbSearch(db, queryUtf8);
    malloc.free(queryUtf8);
    return res;
  }

  int getFoldersCount(Pointer<Void> res) => _getFoldersCount(res);
  int getFilesCount(Pointer<Void> res) => _getFilesCount(res);

  String? getFilePath(Pointer<Void> res, int index) {
    var ptr = _getFilePath(res, index);
    if (ptr == nullptr) return null;
    var str = ptr.toDartString();
    _freeString(ptr);
    return str;
  }

  String? getFolderPath(Pointer<Void> res, int index) {
    var ptr = _getFolderPath(res, index);
    if (ptr == nullptr) return null;
    var str = ptr.toDartString();
    _freeString(ptr);
    return str;
  }

  int getFileSize(Pointer<Void> res, int index) => _getFileSize(res, index);
  int getFileMtime(Pointer<Void> res, int index) => _getFileMtime(res, index);

  void freeSearchResult(Pointer<Void> res) => _freeSearchResult(res);
  void freeDatabase(Pointer<Void> db) => _dbFree(db);
}
