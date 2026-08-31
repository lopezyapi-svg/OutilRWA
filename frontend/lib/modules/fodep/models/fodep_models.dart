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

class AttestationFodep {
  final String rensPrenomsNom;
  final String rensFonction;
  final String rensTelephone;
  final String rensPoste;
  final String rensEmail;

  final String transPrenomsNom;
  final String transFonction;
  final String transTelephone;
  final String transPoste;
  final String transEmail;

  final String certifNous1;
  final String certifNous2;

  final String sign1Code;
  final String sign1Fonction;
  final String sign1Date;
  final String sign1Image;

  final String sign2Code;
  final String sign2Fonction;
  final String sign2Date;
  final String sign2Image;

  AttestationFodep({
    required this.rensPrenomsNom,
    required this.rensFonction,
    required this.rensTelephone,
    required this.rensPoste,
    required this.rensEmail,
    required this.transPrenomsNom,
    required this.transFonction,
    required this.transTelephone,
    required this.transPoste,
    required this.transEmail,
    required this.certifNous1,
    required this.certifNous2,
    required this.sign1Code,
    required this.sign1Fonction,
    required this.sign1Date,
    required this.sign1Image,
    required this.sign2Code,
    required this.sign2Fonction,
    required this.sign2Date,
    required this.sign2Image,
  });

  factory AttestationFodep.fromJson(Map<String, dynamic> json) {
    return AttestationFodep(
      rensPrenomsNom: json['rens_prenoms_nom'] as String? ?? '',
      rensFonction: json['rens_fonction'] as String? ?? '',
      rensTelephone: json['rens_telephone'] as String? ?? '',
      rensPoste: json['rens_poste'] as String? ?? '',
      rensEmail: json['rens_email'] as String? ?? '',
      transPrenomsNom: json['trans_prenoms_nom'] as String? ?? '',
      transFonction: json['trans_fonction'] as String? ?? '',
      transTelephone: json['trans_telephone'] as String? ?? '',
      transPoste: json['trans_poste'] as String? ?? '',
      transEmail: json['trans_email'] as String? ?? '',
      certifNous1: json['certif_nous_1'] as String? ?? '',
      certifNous2: json['certif_nous_2'] as String? ?? '',
      sign1Code: json['sign1_code'] as String? ?? '',
      sign1Fonction: json['sign1_fonction'] as String? ?? '',
      sign1Date: json['sign1_date'] as String? ?? '',
      sign1Image: json['sign1_image'] as String? ?? '',
      sign2Code: json['sign2_code'] as String? ?? '',
      sign2Fonction: json['sign2_fonction'] as String? ?? '',
      sign2Date: json['sign2_date'] as String? ?? '',
      sign2Image: json['sign2_image'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rens_prenoms_nom': rensPrenomsNom,
      'rens_fonction': rensFonction,
      'rens_telephone': rensTelephone,
      'rens_poste': rensPoste,
      'rens_email': rensEmail,
      'trans_prenoms_nom': transPrenomsNom,
      'trans_fonction': transFonction,
      'trans_telephone': transTelephone,
      'trans_poste': transPoste,
      'trans_email': transEmail,
      'certif_nous_1': certifNous1,
      'certif_nous_2': certifNous2,
      'sign1_code': sign1Code,
      'sign1_fonction': sign1Fonction,
      'sign1_date': sign1Date,
      'sign1_image': sign1Image,
      'sign2_code': sign2Code,
      'sign2_fonction': sign2Fonction,
      'sign2_date': sign2Date,
      'sign2_image': sign2Image,
    };
  }

  static AttestationFodep empty() => AttestationFodep(
        rensPrenomsNom: '', rensFonction: '', rensTelephone: '', rensPoste: '', rensEmail: '',
        transPrenomsNom: '', transFonction: '', transTelephone: '', transPoste: '', transEmail: '',
        certifNous1: '', certifNous2: '',
        sign1Code: '', sign1Fonction: '', sign1Date: '', sign1Image: '',
        sign2Code: '', sign2Fonction: '', sign2Date: '', sign2Image: '',
      );

  AttestationFodep copyWith({
    String? rensPrenomsNom, String? rensFonction, String? rensTelephone, String? rensPoste, String? rensEmail,
    String? transPrenomsNom, String? transFonction, String? transTelephone, String? transPoste, String? transEmail,
    String? certifNous1, String? certifNous2,
    String? sign1Code, String? sign1Fonction, String? sign1Date, String? sign1Image,
    String? sign2Code, String? sign2Fonction, String? sign2Date, String? sign2Image,
  }) {
    return AttestationFodep(
      rensPrenomsNom: rensPrenomsNom ?? this.rensPrenomsNom,
      rensFonction: rensFonction ?? this.rensFonction,
      rensTelephone: rensTelephone ?? this.rensTelephone,
      rensPoste: rensPoste ?? this.rensPoste,
      rensEmail: rensEmail ?? this.rensEmail,
      transPrenomsNom: transPrenomsNom ?? this.transPrenomsNom,
      transFonction: transFonction ?? this.transFonction,
      transTelephone: transTelephone ?? this.transTelephone,
      transPoste: transPoste ?? this.transPoste,
      transEmail: transEmail ?? this.transEmail,
      certifNous1: certifNous1 ?? this.certifNous1,
      certifNous2: certifNous2 ?? this.certifNous2,
      sign1Code: sign1Code ?? this.sign1Code,
      sign1Fonction: sign1Fonction ?? this.sign1Fonction,
      sign1Date: sign1Date ?? this.sign1Date,
      sign1Image: sign1Image ?? this.sign1Image,
      sign2Code: sign2Code ?? this.sign2Code,
      sign2Fonction: sign2Fonction ?? this.sign2Fonction,
      sign2Date: sign2Date ?? this.sign2Date,
      sign2Image: sign2Image ?? this.sign2Image,
    );
  }

  /// Signature d'égalité par valeur (pour le suivi « modifications non
  /// enregistrées »).
  String get signatureValeur => toJson().entries
      .map((e) => '${e.key}=${e.value}')
      .join('|');

  /// L'attestation est-elle complète au sens réglementaire minimal :
  /// les deux responsables identifiés + au moins un signataire renseigné.
  bool get estComplete =>
      rensPrenomsNom.trim().isNotEmpty &&
      rensFonction.trim().isNotEmpty &&
      rensEmail.trim().isNotEmpty &&
      transPrenomsNom.trim().isNotEmpty &&
      transFonction.trim().isNotEmpty &&
      transEmail.trim().isNotEmpty &&
      certifNous1.trim().isNotEmpty &&
      sign1Code.trim().isNotEmpty &&
      sign1Fonction.trim().isNotEmpty &&
      sign1Date.trim().isNotEmpty;
}
