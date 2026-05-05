// Ce fichier decrit une entree de recherche globale.
import '../app_module.dart';

/// Modèle simple utilisé pour alimenter la recherche globale.
class GlobalSearchEntry {
  const GlobalSearchEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.module,
    required this.searchIndex,
  });

  final String id;
  final String title;
  final String subtitle;
  final String section;
  final AppModule module;
  final String searchIndex;
}
