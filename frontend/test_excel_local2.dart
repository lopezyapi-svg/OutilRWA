import 'dart:io';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

void main() async {
  try {
    final bytes = File('../test_python.xlsx').readAsBytesSync();
    print('Read \${bytes.length} bytes. Decoding with spreadsheet_decoder...');
    
    var decoder = SpreadsheetDecoder.decodeBytes(bytes, update: true);
    print('Decoded successfully! Sheets: \${decoder.tables.keys}');
  } catch (e, stackTrace) {
    print('Error decoding: $e');
    print(stackTrace);
  }
}
