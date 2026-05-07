import 'dart:ffi';
import 'package:ffi/ffi.dart';

void main() {
  print("Before free nullptr");
  malloc.free(nullptr);
  print("After free nullptr");
}
