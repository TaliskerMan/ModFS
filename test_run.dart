import 'dart:ffi';
import 'lib/ffi.dart';
import 'dart:isolate';

void main() async {
  print("Main: Starting.");
  List<String> _includes = ['/'];
  List<String> _excludes = [];
  bool shouldScan = true;
  String dbPath = '/home/freecode/.local/share/modfs/database.fsearch';

  print("Main: Opening .so & Creating DB");
  final modfs = ModFSBindings('/home/freecode/antigrav/ModFS/src/libmodfs_core.so');
  final dbPtr = modfs.createDatabase(_includes, _excludes, false);

  print("Main: Launching isolate...");
  await Isolate.run(() {
    return _processDB([dbPtr.address, shouldScan, dbPath]);
  });
  print("Main: Returned from isolate.");
  
  modfs.freeDatabase(dbPtr);
}

void _processDB(List<dynamic> args) {
  int dbAddress = args[0] as int;
  bool shouldScan = args[1] as bool;
  String dbPath = args[2] as String;
  
  final bgModfs = ModFSBindings('/home/freecode/antigrav/ModFS/src/libmodfs_core.so');
  final bgDbPtr = Pointer<Void>.fromAddress(dbAddress);
  
  if (shouldScan) {
    print("Isolate: Scanning...");
    bgModfs.scanDatabase(bgDbPtr);
    print("Isolate: Saving...");
    bgModfs.saveDatabase(bgDbPtr, dbPath);
  } else {
    print("Isolate: Loading...");
    bool success = bgModfs.loadDatabase(bgDbPtr, dbPath);
  }
}
