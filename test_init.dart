// ignore_for_file: avoid_print
import 'lib/ffi.dart';

void main() async {
  print('Start');
  const libPath = 'src/libmodfs_core.so';
  final modfs = ModFSBindings(libPath);
  print('Bindings created');
  final dbPtr = modfs.createDatabase(['/'], [], false);
  print('DB created at ${dbPtr.address}');
  print('Loading...');
  modfs.loadDatabase(dbPtr, '/tmp/db.fsearch');
  print('Loaded');
}
