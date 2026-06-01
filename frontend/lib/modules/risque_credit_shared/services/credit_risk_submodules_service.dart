import 'dart:math' as math;

import '../../../core/services/rwa_api_service.dart';
import '../../../core/utils/formatters.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../../expositions/models/exposition_models.dart';
import '../../crm/models/crm_models.dart';
import '../models/credit_risk_models.dart';

class CreditRiskSubmodulesService {
  CreditRiskSubmodulesService(this.api);

  final RwaApiService api;

  static final Map<String, CreditGuaranteeRecord> _editedGuarantees = {};
  static final Set<String> _deletedGuaranteeIds = <String>{};
  static final List<CreditGuaranteeRecord> _customGuarantees =
      <CreditGuaranteeRecord>[];
  static final List<CreditReportHistoryRecord> _reportHistory =
      <CreditReportHistoryRecord>[];

  Future<GuaranteesModuleData> fetchGuaranteesModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final crmModule = await api.fetchCrmModule();
    final baseGuarantees = _buildBaseGuarantees(
      exposureModule.exposures,
      crmModule.items,
    );

    final merged = <CreditGuaranteeRecord>[
      for (final item in baseGuarantees)
        if (!_deletedGuaranteeIds.contains(item.id))
          _editedGuarantees[item.id] ?? item,
      ..._customGuarantees.where(
        (item) => !_deletedGuaranteeIds.contains(item.id),
      ),
    ]..sort((left, right) => right.expirationDate.compareTo(left.expirationDate));

    final exposureOptions = exposureModule.exposures
        .map(
          (item) => CreditExposureOption(
            id: item.id,
            label: '${item.id} • ${item.counterparty.name}',
            counterpartyName: item.counterparty.name,
            category: item.categoryLabel,
            currency: item.currency,
            grossAmount: item.grossAmount,
          ),
        )
        .toList()
      ..sort((left, right) => left.label.compareTo(right.label));

    final now = DateTime.now();
    final activeGuarantees =
        merged.where((item) => !_isExpired(item.expirationDate, now)).toList();
    final summary = CreditGuaranteeSummary(
      totalGuarantees: merged.length,
      activeValue: activeGuarantees.fold<double>(
        0.0,
        (sum, item) => sum + item.value,
      ),
      averageCoverage: merged.isEmpty
          ? 0.0
          : merged.fold<double>(0.0, (sum, item) => sum + item.coverageRatio) /
              merged.length,
      expiringSoonCount: merged.where((item) {
        if (_isExpired(item.expirationDate, now)) {
          return false;
        }
        final days = item.expirationDate.difference(now).inDays;
        return days <= 90;
      }).length,
    );

    return GuaranteesModuleData(
      guarantees: merged,
      exposureOptions: exposureOptions,
      summary: summary,
    );
  }

  Future<void> upsertGuarantee(CreditGuaranteeDraft draft) async {
    final exposureModule = await api.fetchExpositionsModule();
    final exposure = exposureModule.exposures.firstWhere(
      (item) => item.id == draft.exposureId,
    );

    final id = draft.id ?? _nextGuaranteeId();
    final record = CreditGuaranteeRecord(
      id: id,
      exposureId: exposure.id,
      exposureLabel: '${exposure.id} • ${exposure.counterparty.name}',
      counterpartyName: exposure.counterparty.name,
      sector: _sectorFromCategory(exposure.categoryLabel),
      type: draft.type,
      value: draft.value,
      currency: draft.currency,
      coverageRatio: draft.coverageRatio.clamp(0.0, 1.0).toDouble(),
      expirationDate: draft.expirationDate,
      status: draft.status,
      sourceLabel: id.startsWith('CRM') ? 'CRM ajuste' : 'Saisie manuelle',
      rwaLinked: true,
    );

    _deletedGuaranteeIds.remove(id);
    final customIndex = _customGuarantees.indexWhere((item) => item.id == id);
    if (customIndex >= 0) {
      _customGuarantees[customIndex] = record;
      return;
    }

    if (id.startsWith('CRM')) {
      _editedGuarantees[id] = record;
      return;
    }

    _customGuarantees.insert(0, record);
  }

  Future<void> deleteGuarantee(String id) async {
    _editedGuarantees.remove(id);
    _customGuarantees.removeWhere((item) => item.id == id);
    _deletedGuaranteeIds.add(id);
  }

  Future<DefaultsModuleData> fetchDefaultsModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final guarantees = await fetchGuaranteesModule();
    final activeCoverageByExposure = <String, double>{};

    for (final item in guarantees.guarantees) {
      if (_isExpired(item.expirationDate, DateTime.now())) {
        continue;
      }
      activeCoverageByExposure.update(
        item.exposureId,
        (value) => math.max(value, item.coverageRatio),
        ifAbsent: () => item.coverageRatio,
      );
    }

    final candidates = [...exposureModule.exposures]
      ..sort((left, right) {
        final rightScore = _defaultRiskScore(right);
        final leftScore = _defaultRiskScore(left);
        return rightScore.compareTo(leftScore);
      });

    final records = candidates
        .take(math.min(6, candidates.length))
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => _buildDefaultRecord(
            entry.value,
            index: entry.key,
            activeCoverage: activeCoverageByExposure[entry.value.id] ?? 0.0,
          ),
        )
        .toList(growable: false);

    final summary = CreditDefaultSummary(
      totalDefaults: records.length,
      totalDefaultGross: records.fold<double>(
        0.0,
        (sum, item) => sum + item.grossAmount,
      ),
      totalProvision: records.fold<double>(
        0.0,
        (sum, item) => sum + item.estimatedProvision,
      ),
      averageDaysPastDue: records.isEmpty
          ? 0.0
          : records.fold<double>(0.0, (sum, item) => sum + item.daysPastDue) /
              records.length,
    );

    return DefaultsModuleData(items: records, summary: summary);
  }

  Future<ConcentrationModuleData> fetchConcentrationModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final exposures = exposureModule.exposures;
    final totalGross = exposures.fold<double>(
      0.0,
      (sum, item) => sum + item.grossAmount,
    );

    final sectorTotals = <String, double>{};
    final sectorCounts = <String, int>{};
    final countryTotals = <String, double>{};
    final ratingTotals = <String, double>{};

    for (final item in exposures) {
      final sector = _sectorFromCategory(item.categoryLabel);
      sectorTotals.update(
        sector,
        (value) => value + item.grossAmount,
        ifAbsent: () => item.grossAmount,
      );
      sectorCounts.update(sector, (value) => value + 1, ifAbsent: () => 1);
      countryTotals.update(
        item.counterparty.country,
        (value) => value + item.grossAmount,
        ifAbsent: () => item.grossAmount,
      );
      ratingTotals.update(
        item.ratingLabel,
        (value) => value + item.grossAmount,
        ifAbsent: () => item.grossAmount,
      );
    }

    final sectorRows = sectorTotals.entries
        .map(
          (entry) => SectorConcentrationRow(
            sector: entry.key,
            exposureCount: sectorCounts[entry.key] ?? 0,
            grossAmount: entry.value,
            share: totalGross == 0 ? 0.0 : entry.value / totalGross,
          ),
        )
        .toList()
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));

    final topExposures = exposures
        .map(
          (item) => ConcentrationExposureRow(
            exposureId: item.id,
            counterpartyName: item.counterparty.name,
            country: item.counterparty.country,
            sector: _sectorFromCategory(item.categoryLabel),
            grossAmount: item.grossAmount,
            rwa: item.rwa,
            share: totalGross == 0 ? 0.0 : item.grossAmount / totalGross,
          ),
        )
        .toList()
      ..sort((left, right) => right.grossAmount.compareTo(left.grossAmount));

    final sectorDistribution = _distributionFromTotals(sectorTotals, totalGross);
    final countryDistribution =
        _distributionFromTotals(countryTotals, totalGross).take(5).toList();
    final ratingDistribution =
        _distributionFromTotals(ratingTotals, totalGross).take(5).toList();

    final topSectorShare =
        sectorRows.isEmpty ? 0.0 : sectorRows.first.share.clamp(0.0, 1.0).toDouble();
    final topThreeShare = sectorRows
        .take(3)
        .fold<double>(0.0, (sum, item) => sum + item.share)
        .clamp(0.0, 1.0)
        .toDouble();
    final hhi = sectorRows.fold<double>(
      0.0,
      (sum, item) => sum + math.pow(item.share * 100, 2).toDouble(),
    );

    return ConcentrationModuleData(
      summary: ConcentrationSummary(
        totalGross: totalGross,
        topSectorShare: topSectorShare,
        topThreeShare: topThreeShare,
        herfindahlIndex: hhi,
        counterpartyCount:
            exposures.map((item) => item.counterparty.name).toSet().length,
      ),
      sectorRows: sectorRows,
      topExposures: topExposures.take(8).toList(growable: false),
      sectorDistribution: sectorDistribution,
      countryDistribution: countryDistribution,
      ratingDistribution: ratingDistribution,
    );
  }

  Future<CreditReportingModuleData> fetchReportingModule() async {
    final exposureModule = await api.fetchExpositionsModule();
    final guaranteesModule = await fetchGuaranteesModule();
    final defaultsModule = await fetchDefaultsModule();

    final snapshots = [
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.portfolio,
        itemCount: exposureModule.exposures.length,
        totalAmount: exposureModule.summary.totalExpositions,
      ),
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.guarantees,
        itemCount: guaranteesModule.guarantees.length,
        totalAmount: guaranteesModule.guarantees.fold<double>(
          0.0,
          (sum, item) => sum + item.value,
        ),
      ),
      CreditReportingFamilySnapshot(
        family: CreditReportFamily.defaults,
        itemCount: defaultsModule.items.length,
        totalAmount: defaultsModule.summary.totalDefaultGross,
      ),
    ];

    final summary = CreditReportingSummary(
      generatedReports: _reportHistory.length,
      excelExports: _reportHistory
          .where((item) => item.format == CreditExportFormat.excel)
          .length,
      pdfExports: _reportHistory
          .where((item) => item.format == CreditExportFormat.pdf)
          .length,
    );

    return CreditReportingModuleData(
      familySnapshots: snapshots,
      history: List<CreditReportHistoryRecord>.unmodifiable(_reportHistory),
      summary: summary,
    );
  }

  Future<CreditExportDataset> buildExportDataset(
    CreditReportFamily family,
  ) async {
    switch (family) {
      case CreditReportFamily.portfolio:
        final module = await api.fetchExpositionsModule();
        return CreditExportDataset(
          sheetName: 'Portefeuille',
          headers: const [
            'ID',
            'Contrepartie',
            'Pays',
            'Categorie',
            'Notation',
            'Montant brut',
            'EAD',
            'RWA',
            'Capital',
            'CRM',
          ],
          rows: module.exposures
              .map(
                (item) => [
                  item.id,
                  item.counterparty.name,
                  item.counterparty.country,
                  item.categoryLabel,
                  item.ratingLabel,
                  _number(item.grossAmount),
                  _number(item.ead),
                  _number(item.rwa),
                  _number(item.capital),
                  item.crmModeLabel,
                ],
              )
              .toList(growable: false),
          totalAmount: module.summary.totalExpositions,
        );
      case CreditReportFamily.guarantees:
        final module = await fetchGuaranteesModule();
        return CreditExportDataset(
          sheetName: 'Garanties',
          headers: const [
            'ID',
            'Exposition',
            'Contrepartie',
            'Secteur',
            'Type',
            'Valeur',
            'Couverture',
            'Expiration',
            'Statut',
            'Source',
          ],
          rows: module.guarantees
              .map(
                (item) => [
                  item.id,
                  item.exposureLabel,
                  item.counterpartyName,
                  item.sector,
                  item.type,
                  _number(item.value),
                  _percent(item.coverageRatio),
                  AppFormatters.shortDate(item.expirationDate),
                  item.status,
                  item.sourceLabel,
                ],
              )
              .toList(growable: false),
          totalAmount: module.guarantees.fold<double>(
            0.0,
            (sum, item) => sum + item.value,
          ),
        );
      case CreditReportFamily.defaults:
        final module = await fetchDefaultsModule();
        return CreditExportDataset(
          sheetName: 'Defauts',
          headers: const [
            'Exposition',
            'Contrepartie',
            'Pays',
            'Secteur',
            'Notation',
            'Jours de retard',
            'Statut prudentiel',
            'Provision estimee',
            'Taux de provision',
            'Incidents',
          ],
          rows: module.items
              .map(
                (item) => [
                  item.exposureId,
                  item.counterpartyName,
                  item.country,
                  item.sector,
                  item.rating,
                  item.daysPastDue.toString(),
                  item.prudentialStatus,
                  _number(item.estimatedProvision),
                  _percent(item.provisionRate),
                  item.incidents.length.toString(),
                ],
              )
              .toList(growable: false),
          totalAmount: module.summary.totalDefaultGross,
        );
    }
  }

  Future<CreditReportHistoryRecord> registerExport({
    required CreditReportFamily family,
    required CreditExportFormat format,
    required String fileName,
    required int lineCount,
    required double totalAmount,
  }) async {
    final record = CreditReportHistoryRecord(
      id: 'RCR${(_reportHistory.length + 1).toString().padLeft(3, '0')}',
      createdAt: DateTime.now(),
      family: family,
      format: format,
      fileName: fileName,
      lineCount: lineCount,
      totalAmount: totalAmount,
    );
    _reportHistory.insert(0, record);
    return record;
  }

  List<CreditGuaranteeRecord> _buildBaseGuarantees(
    List<ExposureRecord> exposures,
    List<CrmRecord> crmItems,
  ) {
    final exposureById = {
      for (final item in exposures) item.id: item,
    };

    return crmItems.map((item) {
      final exposure = exposureById[item.exposureId];
      final expirationDate = exposure?.maturityDate ??
          exposure?.analysisDate.add(
            Duration(days: 240 + (item.coverageRatio * 160).round()),
          ) ??
          DateTime.now().add(const Duration(days: 180));

      return CreditGuaranteeRecord(
        id: item.id,
        exposureId: item.exposureId,
        exposureLabel: '${item.exposureId} • ${item.borrowerName}',
        counterpartyName: item.borrowerName,
        sector: _sectorFromCategory(item.borrowerCategory),
        type: item.guaranteeType,
        value: item.coverageAmount,
        currency: 'XOF',
        coverageRatio: item.coverageRatio,
        expirationDate: expirationDate,
        status: _resolveGuaranteeStatus(expirationDate),
        sourceLabel: 'CRM RWA',
        rwaLinked: true,
      );
    }).toList(growable: false);
  }

  CreditDefaultRecord _buildDefaultRecord(
    ExposureRecord exposure, {
    required int index,
    required double activeCoverage,
  }) {
    final baseDelay = switch (exposure.ratingLabel) {
      'BB/B' => 78,
      'BBB' => 46,
      'A' => 21,
      _ => exposure.isDefaultLike ? 96 : 34,
    };
    final daysPastDue = baseDelay + (index * 11);
    final prudentialStatus = _prudentialStatusForDelay(daysPastDue);
    final rawProvisionRate = switch (prudentialStatus) {
      'Defaut prudentiel' => 0.38,
      'Sous surveillance renforcee' => 0.24,
      'Surveillance' => 0.15,
      _ => 0.08,
    };
    final provisionRate =
        (rawProvisionRate - (activeCoverage * 0.10)).clamp(0.05, 0.45).toDouble();
    final incidents = _incidentHistory(
      exposure: exposure,
      daysPastDue: daysPastDue,
      prudentialStatus: prudentialStatus,
    );

    return CreditDefaultRecord(
      exposureId: exposure.id,
      counterpartyName: exposure.counterparty.name,
      country: exposure.counterparty.country,
      sector: _sectorFromCategory(exposure.categoryLabel),
      rating: exposure.ratingLabel,
      grossAmount: exposure.grossAmount,
      ead: exposure.ead,
      rwa: exposure.rwa,
      capital: exposure.capital,
      daysPastDue: daysPastDue,
      prudentialStatus: prudentialStatus,
      estimatedProvision: exposure.ead * provisionRate,
      provisionRate: provisionRate,
      incidents: incidents,
    );
  }

  List<CreditIncidentEvent> _incidentHistory({
    required ExposureRecord exposure,
    required int daysPastDue,
    required String prudentialStatus,
  }) {
    final referenceDate = exposure.analysisDate;
    final firstDate = referenceDate.subtract(Duration(days: daysPastDue));
    final secondDate = referenceDate.subtract(
      Duration(days: math.max(5, daysPastDue ~/ 2)),
    );
    final thirdDate = referenceDate.subtract(const Duration(days: 7));
    return [
      CreditIncidentEvent(
        date: thirdDate,
        title: prudentialStatus,
        description:
            'Revue du dossier ${exposure.id} et ajustement du niveau de surveillance.',
      ),
      CreditIncidentEvent(
        date: secondDate,
        title: 'Relance client',
        description:
            'Relance formelle envoyee a ${exposure.counterparty.name} sur les echeances impayees.',
      ),
      CreditIncidentEvent(
        date: firstDate,
        title: 'Premier incident',
        description:
            'Retard detecte sur l exposition ${exposure.id} avec suivi renforcé.',
      ),
    ];
  }

  List<DistributionEntry> _distributionFromTotals(
    Map<String, double> totals,
    double globalAmount,
  ) {
    final entries = totals.entries
        .map(
          (entry) => DistributionEntry(
            label: entry.key,
            amount: entry.value,
            percentage: globalAmount == 0 ? 0.0 : entry.value / globalAmount,
          ),
        )
        .toList()
      ..sort((left, right) => right.amount.compareTo(left.amount));
    return entries;
  }

  double _defaultRiskScore(ExposureRecord exposure) {
    var score = exposure.rwa;
    if (exposure.isDefaultLike) {
      score += 250000000;
    }
    if (exposure.ratingLabel == 'BB/B') {
      score += 180000000;
    }
    if (exposure.crmModeLabel == 'Aucune') {
      score += 60000000;
    }
    score += exposure.finalRw * 10000000;
    return score;
  }

  bool _isExpired(DateTime expirationDate, DateTime now) {
    final baseline = DateTime(now.year, now.month, now.day);
    return expirationDate.isBefore(baseline);
  }

  String _resolveGuaranteeStatus(DateTime expirationDate) {
    final now = DateTime.now();
    if (_isExpired(expirationDate, now)) {
      return 'Expiree';
    }
    if (expirationDate.difference(now).inDays <= 90) {
      return 'A renouveler';
    }
    return 'Active';
  }

  String _prudentialStatusForDelay(int daysPastDue) {
    if (daysPastDue >= 90) {
      return 'Defaut prudentiel';
    }
    if (daysPastDue >= 60) {
      return 'Sous surveillance renforcee';
    }
    if (daysPastDue >= 30) {
      return 'Surveillance';
    }
    return 'Pre-alerte';
  }

  String _sectorFromCategory(String category) {
    final normalized = category
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a');
    if (normalized.contains('souverain') ||
        normalized.contains('organismes pub')) {
      return 'Secteur public';
    }
    if (normalized.contains('institution')) {
      return 'Interbancaire';
    }
    if (normalized.contains('entreprise')) {
      return 'Corporate';
    }
    if (normalized.contains('detail')) {
      return 'Retail';
    }
    if (normalized.contains('immo')) {
      return 'Immobilier';
    }
    if (normalized.contains('souffrance')) {
      return 'Defaut';
    }
    return 'Autres';
  }

  String _nextGuaranteeId() {
    final existingIds = <String>[
      ..._customGuarantees.map((item) => item.id),
      ..._editedGuarantees.keys,
    ];
    var max = 0;
    for (final id in existingIds) {
      if (!id.startsWith('GAR')) {
        continue;
      }
      final parsed = int.tryParse(id.substring(3));
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'GAR${(max + 1).toString().padLeft(3, '0')}';
  }

  String _number(double value) => value.toStringAsFixed(0);
  String _percent(double value) => '${(value * 100).toStringAsFixed(1)} %';
}
