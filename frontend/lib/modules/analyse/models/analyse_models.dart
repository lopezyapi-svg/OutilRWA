// Modèles de données pour le module d'analyse.
import 'package:flutter/material.dart';

import '../../dashboard/models/dashboard_models.dart';

/// Données complètes d'analyse du portefeuille.
class AnalyseData {
  const AnalyseData({
    required this.portfolioQualityScore,
    required this.qualityTrend,
    required this.concentrationLevel,
    required this.concentrationTrend,
    required this.crmCoverageRatio,
    required this.crmTrend,
    required this.rwaReductionPotential,
    required this.sectorDistribution,
    required this.sectorInsights,
    required this.ratingDistribution,
    required this.ratingInsights,
    required this.topConcentration,
    required this.lowRatedExposure,
    required this.weightedAverageRating,
    required this.rwaEvolution,
    required this.rwaVariation,
    required this.currentCapital,
    required this.prudentialAlerts,
    required this.topRiskExposures,
    required this.recommendations,
  });

  final double portfolioQualityScore;
  final String qualityTrend;
  final double concentrationLevel;
  final String concentrationTrend;
  final double crmCoverageRatio;
  final String crmTrend;
  final double rwaReductionPotential;
  final List<DistributionEntry> sectorDistribution;
  final List<String> sectorInsights;
  final List<DistributionEntry> ratingDistribution;
  final List<String> ratingInsights;
  final DistributionEntry? topConcentration;
  final double lowRatedExposure;
  final String? weightedAverageRating;
  final List<RwaEvolutionPoint> rwaEvolution;
  final double rwaVariation;
  final double currentCapital;
  final List<PrudentialAlert> prudentialAlerts;
  final List<RiskExposure> topRiskExposures;
  final List<AnalyseRecommendation> recommendations;
}

/// Point d'évolution du RWA dans le temps.
class RwaEvolutionPoint {
  const RwaEvolutionPoint({
    required this.label,
    required this.value,
    required this.date,
  });

  final String label;
  final double value;
  final DateTime date;
}

/// Alerte prudentielle.
class PrudentialAlert {
  const PrudentialAlert({
    required this.severity,
    required this.message,
    required this.action,
  });

  final String severity;
  final String message;
  final String action;
}

/// Exposition à risque.
class RiskExposure {
  const RiskExposure({
    required this.counterparty,
    required this.rwa,
    required this.rating,
    required this.category,
  });

  final String counterparty;
  final double rwa;
  final String rating;
  final String category;
}

/// Recommandation d'optimisation.
class AnalyseRecommendation {
  const AnalyseRecommendation({
    required this.title,
    required this.description,
    required this.impact,
    required this.effort,
    required this.priority,
    required this.category,
    required this.estimatedSaving,
    required this.actions,
  });

  final String title;
  final String description;
  final String impact;
  final String effort;
  final String priority;
  final String category;
  final double? estimatedSaving;
  final List<String> actions;
}

/// KPI d'analyse.
class AnalyseKpi {
  const AnalyseKpi({
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
    required this.color,
    required this.trend,
  });

  final String label;
  final String value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final String trend;
}

/// Insight d'analyse.
class AnalyseInsight {
  const AnalyseInsight({
    required this.icon,
    required this.severity,
    required this.message,
    required this.recommendation,
  });

  final IconData icon;
  final String severity;
  final String message;
  final String recommendation;
}
