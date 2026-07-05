import 'lib/modules/dashboard/models/dashboard_models.dart';

void main() {
  final json = {
    'metrics': [],
    'category_distribution': [],
    'rwa_type_distribution': [],
    'rwa_category_distribution': [],
    'country_distribution': [],
    'crm_distribution': [],
    'rating_distribution': [],
    'rwa_projection': [],
    'portfolio_overview': [],
  };
  final snap = DashboardSnapshot.fromJson(json);
  print('Is Null? ${snap.top10Exposures == null}');
  print('Length: ${snap.top10Exposures?.length}');
}
