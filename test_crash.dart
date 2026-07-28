import 'lib/ffi.dart';

void main() {
  // print("Loading DB...");
  final modfs = ModFSBindings(
    '/home/freecode/antigrav/ModFS/src/libmodfs_core.so',
  );
  final dbPtr = modfs.createDatabase(
    ['/home/freecode/antigrav/ModFS'],
    [],
    false,
  );
  // print("Scanning...");
  modfs.scanDatabase(dbPtr);
  // print("Files: \${modfs.getNumFiles(dbPtr)}");
  // print("Folders: \${modfs.getNumFolders(dbPtr)}");
}
