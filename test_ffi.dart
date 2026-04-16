import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef ModfsDbNewCNode = Pointer<Void> Function(Pointer<Pointer<Utf8>>, Int32, Pointer<Pointer<Utf8>>, Int32, Bool);
typedef ModfsDbNewDart = Pointer<Void> Function(Pointer<Pointer<Utf8>>, int, Pointer<Pointer<Utf8>>, int, bool);

typedef ModfsDbScanCNode = Bool Function(Pointer<Void>);
typedef ModfsDbScanDart = bool Function(Pointer<Void>);

void main() async {
  // print('Loading lib...');
  final lib = DynamicLibrary.open('./src/libmodfs_core.dylib');
  // print('Lib loaded.');

  final dbNew = lib.lookupFunction<ModfsDbNewCNode, ModfsDbNewDart>('modfs_db_new');
  final dbScan = lib.lookupFunction<ModfsDbScanCNode, ModfsDbScanDart>('modfs_db_scan');

  // print('Allocating includes...');
  final incPath = '/'.toNativeUtf8();
  final incPtr = malloc.allocate<Pointer<Utf8>>(sizeOf<Pointer<Utf8>>());
  incPtr[0] = incPath;

  // print('Creating DB...');
  final db = dbNew(incPtr, 1, nullptr, 0, false);
  // print('DB created at \${db.address}');

  // print('Scanning DB...');
  dbScan(db);
  // print('Scan result: $res');
}
