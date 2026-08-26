// Modèles du module FODEP (Formulaire de Déclaration Prudentielle BCEAO).

class CodeDispru {
  const CodeDispru({
    required this.code,
    required this.ep,
    required this.groupe,
    required this.label,
    required this.sign,
    required this.paragraphes,
  });

  final String code;
  final String ep;
  final String groupe;
  final String label;
  final String sign;
  final List<String> paragraphes;

  bool get estDeduction => sign == 'deduction';

  factory CodeDispru.fromJson(Map<String, dynamic> json) {
    return CodeDispru(
      code: json['code'] as String,
      ep: json['ep'] as String,
      groupe: json['groupe'] as String,
      label: json['label'] as String,
      sign: json['sign'] as String,
      paragraphes: (json['paragraphes'] as List).cast<String>(),
    );
  }
}

class AprDetail {
  const AprDetail({
    required this.rwaCredit,
    required this.rwaMarche,
    required this.rwaOperationnel,
    required this.aprTotal,
  });

  final double rwaCredit;
  final double rwaMarche;
  final double rwaOperationnel;
  final double aprTotal;

  factory AprDetail.fromJson(Map<String, dynamic> json) {
    return AprDetail(
      rwaCredit: (json['rwa_credit'] as num).toDouble(),
      rwaMarche: (json['rwa_marche'] as num).toDouble(),
      rwaOperationnel: (json['rwa_operationnel'] as num).toDouble(),
      aprTotal: (json['apr_total'] as num).toDouble(),
    );
  }
}

class RatioDetail {
  const RatioDetail({
    required this.value,
    required this.threshold,
    required this.diffPoints,
    required this.status,
  });

  final double value;
  final double threshold;
  final double diffPoints;
  final String status;

  bool get conforme => status != 'Déficit';

  factory RatioDetail.fromJson(Map<String, dynamic> json) {
    return RatioDetail(
      value: (json['value'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      diffPoints: (json['diff_points'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}

class FodepApercu {
  const FodepApercu({
    required this.periode,
    required this.postes,
    required this.totaux,
    required this.apr,
    required this.ratios,
    required this.sourcePrefill,
  });

  final String? periode;
  final Map<String, double> postes;
  final Map<String, double> totaux;
  final AprDetail apr;
  final Map<String, RatioDetail> ratios;
  final bool sourcePrefill;

  factory FodepApercu.fromJson(Map<String, dynamic> json) {
    return FodepApercu(
      periode: json['periode'] as String?,
      postes: (json['postes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      totaux: (json['totaux'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      apr: AprDetail.fromJson(json['apr'] as Map<String, dynamic>),
      ratios: (json['ratios'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, RatioDetail.fromJson(value as Map<String, dynamic>)),
      ),
      sourcePrefill: json['source_prefill'] as bool,
    );
  }
}

class ParticipationEntry {
  const ParticipationEntry({
    this.id,
    required this.denominationEmettrice,
    required this.capitalEmettrice,
    required this.montantNet,
  });

  final String? id;
  final String denominationEmettrice;
  final double capitalEmettrice;
  final double montantNet;

  factory ParticipationEntry.fromJson(Map<String, dynamic> json) {
    return ParticipationEntry(
      id: json['id'] as String?,
      denominationEmettrice: json['denomination_emettrice'] as String? ?? '',
      capitalEmettrice: (json['capital_emettrice'] as num).toDouble(),
      montantNet: (json['montant_net'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'denomination_emettrice': denominationEmettrice,
        'capital_emettrice': capitalEmettrice,
        'montant_net': montantNet,
      };

  ParticipationEntry copyWith({
    String? denominationEmettrice,
    double? capitalEmettrice,
    double? montantNet,
  }) {
    return ParticipationEntry(
      id: id,
      denominationEmettrice: denominationEmettrice ?? this.denominationEmettrice,
      capitalEmettrice: capitalEmettrice ?? this.capitalEmettrice,
      montantNet: montantNet ?? this.montantNet,
    );
  }
}

class EtablissementView {
  const EtablissementView({required this.denomination, required this.codeBceao});

  final String denomination;
  final String codeBceao;

  factory EtablissementView.fromJson(Map<String, dynamic> json) {
    return EtablissementView(
      denomination: json['denomination'] as String? ?? '',
      codeBceao: json['code_bceao'] as String? ?? '',
    );
  }
}

class ImportFodepResult {
  const ImportFodepResult({
    required this.id,
    required this.nomFichier,
    this.periode,
    required this.postesDetectes,
    required this.ecarts,
  });

  final String id;
  final String nomFichier;
  final String? periode;
  final Map<String, double> postesDetectes;
  final Map<String, Map<String, double>> ecarts;

  factory ImportFodepResult.fromJson(Map<String, dynamic> json) {
    return ImportFodepResult(
      id: json['id'] as String,
      nomFichier: json['nom_fichier'] as String,
      periode: json['periode'] as String?,
      postesDetectes: (json['postes_detectes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      ecarts: (json['ecarts'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ),
        ),
      ),
    );
  }
}
