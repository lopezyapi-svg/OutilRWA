import 'dart:io';

void main() {
  final file =
      File('lib/modules/vue_ensemble/screens/vue_ensemble_screen.dart');
  var content = file.readAsStringSync();

  // Replace heights between 5 and 30 with 2
  content = content.replaceAllMapped(
      RegExp(r'SizedBox\(height:\s*([5-9]|[1-2][0-9])(?![\d\.])\)'), (match) {
    return 'SizedBox(height: 2)';
  });

  // Replace widths between 5 and 30 with 2
  content = content.replaceAllMapped(
      RegExp(r'SizedBox\(width:\s*([5-9]|[1-2][0-9])(?![\d\.])\)'), (match) {
    return 'SizedBox(width: 2)';
  });

  // Reduce some padding variables
  content =
      content.replaceAll('const EdgeInsets.all(5)', 'const EdgeInsets.all(2)');
  content =
      content.replaceAll('const EdgeInsets.all(8)', 'const EdgeInsets.all(2)');
  content =
      content.replaceAll('const EdgeInsets.all(12)', 'const EdgeInsets.all(4)');
  content =
      content.replaceAll('const EdgeInsets.all(16)', 'const EdgeInsets.all(4)');
  content = content.replaceAll(
      'const EdgeInsets.symmetric(horizontal: 16, vertical: 12)',
      'const EdgeInsets.symmetric(horizontal: 4, vertical: 4)');
  content = content.replaceAll(
      'const EdgeInsets.symmetric(horizontal: 14, vertical: 12)',
      'const EdgeInsets.symmetric(horizontal: 4, vertical: 4)');
  content = content.replaceAll(
      'const EdgeInsets.symmetric(horizontal: 8, vertical: 12)',
      'const EdgeInsets.symmetric(horizontal: 4, vertical: 4)');
  content = content.replaceAll(
      'const EdgeInsets.symmetric(horizontal: 12, vertical: 12)',
      'const EdgeInsets.symmetric(horizontal: 4, vertical: 4)');

  // Reduce panel inner paddings
  content = content.replaceAll(
      'EdgeInsets.symmetric(horizontal: 9, vertical: 5)',
      'EdgeInsets.symmetric(horizontal: 4, vertical: 2)');
  content = content.replaceAll(
      'EdgeInsets.symmetric(horizontal: 12, vertical: 10)',
      'EdgeInsets.symmetric(horizontal: 4, vertical: 4)');

  // Fix panel margin and internal gaps
  content = content.replaceAll(
      'padding: const EdgeInsets.all(3),', 'padding: const EdgeInsets.all(1),');

  file.writeAsStringSync(content);
  print("Done replacing spaces in vue_ensemble_screen");
}
