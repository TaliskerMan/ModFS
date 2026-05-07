import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'lib/ffi.dart';

void main() async {
  print("Start");
  final libPath = '/home/freecode/antigrav/ModFS/src/libmodfs_core.so';
  var modfs = ModFSBindings(libPath);
  print("Bindings created");
  var dbPtr = modfs.createDatabase(['/'], [], false);
  print("DB created at ${dbPtr.address}");
  print("Loading...");
  modfs.loadDatabase(dbPtr, '/tmp/db.fsearch');
  print("Loaded");
}
