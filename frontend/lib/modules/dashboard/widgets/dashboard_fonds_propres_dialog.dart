import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../dashboard/models/dashboard_models.dart';
import 'dashboard_design.dart';

/// Modal d'edition des fonds propres reglementaires.
class DashboardFondsPropresDialog extends StatefulWidget {
  const DashboardFondsPropresDialog({
    super.key,
    required this.api,
    required this.fondsPropres,
  });

  final RwaApiService api;
  final FondsPropresDetail? fondsPropres;

  /// Ouvre la modale et retourne `true` si une sauvegarde a ete effectuee.
  static Future<bool> show(
    BuildContext context,
    RwaApiService api,
    FondsPropresDetail? fondsPropres,
  ) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: DashboardFondsPropresDialog(api: api, fondsPropres: fondsPropres),
          ),
        );
      },
    );
    return result == true;
  }

  @override
  State<DashboardFondsPropresDialog> createState() => _DashboardFondsPropresDialogState();
}

class _DashboardFondsPropresDialogState extends State<DashboardFondsPropresDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _capOrdinaireCtrl;
  late TextEditingController _reservesCtrl;
  late TextEditingController _reportCtrl;
  late TextEditingController _eligibleCtrl;
  late TextEditingController _deducCet1Ctrl;

  late TextEditingController _instAt1Ctrl;
  late TextEditingController _primesAt1Ctrl;
  late TextEditingController _deducAt1Ctrl;

  late TextEditingController _subordT2Ctrl;
  late TextEditingController _provGenT2Ctrl;
  late TextEditingController _deducT2Ctrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final fp = widget.fondsPropres;
    _capOrdinaireCtrl = _ctrl(fp?.capitalOrdinaire);
    _reservesCtrl = _ctrl(fp?.reserves);
    _reportCtrl = _ctrl(fp?.resultatsReport);
    _eligibleCtrl = _ctrl(fp?.resultatEligible);
    _deducCet1Ctrl = _ctrl(fp?.deductionsPrudCet1);

    _instAt1Ctrl = _ctrl(fp?.instrumentsAt1);
    _primesAt1Ctrl = _ctrl(fp?.primesEmissionAt1);
    _deducAt1Ctrl = _ctrl(fp?.deductionsPrudAt1);

    _subordT2Ctrl = _ctrl(fp?.dettesSubordonneesT2);
    _provGenT2Ctrl = _ctrl(fp?.provisionsGeneralesT2);
    _deducT2Ctrl = _ctrl(fp?.deductionsPrudT2);
  }

  TextEditingController _ctrl(double? val) {
    if (val == null || val == 0.0) return TextEditingController(text: '');
    // Enlever ".0" si c'est un entier
    String text = val.toStringAsFixed(0);
    if (val != val.truncateToDouble()) {
      text = val.toString();
    }
    return TextEditingController(text: text);
  }

  @override
  void dispose() {
    _capOrdinaireCtrl.dispose();
    _reservesCtrl.dispose();
    _reportCtrl.dispose();
    _eligibleCtrl.dispose();
    _deducCet1Ctrl.dispose();

    _instAt1Ctrl.dispose();
    _primesAt1Ctrl.dispose();
    _deducAt1Ctrl.dispose();

    _subordT2Ctrl.dispose();
    _provGenT2Ctrl.dispose();
    _deducT2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final update = FondsPropresUpdate(
        capitalOrdinaire: double.tryParse(_capOrdinaireCtrl.text) ?? 0.0,
        reserves: double.tryParse(_reservesCtrl.text) ?? 0.0,
        resultatsReport: double.tryParse(_reportCtrl.text) ?? 0.0,
        resultatEligible: double.tryParse(_eligibleCtrl.text) ?? 0.0,
        deductionsPrudCet1: double.tryParse(_deducCet1Ctrl.text) ?? 0.0,
        instrumentsAt1: double.tryParse(_instAt1Ctrl.text) ?? 0.0,
        primesEmissionAt1: double.tryParse(_primesAt1Ctrl.text) ?? 0.0,
        deductionsPrudAt1: double.tryParse(_deducAt1Ctrl.text) ?? 0.0,
        dettesSubordonneesT2: double.tryParse(_subordT2Ctrl.text) ?? 0.0,
        provisionsGeneralesT2: double.tryParse(_provGenT2Ctrl.text) ?? 0.0,
        deductionsPrudT2: double.tryParse(_deducT2Ctrl.text) ?? 0.0,
      );

      await widget.api.updateFondsPropres(update);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DashColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 700,
      constraints: const BoxConstraints(maxHeight: 800),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Modifier les Fonds Propres',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
                color: c.muted,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'CET1 (Catégorie 1)',
                        const Color(0xFF1E40AF),
                        [
                          _buildField('Capital ordinaire', _capOrdinaireCtrl, isDark),
                          _buildField('Réserves', _reservesCtrl, isDark),
                          _buildField('Résultats en report', _reportCtrl, isDark),
                          _buildField('Résultat éligible', _eligibleCtrl, isDark),
                          _buildField('Déductions prudentielles', _deducCet1Ctrl, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'AT1 (Additionnel Catégorie 1)',
                        const Color(0xFF1E3A8A),
                        [
                          _buildField('Instruments additionnels', _instAt1Ctrl, isDark),
                          _buildField('Primes d\'émission', _primesAt1Ctrl, isDark),
                          _buildField('Déductions prudentielles', _deducAt1Ctrl, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildColumn(
                        c,
                        isDark,
                        'Tier 2 (Complémentaire)',
                        const Color(0xFF475569),
                        [
                          _buildField('Dettes subordonnées', _subordT2Ctrl, isDark),
                          _buildField('Provisions générales', _provGenT2Ctrl, isDark),
                          _buildField('Déductions prudentielles', _deducT2Ctrl, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: c.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sidebar,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(
      DashColors c, bool isDark, String title, Color borderC, List<Widget> fields) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border, width: Dash.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderC, width: 3)),
            ),
            child: Text(
              title,
              style: DashText.eyebrow(c).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Divider(height: 1, thickness: Dash.hairline, color: c.divider),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: fields,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
            ],
            style: const TextStyle(
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              hintText: '0',
              hintStyle: TextStyle(
                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: AppColors.sidebar, width: 1.5),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
