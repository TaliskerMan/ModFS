// ignore_for_file: avoid_print
import 'lib/ffi.dart';

void main() async {
  print("Start");
  final libPath = 'src/libmodfs_core.so';
  var modfs = ModFSBindings(libPath);
  print("Bindings created");
  var dbPtr = modfs.createDatabase(['/'], [], false);
  print("DB created at ${dbPtr.address}");
  print("Loading...");
  modfs.loadDatabase(dbPtr, '/tmp/db.fsearch');
  print("Loaded");
}
