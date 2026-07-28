import 'dart:ffi';
import 'dart:isolate';

import 'lib/ffi.dart';

void main() async {
  // print("Main: Starting.");
  final includes = <String>['/'];
  final excludes = <String>[];
  const shouldScan = true;
  const dbPath = '/home/freecode/.local/share/modfs/database.fsearch';

  // print("Main: Opening .so & Creating DB");
  final modfs = ModFSBindings(
    '/home/freecode/antigrav/ModFS/src/libmodfs_core.so',
  );
  final dbPtr = modfs.createDatabase(includes, excludes, false);

  // print("Main: Launching isolate...");
  await Isolate.run(() {
    return _processDB([dbPtr.address, shouldScan, dbPath]);
  });
  // print("Main: Returned from isolate.");

  modfs.freeDatabase(dbPtr);
}

void _processDB(List<dynamic> args) {
  final dbAddress = args[0] as int;
  final shouldScan = args[1] as bool;
  final dbPath = args[2] as String;

  final bgModfs = ModFSBindings(
    '/home/freecode/antigrav/ModFS/src/libmodfs_core.so',
  );
  final bgDbPtr = Pointer<Void>.fromAddress(dbAddress);

  if (shouldScan) {
    // print("Isolate: Scanning...");
    bgModfs.scanDatabase(bgDbPtr);
    // print("Isolate: Saving...");
    bgModfs.saveDatabase(bgDbPtr, dbPath);
  } else {
    // print("Isolate: Loading...");
    bgModfs.loadDatabase(bgDbPtr, dbPath);
  }
}
