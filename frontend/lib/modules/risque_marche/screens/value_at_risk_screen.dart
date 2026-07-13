// Onglet VALUE AT RISK (VaR) alimenté par le backend.
//
// Les trois méthodes (historique, paramétrique, Monte-Carlo) sont calculées
// côté serveur via /api/var/* ; cet écran ne fait aucun calcul financier,
// il ne fait qu'afficher les données reçues (valeurs en Md FCFA, formatées
// en convention française à l'affichage).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/services/api_client.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';

const Color _varNavy = Color(0xFF0F1B3D);
const Color _varDeepBlue = Color(0xFF001F4E);
const Color _varPrimary = Color(0xFF2563EB);
const Color _varBarBlue = Color(0xFF9DC2F9);
const Color _varDanger = Color(0xFFEF4444);
const Color _varOrange = Color(0xFFF59E0B);
const Color _varMuted = Color(0xFF64748B);
const Color _varBorder = Color(0xFFDDE7F5);
const Color _varSurface = Color(0xFFFFFFFF);
const Color _varSurfaceSoft = Color(0xFFF8FAFC);

const double _parameterPanelWidth = 340;

final NumberFormat _formatMd = NumberFormat('#,##0.0', 'fr_FR');
final NumberFormat _formatAxe = NumberFormat('#,##0.#', 'fr_FR');
final NumberFormat _formatPct2 = NumberFormat('#,##0.00', 'fr_FR');
final NumberFormat _formatEntier = NumberFormat('#,##0', 'fr_FR');

String _md(num valeur) => '${_formatMd.format(valeur)} Md FCFA';

String _pourcentage(double fraction) => '${_formatPct2.format(fraction * 100)} %';

enum VarMethode { historique, parametrique, monteCarlo }

extension on VarMethode {
  String get segment => switch (this) {
        VarMethode.historique => 'historique',
        VarMethode.parametrique => 'parametrique',
        VarMethode.monteCarlo => 'montecarlo',
      };

  String get libelle => switch (this) {
        VarMethode.historique => 'VaR Historique',
        VarMethode.parametrique => 'VaR Paramétrique',
        VarMethode.monteCarlo => 'VaR Monte-Carlo',
      };

  String get definition => switch (this) {
        VarMethode.historique =>
          'La VaR (Value at Risk, valeur en risque) historique estime la '
              'perte maximale probable à partir du quantile des pertes '
              'réellement observées sur la fenêtre choisie.',
        VarMethode.parametrique =>
          'La VaR paramétrique suppose des pertes et gains distribués selon '
              'une loi normale et déduit la perte maximale probable de la '
              'moyenne et de l\'écart-type estimés.',
        VarMethode.monteCarlo =>
          'La VaR Monte-Carlo estime la perte maximale probable à partir de '
              'milliers de scénarios simulés calibrés sur l\'historique.',
      };
}

/// Classe d'histogramme reçue du backend.
class _ClasseHistogramme {
  const _ClasseHistogramme(this.borneInf, this.borneSup, this.effectif);

  final double borneInf;
  final double borneSup;
  final int effectif;
}

/// Réponse d'un endpoint /api/var/*, sans aucun recalcul côté client.
class _ReponseVar {
  const _ReponseVar({
    required this.methode,
    required this.sourceDonnees,
    required this.valeurPortefeuille,
    required this.varValeur,
    required this.expectedShortfall,
    required this.pirePerte,
    required this.p95,
    required this.p99,
    required this.tauxDepassementPct,
    required this.nombreObservations,
    required this.histogramme,
    this.courbeNormale = const [],
    this.hypotheseNormaleDouteuse = false,
    this.nbSimulations,
    this.graine,
    this.icVarBasse,
    this.icVarHaute,
  });

  final String methode;
  final String sourceDonnees;
  final double valeurPortefeuille;
  final double varValeur;
  final double expectedShortfall;
  final double pirePerte;
  final double p95;
  final double p99;
  final double tauxDepassementPct;
  final int nombreObservations;
  final List<_ClasseHistogramme> histogramme;
  final List<Offset> courbeNormale;
  final bool hypotheseNormaleDouteuse;
  final int? nbSimulations;
  final int? graine;
  final double? icVarBasse;
  final double? icVarHaute;

  static double _d(dynamic valeur) => (valeur as num).toDouble();

  factory _ReponseVar.fromJson(Map<String, dynamic> json) {
    final classes = <_ClasseHistogramme>[
      for (final brut in (json['histogramme'] as List))
        _ClasseHistogramme(
          _d((brut as Map)['borne_inf']),
          _d(brut['borne_sup']),
          (brut['effectif'] as num).toInt(),
        ),
    ];
    final courbe = <Offset>[
      for (final point in (json['courbe_normale'] as List? ?? const []))
        Offset(_d((point as Map)['x']), _d(point['y'])),
    ];
    final ic = json['ic_var_95'] as Map?;
    return _ReponseVar(
      methode: json['methode'] as String,
      sourceDonnees: json['source_donnees'] as String,
      valeurPortefeuille: _d(json['valeur_portefeuille']),
      varValeur: _d(json['var']),
      expectedShortfall: _d(json['expected_shortfall']),
      pirePerte: _d(json['pire_perte']),
      p95: _d(json['p95']),
      p99: _d(json['p99']),
      tauxDepassementPct: _d(json['taux_depassement_pct']),
      nombreObservations: (json['nombre_observations'] as num).toInt(),
      histogramme: classes,
      courbeNormale: courbe,
      hypotheseNormaleDouteuse:
          json['hypothese_normale_douteuse'] as bool? ?? false,
      nbSimulations: (json['nb_simulations'] as num?)?.toInt(),
      graine: (json['graine'] as num?)?.toInt(),
      icVarBasse: ic == null ? null : _d(ic['borne_basse']),
      icVarHaute: ic == null ? null : _d(ic['borne_haute']),
    );
  }
}

class ValueAtRiskScreen extends StatefulWidget {
  const ValueAtRiskScreen({super.key, required this.api});

  final RwaApiService api;

  @override
  State<ValueAtRiskScreen> createState() => _ValueAtRiskScreenState();
}

class _ValueAtRiskScreenState extends State<ValueAtRiskScreen> {
  static const String _portefeuilleDefaut = 'obligations';
  static const double _confianceDefaut = 0.99;
  static const int _horizonDefaut = 1;
  static const int _fenetreDefaut = 500;
  static const int _simulationsDefaut = 10000;

  VarMethode _methode = VarMethode.historique;
  String _portefeuille = _portefeuilleDefaut;
  double _confiance = _confianceDefaut;
  int _horizon = _horizonDefaut;
  int _fenetre = _fenetreDefaut;
  int _nbSimulations = _simulationsDefaut;

  _ReponseVar? _reponse;
  bool _chargement = false;
  String? _erreur;
  bool _donneesAbsentes = false;
  int _requeteEnCours = 0;
  Timer? _relanceAutomatique;

  // Sans données, l'écran réinterroge le serveur à intervalle régulier :
  // les fichiers déposés dans data/ sont ainsi chargés automatiquement.
  static const Duration _delaiRelance = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _relanceAutomatique?.cancel();
    super.dispose();
  }

  void _programmerRelanceAutomatique() {
    _relanceAutomatique?.cancel();
    _relanceAutomatique = Timer(_delaiRelance, () {
      if (mounted && _erreur != null) _charger();
    });
  }

  Future<void> _charger() async {
    final numero = ++_requeteEnCours;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final json = await widget.api.fetchVarAnalysis(
        methode: _methode.segment,
        typePortefeuille: _portefeuille,
        niveauConfiance: _confiance,
        horizonJours: _horizon,
        fenetreJours: _fenetre,
        nbSimulations:
            _methode == VarMethode.monteCarlo ? _nbSimulations : null,
      );
      if (!mounted || numero != _requeteEnCours) return;
      _relanceAutomatique?.cancel();
      setState(() {
        _reponse = _ReponseVar.fromJson(json);
        _chargement = false;
        _donneesAbsentes = false;
      });
    } catch (erreur) {
      if (!mounted || numero != _requeteEnCours) return;
      final donneesAbsentes = erreur is ApiException &&
          erreur.detail is Map &&
          (erreur.detail as Map)['code'] == 'VAR_DONNEES_ABSENTES';
      setState(() {
        _chargement = false;
        _erreur = erreur.toString();
        _donneesAbsentes = donneesAbsentes;
        if (donneesAbsentes) {
          // Les données absentes rendent l'ancienne réponse caduque.
          _reponse = null;
        }
      });
      _programmerRelanceAutomatique();
    }
  }

  void _changerMethode(VarMethode methode) {
    if (methode == _methode) return;
    setState(() => _methode = methode);
    _charger();
  }

  void _reinitialiser() {
    setState(() {
      _portefeuille = _portefeuilleDefaut;
      _confiance = _confianceDefaut;
      _horizon = _horizonDefaut;
      _fenetre = _fenetreDefaut;
      _nbSimulations = _simulationsDefaut;
    });
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: PageHeader(
            title: 'VALUE AT RISK (VaR)',
            titleFontSize: 26,
            trailing: _SelecteurMethode(
              selection: _methode,
              onChanged: _changerMethode,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              0,
              AppTheme.pagePadding,
              AppTheme.pagePadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _parameterPanelWidth,
                  child: _PanneauParametres(
                    methode: _methode,
                    portefeuille: _portefeuille,
                    confiance: _confiance,
                    horizon: _horizon,
                    fenetre: _fenetre,
                    nbSimulations: _nbSimulations,
                    onPortefeuille: (valeur) {
                      setState(() => _portefeuille = valeur);
                      _charger();
                    },
                    onConfiance: (valeur) {
                      setState(() => _confiance = valeur);
                      _charger();
                    },
                    onHorizon: (valeur) {
                      setState(() => _horizon = valeur);
                      _charger();
                    },
                    onFenetre: (valeur) {
                      setState(() => _fenetre = valeur);
                      _charger();
                    },
                    onNbSimulations: (valeur) {
                      setState(() => _nbSimulations = valeur);
                      _charger();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _contenuPrincipal()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenuPrincipal() {
    final reponse = _reponse;
    if (_erreur != null && reponse == null) {
      return _CarteVar(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _donneesAbsentes
                    ? 'Aucune donnée chargée'
                    : 'Le calcul de la VaR est indisponible',
                style: const TextStyle(
                  color: _varNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  _erreur!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _varMuted, fontSize: 12.5),
                ),
              ),
              if (_donneesAbsentes) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(strokeWidth: 1.4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Les nouvelles données seront chargées automatiquement '
                      'dès leur import.',
                      style: TextStyle(
                        color: _varNavy.withValues(alpha: 0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _charger,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (reponse == null) {
      return const _CarteVar(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RangeeKpi(
          methode: _methode,
          reponse: reponse,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _CarteVar(
            child: _PanneauGraphique(
              methode: _methode,
              reponse: reponse,
              confiance: _confiance,
              chargement: _chargement,
              erreur: _erreur,
              onReinitialiser: _reinitialiser,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sélecteur de méthode (onglets en haut à droite)
// ---------------------------------------------------------------------------

class _SelecteurMethode extends StatelessWidget {
  const _SelecteurMethode({required this.selection, required this.onChanged});

  final VarMethode selection;
  final ValueChanged<VarMethode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _varSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _varBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final methode in VarMethode.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _OngletMethode(
                methode: methode,
                actif: methode == selection,
                onTap: () => onChanged(methode),
              ),
            ),
        ],
      ),
    );
  }
}

class _OngletMethode extends StatelessWidget {
  const _OngletMethode({
    required this.methode,
    required this.actif,
    required this.onTap,
  });

  final VarMethode methode;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: actif ? _varPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              methode.libelle,
              style: TextStyle(
                color: actif ? Colors.white : _varNavy,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: methode.definition,
              waitDuration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: actif ? Colors.white70 : _varMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau des paramètres de calcul
// ---------------------------------------------------------------------------

class _PanneauParametres extends StatelessWidget {
  const _PanneauParametres({
    required this.methode,
    required this.portefeuille,
    required this.confiance,
    required this.horizon,
    required this.fenetre,
    required this.nbSimulations,
    required this.onPortefeuille,
    required this.onConfiance,
    required this.onHorizon,
    required this.onFenetre,
    required this.onNbSimulations,
  });

  final VarMethode methode;
  final String portefeuille;
  final double confiance;
  final int horizon;
  final int fenetre;
  final int nbSimulations;
  final ValueChanged<String> onPortefeuille;
  final ValueChanged<double> onConfiance;
  final ValueChanged<int> onHorizon;
  final ValueChanged<int> onFenetre;
  final ValueChanged<int> onNbSimulations;

  @override
  Widget build(BuildContext context) {
    return _CarteVar(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres de calcul',
              style: TextStyle(
                color: _varNavy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _GroupeChoix<String>(
              libelle: 'Type de portefeuille',
              valeur: portefeuille,
              valeurs: const ['obligations', 'actions'],
              libellePour: (valeur) =>
                  valeur == 'obligations' ? 'Obligations' : 'Actions',
              onChanged: onPortefeuille,
            ),
            _GroupeChoix<double>(
              libelle: 'Niveau de confiance',
              valeur: confiance,
              valeurs: const [0.95, 0.975, 0.99],
              libellePour: _pourcentage,
              onChanged: onConfiance,
            ),
            _GroupeChoix<int>(
              libelle: 'Horizon',
              valeur: horizon,
              valeurs: const [1, 3, 10, 21],
              libellePour: (valeur) => switch (valeur) {
                1 => '1 jour',
                21 => '1 mois',
                _ => '$valeur jours',
              },
              onChanged: onHorizon,
            ),
            _GroupeChoix<int>(
              libelle: 'Fenêtre historique',
              valeur: fenetre,
              valeurs: const [250, 500, 1000],
              libellePour: (valeur) => '$valeur jours',
              onChanged: onFenetre,
            ),
            if (methode == VarMethode.monteCarlo)
              _GroupeChoix<int>(
                libelle: 'Nombre de simulations',
                valeur: nbSimulations,
                valeurs: const [1000, 10000, 50000],
                libellePour: (valeur) => _formatEntier.format(valeur),
                onChanged: onNbSimulations,
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupeChoix<T> extends StatelessWidget {
  const _GroupeChoix({
    required this.libelle,
    required this.valeur,
    required this.valeurs,
    required this.libellePour,
    required this.onChanged,
  });

  final String libelle;
  final T valeur;
  final List<T> valeurs;
  final String Function(T) libellePour;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            libelle,
            style: const TextStyle(
              color: _varMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _varSurfaceSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _varBorder),
            ),
            child: Row(
              children: [
                for (final choix in valeurs)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (choix != valeur) onChanged(choix);
                      },
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: choix == valeur
                              ? _varDeepBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          libellePour(choix),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                choix == valeur ? Colors.white : _varNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartes KPI
// ---------------------------------------------------------------------------

class _RangeeKpi extends StatelessWidget {
  const _RangeeKpi({required this.methode, required this.reponse});

  final VarMethode methode;
  final _ReponseVar reponse;

  @override
  Widget build(BuildContext context) {
    final libelleVar = switch (methode) {
      VarMethode.historique => 'VAR HISTORIQUE',
      VarMethode.parametrique => 'VAR PARAMÉTRIQUE',
      VarMethode.monteCarlo => 'VAR MONTE-CARLO',
    };
    final libellePire = methode == VarMethode.monteCarlo
        ? 'PIRE PERTE SIMULÉE'
        : 'PIRE PERTE OBSERVÉE';
    final cartes = [
      ('VALEUR DU PORTEFEUILLE', reponse.valeurPortefeuille, _varNavy),
      (libelleVar, reponse.varValeur, _varNavy),
      ('EXPECTED SHORTFALL', reponse.expectedShortfall, _varNavy),
      (libellePire, reponse.pirePerte, _varDanger),
    ];
    return Row(
      children: [
        for (var indice = 0; indice < cartes.length; indice++) ...[
          if (indice > 0) const SizedBox(width: 12),
          Expanded(
            child: _CarteKpi(
              libelle: cartes[indice].$1,
              valeur: cartes[indice].$2,
              accent: cartes[indice].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class _CarteKpi extends StatelessWidget {
  const _CarteKpi({
    required this.libelle,
    required this.valeur,
    required this.accent,
  });

  final String libelle;
  final double valeur;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _varSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _varBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _varMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _md(valeur),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _varNavy,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panneau graphique
// ---------------------------------------------------------------------------

class _PanneauGraphique extends StatelessWidget {
  const _PanneauGraphique({
    required this.methode,
    required this.reponse,
    required this.confiance,
    required this.chargement,
    required this.erreur,
    required this.onReinitialiser,
  });

  final VarMethode methode;
  final _ReponseVar reponse;
  final double confiance;
  final bool chargement;
  final String? erreur;
  final VoidCallback onReinitialiser;

  String get _titre => switch (methode) {
        VarMethode.historique => 'Histogramme des pertes historiques',
        VarMethode.parametrique =>
          'Distribution des pertes et loi normale ajustée',
        VarMethode.monteCarlo => 'Distribution des pertes simulées',
      };

  String get _sousTitre => switch (methode) {
        VarMethode.historique =>
          'Distribution observée et seuil de perte VaR',
        VarMethode.parametrique =>
          'Histogramme observé et densité normale théorique',
        VarMethode.monteCarlo =>
          '${_formatEntier.format(reponse.nbSimulations ?? 0)} simulations, '
              'graine ${reponse.graine ?? 0}',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _varNavy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (reponse.sourceDonnees == 'simulation') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _varSurfaceSoft,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _varBorder),
                          ),
                          child: const Text(
                            'Données simulées',
                            style: TextStyle(
                              color: _varMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (chargement) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _sousTitre,
                    style: const TextStyle(color: _varMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Réinitialiser les paramètres',
              child: InkWell(
                onTap: onReinitialiser,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _varBorder),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    size: 15,
                    color: _varMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              erreur!,
              style: const TextStyle(color: _varDanger, fontSize: 11.5),
            ),
          ),
        if (methode == VarMethode.parametrique &&
            reponse.hypotheseNormaleDouteuse)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'La distribution observée s\'écarte de la loi normale '
              '(asymétrie ou queues épaisses), la VaR paramétrique peut '
              'sous-estimer le risque.',
              style: TextStyle(
                color: _varOrange.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: CustomPaint(
            painter: _HistogrammeVarPainter(
              methode: methode,
              reponse: reponse,
              confiance: confiance,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Peintre de l'histogramme
// ---------------------------------------------------------------------------

class _HistogrammeVarPainter extends CustomPainter {
  _HistogrammeVarPainter({
    required this.methode,
    required this.reponse,
    required this.confiance,
  });

  final VarMethode methode;
  final _ReponseVar reponse;
  final double confiance;

  static const double _gauche = 56;
  static const double _droite = 18;
  static const double _haut = 56;
  static const double _bas = 52;

  @override
  void paint(Canvas canvas, Size size) {
    final classes = reponse.histogramme;
    if (classes.isEmpty) return;
    final zone = Rect.fromLTRB(
      _gauche,
      _haut,
      math.max(_gauche + 10, size.width - _droite),
      math.max(_haut + 10, size.height - _bas),
    );

    var xMin = classes.first.borneInf;
    var xMax = classes.last.borneSup;
    for (final point in reponse.courbeNormale) {
      xMin = math.min(xMin, point.dx);
      xMax = math.max(xMax, point.dx);
    }
    xMax = math.max(xMax, reponse.varValeur);
    if (reponse.icVarHaute != null) {
      xMax = math.max(xMax, reponse.icVarHaute!);
    }
    final margeX = (xMax - xMin).abs() < 1e-9 ? 1.0 : (xMax - xMin) * 0.02;
    xMin -= margeX;
    xMax += margeX;

    var yMax = 0.0;
    for (final classe in classes) {
      yMax = math.max(yMax, classe.effectif.toDouble());
    }
    for (final point in reponse.courbeNormale) {
      yMax = math.max(yMax, point.dy);
    }
    if (yMax <= 0) yMax = 1;
    yMax *= 1.08;

    double xPixel(double valeur) =>
        zone.left + (valeur - xMin) / (xMax - xMin) * zone.width;
    double yPixel(double valeur) =>
        zone.bottom - (valeur / yMax) * zone.height;

    _peindreGrille(canvas, zone, yMax, xMin, xMax, xPixel);
    _peindreZoneExtreme(canvas, zone, xPixel);
    _peindreBandeIc(canvas, zone, xPixel);
    _peindreBarres(canvas, zone, classes, xPixel, yPixel);
    _peindreCourbeNormale(canvas, zone, xPixel, yPixel);
    _peindrePercentiles(canvas, zone, xPixel);
    _peindreLigneVar(canvas, zone, xPixel);
    _peindreAxes(canvas, zone, size);
  }

  void _peindreGrille(
    Canvas canvas,
    Rect zone,
    double yMax,
    double xMin,
    double xMax,
    double Function(double) xPixel,
  ) {
    final stylo = Paint()
      ..color = _varBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // Graduations entières de l'axe des fréquences.
    final pas = _pasEntier(yMax);
    for (var valeur = 0; valeur <= yMax; valeur += pas) {
      final y = zone.bottom - (valeur / yMax) * zone.height;
      canvas.drawLine(Offset(zone.left, y), Offset(zone.right, y), stylo);
      _texte(
        canvas,
        _formatEntier.format(valeur),
        Offset(zone.left - 8, y),
        couleur: _varMuted,
        taille: 10,
        alignementDroite: true,
        centreVertical: true,
      );
    }

    // Graduations horizontales en convention française.
    const nombreTicks = 8;
    for (var indice = 0; indice <= nombreTicks; indice++) {
      final valeur = xMin + (xMax - xMin) * indice / nombreTicks;
      final x = xPixel(valeur);
      canvas.drawLine(
        Offset(x, zone.bottom),
        Offset(x, zone.bottom + 4),
        Paint()
          ..color = _varMuted
          ..strokeWidth = 1,
      );
      _texte(
        canvas,
        _formatAxe.format(valeur),
        Offset(x, zone.bottom + 7),
        couleur: _varMuted,
        taille: 10,
        centreHorizontal: true,
      );
    }
  }

  int _pasEntier(double yMax) {
    final brut = yMax / 5;
    if (brut <= 1) return 1;
    final magnitude = math.pow(10, (math.log(brut) / math.ln10).floor());
    for (final facteur in [1, 2, 5, 10]) {
      final pas = (magnitude * facteur).round();
      if (pas >= brut) return math.max(1, pas);
    }
    return math.max(1, brut.ceil());
  }

  void _peindreZoneExtreme(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final xVar = xPixel(reponse.varValeur).clamp(zone.left, zone.right);
    final rect = Rect.fromLTRB(xVar, zone.top, zone.right, zone.bottom);
    if (rect.width <= 0) return;
    canvas.drawRect(
      rect,
      Paint()..color = _varOrange.withValues(alpha: 0.12),
    );
    // Étiquettes ancrées à gauche de la ligne VaR quand la zone orange est
    // trop étroite, pour éviter tout chevauchement avec la ligne rouge.
    _etiquetteAncree(
      canvas,
      zone,
      'Zone des pertes extrêmes',
      xVar,
      zone.top + 8,
      couleurTexte: _varOrange,
      couleurBord: _varOrange.withValues(alpha: 0.5),
    );
    final libelleTaux = methode == VarMethode.monteCarlo
        ? '${_formatPct2.format(reponse.tauxDepassementPct)} % des simulations dépassent ce seuil'
        : '${_formatPct2.format(reponse.tauxDepassementPct)} % des observations dépassent ce seuil';
    _etiquetteAncree(
      canvas,
      zone,
      libelleTaux,
      xVar,
      zone.top + 34,
      couleurTexte: _varDanger,
      couleurBord: _varDanger.withValues(alpha: 0.45),
    );
  }

  void _etiquetteAncree(
    Canvas canvas,
    Rect zone,
    String contenu,
    double xLigne,
    double y, {
    required Color couleurTexte,
    required Color couleurBord,
  }) {
    final largeurEstimee = contenu.length * 6.4 + 14;
    final xDroite = xLigne + 8;
    final x = xDroite + largeurEstimee <= zone.right
        ? xDroite
        : math.max(zone.left, xLigne - largeurEstimee - 8);
    _etiquette(
      canvas,
      contenu,
      Offset(x, y),
      couleurTexte: couleurTexte,
      couleurBord: couleurBord,
    );
  }

  void _peindreBandeIc(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final basse = reponse.icVarBasse;
    final haute = reponse.icVarHaute;
    if (basse == null || haute == null) return;
    final gauche = xPixel(basse).clamp(zone.left, zone.right);
    final droite = xPixel(haute).clamp(zone.left, zone.right);
    if (droite - gauche <= 0) return;
    canvas.drawRect(
      Rect.fromLTRB(gauche, zone.top, droite, zone.bottom),
      Paint()..color = _varDanger.withValues(alpha: 0.08),
    );
  }

  void _peindreBarres(
    Canvas canvas,
    Rect zone,
    List<_ClasseHistogramme> classes,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    for (final classe in classes) {
      if (classe.effectif <= 0) continue;
      final gauche = xPixel(classe.borneInf);
      final droite = xPixel(classe.borneSup);
      final haut = yPixel(classe.effectif.toDouble());
      final milieu = (classe.borneInf + classe.borneSup) / 2;
      final couleur =
          milieu >= reponse.varValeur ? _varOrange : _varBarBlue;
      final rect = Rect.fromLTRB(
        gauche + 1,
        haut,
        math.max(gauche + 2, droite - 1),
        zone.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = couleur.withValues(alpha: 0.85),
      );
    }
  }

  void _peindreCourbeNormale(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
    double Function(double) yPixel,
  ) {
    if (methode != VarMethode.parametrique || reponse.courbeNormale.isEmpty) {
      return;
    }
    final chemin = Path();
    var premier = true;
    for (final point in reponse.courbeNormale) {
      final position = Offset(xPixel(point.dx), yPixel(point.dy));
      if (premier) {
        chemin.moveTo(position.dx, position.dy);
        premier = false;
      } else {
        chemin.lineTo(position.dx, position.dy);
      }
    }
    canvas.drawPath(
      chemin,
      Paint()
        ..color = _varDeepBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _peindrePercentiles(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    for (final (valeur, libelle) in [
      (reponse.p95, 'P95'),
      (reponse.p99, 'P99'),
    ]) {
      final x = xPixel(valeur);
      if (x < zone.left || x > zone.right) continue;
      final stylo = Paint()
        ..color = _varNavy.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      _ligneVerticalePointillee(canvas, x, zone.top, zone.bottom, stylo);
      _etiquette(
        canvas,
        libelle,
        Offset(x - 14, zone.bottom - (libelle == 'P95' ? 26 : 52)),
        couleurTexte: _varNavy,
        couleurBord: _varBorder,
      );
    }
  }

  void _peindreLigneVar(
    Canvas canvas,
    Rect zone,
    double Function(double) xPixel,
  ) {
    final x = xPixel(reponse.varValeur).clamp(zone.left, zone.right);
    canvas.drawLine(
      Offset(x, zone.top - 6),
      Offset(x, zone.bottom),
      Paint()
        ..color = _varDanger
        ..strokeWidth = 2,
    );
    final libelle =
        'VaR ${_pourcentage(confiance)} : ${_md(reponse.varValeur)}';
    final largeurEstimee = libelle.length * 6.4 + 18;
    final xEtiquette = x + largeurEstimee + 12 > zone.right
        ? x - largeurEstimee - 10
        : x + 10;
    _etiquette(
      canvas,
      libelle,
      Offset(math.max(zone.left, xEtiquette), zone.top - 46),
      couleurTexte: _varDanger,
      couleurBord: _varDanger.withValues(alpha: 0.55),
    );
  }

  void _peindreAxes(Canvas canvas, Rect zone, Size size) {
    final stylo = Paint()
      ..color = _varMuted.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(zone.left, zone.top),
      Offset(zone.left, zone.bottom),
      stylo,
    );
    canvas.drawLine(
      Offset(zone.left, zone.bottom),
      Offset(zone.right, zone.bottom),
      stylo,
    );

    // Titre de l'axe vertical.
    _texte(
      canvas,
      'Fréquence',
      Offset(zone.left - 46, zone.top - 18),
      couleur: _varMuted,
      taille: 10.5,
    );

    // Titre et sens de lecture de l'axe horizontal.
    _texte(
      canvas,
      'Pertes / gains (Md FCFA)',
      Offset(zone.center.dx, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
      centreHorizontal: true,
    );
    _texte(
      canvas,
      '← gains',
      Offset(zone.left, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
    );
    _texte(
      canvas,
      'pertes sévères →',
      Offset(zone.right, zone.bottom + 24),
      couleur: _varMuted,
      taille: 10.5,
      alignementDroite: true,
    );
  }

  void _ligneVerticalePointillee(
    Canvas canvas,
    double x,
    double haut,
    double bas,
    Paint stylo,
  ) {
    const segment = 4.0;
    const espace = 4.0;
    var y = haut;
    while (y < bas) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(bas, y + segment)),
        stylo,
      );
      y += segment + espace;
    }
  }

  void _texte(
    Canvas canvas,
    String contenu,
    Offset position, {
    required Color couleur,
    required double taille,
    bool alignementDroite = false,
    bool centreHorizontal = false,
    bool centreVertical = false,
  }) {
    final peintre = TextPainter(
      text: TextSpan(
        text: contenu,
        style: TextStyle(
          color: couleur,
          fontSize: taille,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var decalage = position;
    if (alignementDroite) {
      decalage = decalage.translate(-peintre.width, 0);
    } else if (centreHorizontal) {
      decalage = decalage.translate(-peintre.width / 2, 0);
    }
    if (centreVertical) {
      decalage = decalage.translate(0, -peintre.height / 2);
    }
    peintre.paint(canvas, decalage);
  }

  void _etiquette(
    Canvas canvas,
    String contenu,
    Offset position, {
    required Color couleurTexte,
    required Color couleurBord,
  }) {
    final peintre = TextPainter(
      text: TextSpan(
        text: contenu,
        style: TextStyle(
          color: couleurTexte,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
      position.dx,
      position.dy,
      peintre.width + 14,
      peintre.height + 8,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = couleurBord
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    peintre.paint(canvas, position.translate(7, 4));
  }

  @override
  bool shouldRepaint(covariant _HistogrammeVarPainter ancien) {
    return ancien.reponse != reponse ||
        ancien.methode != methode ||
        ancien.confiance != confiance;
  }
}

// ---------------------------------------------------------------------------
// Carte de base
// ---------------------------------------------------------------------------

class _CarteVar extends StatelessWidget {
  const _CarteVar({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _varSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _varBorder),
      ),
      child: child,
    );
  }
}
