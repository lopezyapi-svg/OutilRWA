import 'package:flutter/material.dart';

import '../../core/localization/app_localization.dart';
import '../../core/theme/app_theme.dart';
import 'mini_trend_chart.dart';

class KpiMetricCard extends StatefulWidget {
  const KpiMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
    this.trend = const <double>[],
    this.fullValue,
    this.height = 104,
    this.borderRadius = AppTheme.radius,
    this.onTap,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;
  final List<double> trend;
  final String? fullValue;
  final double height;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<KpiMetricCard> createState() => _KpiMetricCardState();
}

class _KpiMetricCardState extends State<KpiMetricCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parts = _KpiValueParts.from(widget.value);
    final expandedValue = _expandedHoverValue(
      parts: parts,
      compactValue: widget.value,
      fullValue: widget.fullValue,
    );
    final showExpandedValue = _hovered && expandedValue != null;
    final surface = isDark ? AppTheme.darkCard : Colors.white;
    final border = isDark ? AppTheme.darkBorder : const Color(0xFFD9E5F4);
    final titleColor = isDark ? AppTheme.darkText : AppTheme.text;
    final mutedColor = isDark ? AppTheme.darkMuted : AppTheme.muted;
    final indicatorInfo = _KpiIndicatorInfo.resolve(
      label: widget.label,
      helper: widget.helper,
    );
    final contentPadding = EdgeInsets.fromLTRB(
      14,
      showExpandedValue ? 8 : 10,
      14,
      showExpandedValue ? 5 : 8,
    );
    final trendValues =
        widget.trend.isEmpty ? const [0.0, 1.0, 0.4, 1.2] : widget.trend;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            return Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, 7 * (1 - progress)),
                child: child,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            height: widget.height,
            transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _hovered ? widget.color.withValues(alpha: 0.54) : border,
                width: _hovered ? 1.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: _hovered ? 0.16 : 0.09)
                      : const Color(0xFF9DB2D1).withValues(
                          alpha: _hovered ? 0.16 : 0.08,
                        ),
                  blurRadius: _hovered ? 18 : 12,
                  offset: Offset(0, _hovered ? 8 : 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 28,
                    child: Container(
                      width: 92,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(widget.borderRadius),
                          bottomRight: Radius.circular(widget.borderRadius),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 22,
                    width: 76,
                    height: 34,
                    child: Opacity(
                      opacity: isDark ? 0.16 : 0.12,
                      child: MiniTrendChart(
                        values: trendValues,
                        color: widget.color,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: mutedColor.withValues(alpha: 0.60),
                    ),
                  ),
                  Padding(
                    padding: contentPadding,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 180.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IndicatorTooltip(
                              info: indicatorInfo,
                              accent: widget.color,
                              isDark: isDark,
                              borderRadius: widget.borderRadius,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.color.withValues(
                                    alpha: isDark ? 0.13 : 0.08,
                                  ),
                                  border: Border.all(
                                    color: widget.color.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: widget.color,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomLeft,
                                  child: SizedBox(
                                    width: contentWidth,
                                    child: _KpiTextBlock(
                                      parts: parts,
                                      accent: widget.color,
                                      titleColor: titleColor,
                                      mutedColor: mutedColor,
                                      label: widget.label,
                                      helper: widget.helper,
                                      showExpandedValue: showExpandedValue,
                                      expandedValue: expandedValue,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndicatorTooltip extends StatelessWidget {
  const _IndicatorTooltip({
    required this.info,
    required this.accent,
    required this.isDark,
    required this.borderRadius,
    required this.child,
  });

  final _KpiIndicatorInfo info;
  final Color accent;
  final bool isDark;
  final double borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background =
        isDark ? const Color(0xFF101B2E) : const Color(0xFF0F172A);
    const bodyColor = Color(0xFFEAF1FF);
    const mutedColor = Color(0xFFAFC0DA);

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: info.title.tr(context),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.4,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.summary.tr(context)}',
            style: const TextStyle(
              color: bodyColor,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nCalcul',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.formula.tr(context)}',
            style: const TextStyle(
              color: bodyColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nRéférences',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.references.tr(context)}',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 9.6,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          TextSpan(
            text: '\n\nLecture',
            style: TextStyle(
              color: accent,
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: '\n${info.reading.tr(context)}',
            style: const TextStyle(
              color: mutedColor,
              fontSize: 9.6,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minWidth: 260,
        maxWidth: 340,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      margin: const EdgeInsets.all(12),
      preferBelow: false,
      verticalOffset: 15,
      waitDuration: const Duration(milliseconds: 220),
      showDuration: const Duration(seconds: 9),
      textAlign: TextAlign.left,
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.44)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _KpiIndicatorInfo {
  const _KpiIndicatorInfo({
    required this.title,
    required this.summary,
    required this.formula,
    required this.references,
    required this.reading,
  });

  final String title;
  final String summary;
  final String formula;
  final String references;
  final String reading;

  static _KpiIndicatorInfo resolve({
    required String label,
    required String helper,
  }) {
    final text = '$label $helper'.toLowerCase();

    if (text.contains('solv') || text.contains('cet1')) {
      return const _KpiIndicatorInfo(
        title: 'Ratio de solvabilité',
        summary:
            'Mesure la capacité de la banque à couvrir ses risques pondérés par ses fonds propres éligibles.',
        formula:
            'Ratio = fonds propres réglementaires éligibles / RWA total. Le CET1 retient le noyau dur des fonds propres.',
        references:
            'Repères Bâle III et dispositif prudentiel BCEAO/UMOA : fonds propres, exigences minimales et coussins prudentiels.',
        reading:
            'Un ratio élevé indique une marge de solvabilité plus confortable ; une baisse signale une pression sur le capital.',
      );
    }

    if (text.contains('npl') ||
        text.contains('defaut') ||
        text.contains('défaut') ||
        text.contains('pd')) {
      return const _KpiIndicatorInfo(
        title: 'Qualité du portefeuille',
        summary:
            'Suit le poids des défauts, retards ou probabilités de défaut dans le portefeuille analysé.',
        formula:
            'NPL = encours non performants / exposition brute. PD = moyenne pondérée des probabilités de défaut disponibles.',
        references:
            'Dispositif prudentiel BCEAO/UMOA : créances en souffrance et défaut prudentiel, avec repère interne aux paragraphes 152 à 160.',
        reading:
            'Une hausse détériore la qualité crédit, augmente la surveillance et peut peser sur les pondérations ou provisions.',
      );
    }

    if (text.contains('ead') || text.contains('exposition')) {
      return const _KpiIndicatorInfo(
        title: 'Exposition au défaut',
        summary:
            'Représente le montant exposé au risque après prise en compte du bilan, du hors-bilan et des conversions applicables.',
        formula:
            'EAD = exposition bilan + exposition hors-bilan convertie par CCF, avant ou après filtres selon le module.',
        references:
            'Approche standard BCEAO/UMOA : traitement des expositions, engagements hors bilan et facteurs de conversion CCF.',
        reading:
            'Plus l’EAD est élevée, plus le portefeuille alimente fortement le RWA et le capital minimum requis.',
      );
    }

    if (text.contains('capital')) {
      return const _KpiIndicatorInfo(
        title: 'Capital minimum requis',
        summary:
            'Estime le montant de fonds propres réglementaires à immobiliser pour couvrir les actifs pondérés.',
        formula:
            'Capital minimum = RWA total x taux réglementaire cible. Le taux standard utilisé dans l’outil est 8 %.',
        references:
            'Cadre Bâle III et dispositif prudentiel BCEAO/UMOA : exigence de fonds propres et pilotage des coussins.',
        reading:
            'Une hausse traduit une consommation de capital plus importante et réduit les marges disponibles.',
      );
    }

    if (text.contains('var')) {
      return const _KpiIndicatorInfo(
        title: 'VaR globale',
        summary:
            'Mesure une perte potentielle maximale sur un horizon donné, pour un niveau de confiance défini.',
        formula:
            'VaR = quantile de perte du portefeuille selon l’horizon, la volatilité et les corrélations retenues.',
        references:
            'Référentiel de risque de marché : exigences internes de mesure, backtesting et limites de marché.',
        reading:
            'Une VaR élevée signale une exposition de marché plus sensible aux mouvements défavorables.',
      );
    }

    if (text.contains('incident') || text.contains('operationnel')) {
      return const _KpiIndicatorInfo(
        title: 'Incidents critiques',
        summary:
            'Synthétise les événements opérationnels majeurs nécessitant un suivi renforcé ou une action corrective.',
        formula:
            'Indicateur = nombre d’incidents classés critiques selon la gravité, l’impact financier et le statut de traitement.',
        references:
            'Cadre de risque opérationnel : collecte des pertes, suivi KRI, contrôle interne et plans d’actions.',
        reading:
            'Un niveau élevé appelle une priorisation des contrôles, des plans correctifs et de l’escalade managériale.',
      );
    }

    if (text.contains('expected loss') || text.contains('perte attendue')) {
      return const _KpiIndicatorInfo(
        title: 'Expected Loss',
        summary:
            'Estime la perte moyenne attendue du portefeuille sur la base des paramètres de risque disponibles.',
        formula:
            'EL = EAD x PD x LGD. Lorsque les paramètres sont absents, l’indicateur reste à zéro ou non disponible.',
        references:
            'Référentiel crédit : paramètres EAD, PD, LGD, défaut et suivi des pertes attendues.',
        reading:
            'Une EL élevée indique une perte statistique attendue plus importante et peut guider le provisionnement.',
      );
    }

    if (text.contains('couverture') || text.contains('crm')) {
      return const _KpiIndicatorInfo(
        title: 'Couverture CRM',
        summary:
            'Mesure la part du risque couverte par des techniques éligibles de réduction du risque de crédit.',
        formula:
            'Couverture = montant couvert éligible / exposition concernée, après règles d’éligibilité et décotes applicables.',
        references:
            'Approche standard BCEAO/UMOA : garanties, sûretés, CRM éligible, décotes et traitement des garants.',
        reading:
            'Une bonne couverture peut réduire le risque résiduel, le RWA et le besoin de capital.',
      );
    }

    if (text.contains('risque residuel') || text.contains('résiduel')) {
      return const _KpiIndicatorInfo(
        title: 'Risque résiduel',
        summary:
            'Montant de risque restant après prise en compte des garanties et mécanismes de mitigation.',
        formula:
            'Risque résiduel = exposition brute - protections reconnues, selon les règles CRM appliquées.',
        references:
            'Référentiel CRM et garanties : éligibilité, valorisation, décotes et reconnaissance prudentielle.',
        reading:
            'Un risque résiduel élevé montre que la protection économique ou prudentielle reste insuffisante.',
      );
    }

    return const _KpiIndicatorInfo(
      title: 'RWA - Actifs pondérés aux risques',
      summary:
          'Indicateur prudentiel central qui transforme les expositions en risque pondéré selon leur catégorie et leur qualité.',
      formula:
          'RWA = somme des EAD x pondération prudentielle, après CCF hors bilan et CRM éligible lorsque applicable.',
      references:
          'Approche standard du dispositif prudentiel BCEAO/UMOA : catégories prudentielles, notations, CCF, défauts et CRM.',
      reading:
          'Plus le RWA est élevé, plus la consommation de capital réglementaire augmente.',
    );
  }
}

class _KpiTextBlock extends StatelessWidget {
  const _KpiTextBlock({
    required this.parts,
    required this.accent,
    required this.titleColor,
    required this.mutedColor,
    required this.label,
    required this.helper,
    required this.showExpandedValue,
    required this.expandedValue,
  });

  final _KpiValueParts parts;
  final Color accent;
  final Color titleColor;
  final Color mutedColor;
  final String label;
  final String helper;
  final bool showExpandedValue;
  final String? expandedValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiValueText(
          parts: parts,
          accent: accent,
          titleColor: titleColor,
          mutedColor: mutedColor,
        ),
        if (showExpandedValue)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: _KpiExpandedValueText(
              value: expandedValue ?? '',
              accent: accent,
              mutedColor: mutedColor,
            ),
          )
        else
          const SizedBox(height: 5),
        Text(
          label.tr(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontFamily: AppTheme.fontFamily,
            fontSize: 10.8,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        if (!showExpandedValue) ...[
          const SizedBox(height: 2),
          Text(
            helper.tr(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontFamily: AppTheme.fontFamily,
              fontSize: 7.6,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

class _KpiValueText extends StatelessWidget {
  const _KpiValueText({
    required this.parts,
    required this.accent,
    required this.titleColor,
    required this.mutedColor,
  });

  final _KpiValueParts parts;
  final Color accent;
  final Color titleColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final unit = parts.unit;
    final suffix = parts.suffix;

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        maxLines: 1,
        text: TextSpan(
          children: [
            TextSpan(
              text: parts.number,
              style: TextStyle(
                color: titleColor,
                fontFamily: AppTheme.fontFamily,
                fontSize: 19.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            if (unit != null)
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: accent,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            if (suffix != null)
              TextSpan(
                text: '  $suffix',
                style: TextStyle(
                  color: mutedColor.withValues(alpha: 0.78),
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 8.8,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiExpandedValueText extends StatelessWidget {
  const _KpiExpandedValueText({
    required this.value,
    required this.accent,
    required this.mutedColor,
  });

  final String value;
  final Color accent;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: mutedColor.withValues(alpha: 0.95),
              fontFamily: AppTheme.fontFamily,
              fontSize: 9.4,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiValueParts {
  const _KpiValueParts({
    required this.number,
    this.unit,
    this.suffix,
  });

  final String number;
  final String? unit;
  final String? suffix;

  static const _currencySuffixes = {'FCFA', 'XOF', 'EUR', 'USD'};

  factory _KpiValueParts.from(String raw) {
    final normalized =
        raw.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const _KpiValueParts(number: 'N/D');
    }

    final tokens = normalized.split(' ');
    if (tokens.length == 1) {
      return _KpiValueParts(number: normalized);
    }

    final first = tokens.first.toUpperCase();
    final last = tokens.last.toUpperCase();
    if (_currencySuffixes.contains(first) && tokens.length >= 2) {
      return _KpiValueParts(
        number: tokens[1],
        unit: tokens.length > 2
            ? tokens.sublist(2, tokens.length).join(' ')
            : null,
        suffix: tokens.first,
      );
    }

    if (_currencySuffixes.contains(last)) {
      return _KpiValueParts(
        number: tokens.first,
        unit: tokens.length > 2
            ? tokens.sublist(1, tokens.length - 1).join(' ')
            : null,
        suffix: tokens.last,
      );
    }

    return _KpiValueParts(
      number: tokens.first,
      unit: tokens.sublist(1).join(' '),
    );
  }
}

String? _expandedHoverValue({
  required _KpiValueParts parts,
  required String compactValue,
  required String? fullValue,
}) {
  final normalizedCompact = _normalizeValueText(compactValue);
  final normalizedFull = _normalizeValueText(fullValue);
  if (normalizedFull != null && normalizedFull != normalizedCompact) {
    return fullValue!.trim();
  }

  return _expandedCompactCurrency(parts);
}

String? _expandedCompactCurrency(_KpiValueParts parts) {
  final multiplier = _compactUnitMultiplier(parts.unit);
  if (multiplier == null) {
    return null;
  }

  final numericValue = _parseLocalizedNumber(parts.number);
  if (numericValue == null) {
    return null;
  }

  final expandedNumber = _groupInteger((numericValue * multiplier).round());
  if (parts.suffix == null) {
    return expandedNumber;
  }
  return '$expandedNumber ${parts.suffix}';
}

double? _compactUnitMultiplier(String? unit) {
  if (unit == null) {
    return null;
  }

  final normalized = unit.toLowerCase();
  if (normalized.contains('milliard') || normalized.contains('billion')) {
    return 1000000000;
  }
  if (normalized.contains('million')) {
    return 1000000;
  }
  if (normalized.contains('mille') || normalized.contains('thousand')) {
    return 1000;
  }
  return null;
}

double? _parseLocalizedNumber(String value) {
  final normalized = value
      .replaceAll('\u00a0', '')
      .replaceAll(' ', '')
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String _groupInteger(int value) {
  final sign = value < 0 ? '-' : '';
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }
  return '$sign$buffer';
}

String? _normalizeValueText(String? value) {
  final trimmed =
      value?.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return trimmed?.isEmpty ?? true ? null : trimmed;
}
