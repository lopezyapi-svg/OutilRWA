import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart';

void main() async {
  try {
    print('Downloading template...');
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/dashboard/fonds-propres/import/template'));
    if (response.statusCode != 200) {
      print('Failed to download: \${response.statusCode}');
      return;
    }
    
    final bytes = response.bodyBytes;
    print('Downloaded \${bytes.length} bytes. Decoding...');
    
    final excel = Excel.decodeBytes(bytes);
    print('Decoded successfully! Sheets: \${excel.tables.keys}');
  } catch (e, stackTrace) {
    print('Error decoding: $e');
    print(stackTrace);
  }
}
