// Service d'analyse des données RWA.
import '../../../core/services/rwa_api_service.dart';
import '../../dashboard/models/dashboard_models.dart';
import '../models/analyse_models.dart';

/// Service qui génère les analyses et recommandations.
class AnalyseService {
  const AnalyseService(this.api);

  final RwaApiService api;

  /// Récupère et calcule toutes les données d'analyse.
  Future<AnalyseData> fetchAnalyseData() async {
    final dashboard = await api.fetchDashboard();
    final exposures = await api.fetchExpositionsModule();
    final crm = await api.fetchCrmModule();

    // Calcul de la qualité du portefeuille
    final qualityScore = _calculatePortfolioQuality(
      dashboard.ratingDistribution,
      exposures.exposures.length,
    );

    // Calcul du niveau de concentration
    final concentrationLevel = _calculateConcentration(
      dashboard.categoryDistribution,
      dashboard.countryDistribution,
    );

    // Ratio de couverture CRM
    final crmCoverage = crm.summary.totalExpositions > 0
        ? (crm.summary.totalExpositions -
                (crm.summary.totalRwaBefore - crm.summary.totalRwaAfter)) /
            crm.summary.totalExpositions
        : 0.0;

    // Potentiel de réduction RWA
    final reductionPotential = _calculateRwaReductionPotential(
      exposures.exposures,
      crm.summary,
    );

    // Distribution par secteur (catégories)
    final sectorDistribution = dashboard.categoryDistribution;
    final sectorInsights = _generateSectorInsights(sectorDistribution);

    // Distribution par notation
    final ratingDistribution = dashboard.ratingDistribution;
    final ratingInsights = _generateRatingInsights(ratingDistribution);

    // Top concentration
    final topConcentration = _findTopConcentration(sectorDistribution);

    // Exposition aux notations spéculatives
    final lowRatedExposure = _calculateLowRatedExposure(ratingDistribution);

    // Notation moyenne pondérée
    final weightedAvgRating = _calculateWeightedAverageRating(
      ratingDistribution,
    );

    // Évolution RWA (simulée à partir des projections)
    final rwaEvolution = _generateRwaEvolution(dashboard.rwaProjection);

    // Variation RWA
    final rwaVariation = rwaEvolution.length >= 2
        ? (rwaEvolution.last.value - rwaEvolution.first.value) /
            rwaEvolution.first.value
        : 0.0;

    // Capital actuel
    final capitalMetric = dashboard.metrics.firstWhere(
      (m) => m.key == 'capital',
      orElse: () => const DashboardMetric(
        key: 'capital',
        label: 'Capital',
        value: 0,
        variation: '0%',
        trend: [],
      ),
    );

    // Alertes prudentielles
    final prudentialAlerts = _generatePrudentialAlerts(
      dashboard,
      concentrationLevel,
      lowRatedExposure,
    );

    // Top expositions à risque
    final topRiskExposures = _identifyTopRiskExposures(
      dashboard.portfolioOverview,
    );

    // Recommandations
    final recommendations = _generateRecommendations(
      concentrationLevel,
      lowRatedExposure,
      crmCoverage,
      reductionPotential,
      topRiskExposures,
    );

    return AnalyseData(
      portfolioQualityScore: qualityScore,
      qualityTrend: 'stable',
      concentrationLevel: concentrationLevel,
      concentrationTrend: 'up',
      crmCoverageRatio: crmCoverage,
      crmTrend: 'up',
      rwaReductionPotential: reductionPotential,
      sectorDistribution: sectorDistribution,
      sectorInsights: sectorInsights,
      ratingDistribution: ratingDistribution,
      ratingInsights: ratingInsights,
      topConcentration: topConcentration,
      lowRatedExposure: lowRatedExposure,
      weightedAverageRating: weightedAvgRating,
      rwaEvolution: rwaEvolution,
      rwaVariation: rwaVariation,
      currentCapital: capitalMetric.value,
      prudentialAlerts: prudentialAlerts,
      topRiskExposures: topRiskExposures,
      recommendations: recommendations,
    );
  }

  double _calculatePortfolioQuality(
    List<DistributionEntry> ratings,
    int exposureCount,
  ) {
    if (ratings.isEmpty || exposureCount == 0) return 5.0;

    var score = 0.0;
    var totalWeight = 0.0;

    for (final entry in ratings) {
      final weight = entry.percentage;
      final ratingScore = _ratingToScore(entry.label);
      score += ratingScore * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? score / totalWeight : 5.0;
  }

  double _ratingToScore(String rating) {
    final r = rating.toUpperCase();
    if (r.startsWith('AAA')) return 10.0;
    if (r.startsWith('AA')) return 9.0;
    if (r.startsWith('A')) return 7.5;
    if (r.startsWith('BBB')) return 6.0;
    if (r.startsWith('BB')) return 4.5;
    if (r.startsWith('B')) return 3.0;
    return 2.0;
  }

  double _calculateConcentration(
    List<DistributionEntry> categories,
    List<DistributionEntry> countries,
  ) {
    // Indice de Herfindahl-Hirschman pour mesurer la concentration
    var hhi = 0.0;
    for (final entry in categories) {
      hhi += entry.percentage * entry.percentage;
    }
    for (final entry in countries) {
      hhi += entry.percentage * entry.percentage;
    }

    // Normalisation (0 = bien diversifié, 1 = très concentré)
    return (hhi / 2).clamp(0.0, 1.0);
  }

  double _calculateRwaReductionPotential(
    List<dynamic> exposures,
    dynamic crmSummary,
  ) {
    // Estimation du potentiel de réduction via optimisation CRM
    final totalRwa = crmSummary.totalRwaAfter as double;
    return totalRwa * 0.15; // 15% de potentiel d'optimisation
  }

  List<String> _generateSectorInsights(List<DistributionEntry> distribution) {
    final insights = <String>[];
    if (distribution.isEmpty) return insights;

    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    if (sorted.first.percentage > 0.4) {
      insights.add(
        'Forte concentration sur ${sorted.first.label} (${(sorted.first.percentage * 100).toStringAsFixed(0)}%)',
      );
    }

    if (sorted.length >= 3) {
      final top3 = sorted.take(3).fold<double>(
            0.0,
            (sum, e) => sum + e.percentage,
          );
      if (top3 > 0.7) {
        insights.add('Les 3 premiers secteurs représentent 70%+ du portefeuille');
      }
    }

    return insights;
  }

  List<String> _generateRatingInsights(List<DistributionEntry> distribution) {
    final insights = <String>[];
    if (distribution.isEmpty) return insights;

    final investmentGrade = distribution.where((e) {
      final r = e.label.toUpperCase();
      return r.startsWith('AAA') ||
          r.startsWith('AA') ||
          r.startsWith('A') ||
          r.startsWith('BBB');
    }).fold<double>(0.0, (sum, e) => sum + e.percentage);

    if (investmentGrade > 0.7) {
      insights.add(
        'Portefeuille de qualité: ${(investmentGrade * 100).toStringAsFixed(0)}% investment grade',
      );
    } else if (investmentGrade < 0.4) {
      insights.add(
        'Attention: seulement ${(investmentGrade * 100).toStringAsFixed(0)}% investment grade',
      );
    }

    return insights;
  }

  DistributionEntry? _findTopConcentration(
    List<DistributionEntry> distribution,
  ) {
    if (distribution.isEmpty) return null;
    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));
    return sorted.first.percentage > 0.25 ? sorted.first : null;
  }

  double _calculateLowRatedExposure(List<DistributionEntry> distribution) {
    return distribution.where((e) {
      final r = e.label.toUpperCase();
      return r.startsWith('BB') || r.startsWith('B') || r.contains('NON');
    }).fold<double>(0.0, (sum, e) => sum + e.percentage);
  }

  String? _calculateWeightedAverageRating(
    List<DistributionEntry> distribution,
  ) {
    if (distribution.isEmpty) return null;

    // Calcul simplifié : prendre la notation avec le plus gros poids
    final sorted = List<DistributionEntry>.from(distribution)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return sorted.first.label;
  }

  List<RwaEvolutionPoint> _generateRwaEvolution(
    List<DashboardProjectionPoint> projection,
  ) {
    final now = DateTime.now();
    return projection.asMap().entries.map((entry) {
      return RwaEvolutionPoint(
        label: entry.value.label,
        value: entry.value.value,
        date: DateTime(now.year, now.month - (12 - entry.key), 1),
      );
    }).toList();
  }

  List<PrudentialAlert> _generatePrudentialAlerts(
    DashboardSnapshot dashboard,
    double concentrationLevel,
    double lowRatedExposure,
  ) {
    final alerts = <PrudentialAlert>[];

    // Alerte concentration
    if (concentrationLevel > 0.4) {
      alerts.add(
        const PrudentialAlert(
          severity: 'high',
          message: 'Concentration de portefeuille élevée',
          action: 'Diversifier les expositions sur plusieurs secteurs et pays',
        ),
      );
    }

    // Alerte qualité crédit
    if (lowRatedExposure > 0.2) {
      alerts.add(
        const PrudentialAlert(
          severity: 'medium',
          message: 'Exposition significative aux notations spéculatives',
          action: 'Renforcer les garanties ou réduire ces expositions',
        ),
      );
    }

    // Alerte ratio de solvabilité
    final solvencyMetric = dashboard.metrics.firstWhere(
      (m) => m.key == 'solvabilite',
      orElse: () => const DashboardMetric(
        key: 'solvabilite',
        label: 'Solvabilité',
        value: 0.15,
        variation: '0%',
        trend: [],
      ),
    );

    if (solvencyMetric.value < 0.09) {
      alerts.add(
        const PrudentialAlert(
          severity: 'critical',
          message: 'Ratio de solvabilité sous le minimum réglementaire (9%)',
          action: 'Augmenter les fonds propres ou réduire les RWA',
        ),
      );
    } else if (solvencyMetric.value < 0.115) {
      alerts.add(
        const PrudentialAlert(
          severity: 'medium',
          message: 'Ratio de solvabilité proche du seuil cible (11.5%)',
          action: 'Maintenir une marge de sécurité prudentielle',
        ),
      );
    }

    return alerts;
  }

  List<RiskExposure> _identifyTopRiskExposures(
    List<PortfolioRow> portfolio,
  ) {
    final sorted = List<PortfolioRow>.from(portfolio)
      ..sort((a, b) => b.rwa.compareTo(a.rwa));

    return sorted.take(10).map((row) {
      return RiskExposure(
        counterparty: row.counterparty,
        rwa: row.rwa,
        rating: row.rating,
        category: row.category,
      );
    }).toList();
  }

  List<AnalyseRecommendation> _generateRecommendations(
    double concentrationLevel,
    double lowRatedExposure,
    double crmCoverage,
    double reductionPotential,
    List<RiskExposure> topRisks,
  ) {
    final recommendations = <AnalyseRecommendation>[];

    // Recommandation: Diversification
    if (concentrationLevel > 0.3) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Diversifier le portefeuille',
          description:
              'Le niveau de concentration actuel (${(concentrationLevel * 100).toStringAsFixed(0)}%) expose la banque à un risque systémique. Une diversification géographique et sectorielle est recommandée.',
          impact: 'high',
          effort: 'medium',
          priority: 'high',
          category: 'diversification',
          estimatedSaving: null,
          actions: [
            'Identifier de nouveaux secteurs et zones géographiques',
            'Fixer des limites de concentration par secteur (max 25%)',
            'Réviser les politiques d\'octroi de crédit',
          ],
        ),
      );
    }

    // Recommandation: Améliorer la couverture CRM
    if (crmCoverage < 0.5) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Augmenter la couverture CRM',
          description:
              'Seulement ${(crmCoverage * 100).toStringAsFixed(0)}% des expositions sont couvertes par des techniques de réduction du risque. Une meilleure utilisation du CRM peut réduire significativement le capital requis.',
          impact: 'high',
          effort: 'medium',
          priority: 'high',
          category: 'crm',
          estimatedSaving: reductionPotential * 0.3,
          actions: [
            'Exiger des garanties sur les expositions non notées',
            'Négocier des collatéraux pour les contreparties BB/B',
            'Utiliser l\'assurance-crédit pour les PME',
          ],
        ),
      );
    }

    // Recommandation: Réduire les expositions spéculatives
    if (lowRatedExposure > 0.15) {
      recommendations.add(
        AnalyseRecommendation(
          title: 'Réduire les expositions spéculatives',
          description:
              '${(lowRatedExposure * 100).toStringAsFixed(0)}% du portefeuille présente une notation spéculative (BB/B). Ces expositions génèrent un RWA élevé et augmentent le risque de défaut.',
          impact: 'high',
          effort: 'high',
          priority: 'medium',
          category: 'quality',
          estimatedSaving: reductionPotential * 0.25,
          actions: [
            'Établir un plan de sortie progressive',
            'Renégocier les conditions avec garanties renforcées',
            'Provisionner adéquatement ces expositions',
          ],
        ),
      );
    }

    // Recommandation: Optimiser les expositions à fort RWA
    if (topRisks.isNotEmpty) {
      final topRwa = topRisks.take(3).fold<double>(0.0, (sum, e) => sum + e.rwa);
      recommendations.add(
        AnalyseRecommendation(
          title: 'Optimiser les top 3 expositions à fort RWA',
          description:
              'Les 3 principales expositions représentent un RWA significatif. Une optimisation ciblée peut générer d\'importantes économies de capital.',
          impact: 'medium',
          effort: 'low',
          priority: 'high',
          category: 'optimization',
          estimatedSaving: topRwa * 0.2,
          actions: [
            'Restructurer avec garanties étatiques ou bancaires',
            'Titriser une partie de ces expositions',
            'Utiliser des dérivés de crédit (CDS)',
          ],
        ),
      );
    }

    // Recommandation: Améliorer la notation des contreparties
    recommendations.add(
      const AnalyseRecommendation(
        title: 'Programme d\'accompagnement crédit',
        description:
            'Mettre en place un programme pour améliorer la notation interne des contreparties prometteuses, réduisant ainsi mécaniquement le RWA.',
        impact: 'medium',
        effort: 'medium',
        priority: 'low',
        category: 'quality',
        estimatedSaving: null,
        actions: [
          'Former les analystes crédit aux meilleures pratiques',
          'Développer un système de notation interne robuste',
          'Accompagner les clients dans l\'amélioration de leur profil',
        ],
      ),
    );

    // Trier par priorité
    recommendations.sort((a, b) {
      final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      return (priorityOrder[a.priority] ?? 99)
          .compareTo(priorityOrder[b.priority] ?? 99);
    });

    return recommendations;
  }
}



