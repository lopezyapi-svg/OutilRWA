// Ce fichier centralise tous les espacements de l'application.
import 'package:flutter/material.dart';

/// Système d'espacement standardisé pour l'outil RWA.
/// Remplace les valeurs d'espacement hardcodées.
class AppSpacing {
  AppSpacing._();

  // Espacements de base
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Espacements pour les pages
  static const double pagePadding = lg; // 16
  static const double pageGap = md; // 12

  // Espacements pour les cartes
  static const double cardPadding = lg; // 16
  static const double cardGap = md; // 12
  static const double cardInnerGap = sm; // 8

  // Espacements pour les sections
  static const double sectionPadding = xl; // 24
  static const double sectionGap = lg; // 16
  static const double sectionHeaderGap = md; // 12

  // Espacements pour les formulaires
  static const double formFieldGap = md; // 12
  static const double formSectionGap = xl; // 24
  static const double formLabelGap = xs; // 4

  // Espacements pour les tableaux
  static const double tableCellPadding = md; // 12
  static const double tableRowGap = sm; // 8
  static const double tableHeaderGap = lg; // 16

  // Espacements pour les boutons
  static const double buttonPaddingHorizontal = lg; // 16
  static const double buttonPaddingVertical = md; // 12
  static const double buttonGap = sm; // 8

  // Espacements pour les KPI et métriques
  static const double kpiPadding = lg; // 16
  static const double kpiGap = md; // 12
  static const double kpiLabelGap = xs; // 4

  // EdgeInsets prédéfinis pour usage courant
  static const EdgeInsets pageInsets = EdgeInsets.all(pagePadding);
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);
  static const EdgeInsets sectionInsets = EdgeInsets.all(sectionPadding);
  static const EdgeInsets formFieldInsets = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets buttonInsets = EdgeInsets.symmetric(
    horizontal: buttonPaddingHorizontal,
    vertical: buttonPaddingVertical,
  );
  static const EdgeInsets kpiInsets = EdgeInsets.all(kpiPadding);

  // Gaps prédéfinis (pour Column, Row, Wrap, etc.)
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // Gaps horizontaux
  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
  static const SizedBox hGapXl = SizedBox(width: xl);

  // Gaps verticaux
  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);
}
