import 'package:flutter_test/flutter_test.dart';
import 'package:rwa_calculator/modules/risque_marche/services/market_data_import_store.dart';
import 'package:rwa_calculator/modules/risque_marche/services/fx_security_analysis_service.dart';
import 'package:rwa_calculator/core/services/rwa_api_service.dart';
import 'package:rwa_calculator/core/services/api_client.dart';

void main() {
  test('Debug data loading and FX analysis', () async {
    final client = ApiClient(baseUrl: 'http://127.0.0.1:8000');
    final api = RwaApiService(client: client, useMockData: false);
    
    print('Fetching portfolio payload from API...');
    final payload = await api.fetchMarketPortfolioPayload();
    if (payload == null) {
      print('API returned null payload!');
      return;
    }
    print('Payload keys: ${payload.keys}');
    
    final datasets = payload['datasets'];
    if (datasets == null) {
      print('datasets key is missing from payload!');
      return;
    }
    
    final bondsData = datasets['bonds'];
    if (bondsData == null) {
      print('bonds dataset is missing from payload!');
      return;
    }
    
    final List<dynamic> recordsRaw = bondsData['records'] ?? [];
    print('Raw bonds records count: ${recordsRaw.length}');
    
    final records = <MarketPortfolioRecord>[];
    for (final r in recordsRaw) {
      final map = Map<String, Object?>.from(r['values'] as Map? ?? {});
      records.add(MarketPortfolioRecord(
        portfolioType: MarketPortfolioType.bonds,
        values: map,
      ));
    }
    
    print('Parsed MarketPortfolioRecord count: ${records.length}');
    
    final service = FxSecurityAnalysisService();
    final result = service.analyzePortfolio(
      records: records,
      analysisDate: DateTime.now(),
    );
    
    print('FX Analysis result:');
    print('  Securities count: ${result.securities.length}');
    print('  Exposures count: ${result.currencyExposures.length}');
    print('  Total Exposure: ${result.totalExposure}');
    
    if (result.securities.isEmpty) {
      print('No securities in result. Printing details of some records to check why:');
      for (int i = 0; i < records.length && i < 10; i++) {
        final r = records[i];
        print('Record $i:');
        print('  ID Titre: ${r.titleId}');
        print('  Issuer: ${r.issuer}');
        print('  Currency (raw): ${r.values['Devise']}');
        print('  Currency (getter): ${r.currency}');
        print('  Quantity: ${r.quantity}');
        print('  Nominal: ${r.nominalUnit}');
        print('  Maturity Date: ${r.maturityDate}');
      }
    } else {
      print('Securities in result:');
      for (final s in result.securities) {
        print('  Title: ${s.titleName} | Devise: ${s.currency} | Qty: ${s.quantity} | Val: ${s.initialValue}');
      }
    }
  });
}
