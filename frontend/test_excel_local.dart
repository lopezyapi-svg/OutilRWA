import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  try {
    final bytes = File('../test_python4.xlsx').readAsBytesSync();
    print('Read \${bytes.length} bytes. Decoding...');
    
    final excel = Excel.decodeBytes(bytes);
    print('Decoded successfully! Sheets: \${excel.tables.keys}');
  } catch (e, stackTrace) {
    print('Error decoding: $e');
    print(stackTrace);
  }
}
