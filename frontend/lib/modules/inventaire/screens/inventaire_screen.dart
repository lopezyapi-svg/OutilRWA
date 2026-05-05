// Ce fichier laisse volontairement la section Expositions vide.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';

/// Ecran vide conserve pour la section Expositions.
class InventaireScreen extends StatefulWidget {
  const InventaireScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<InventaireScreen> createState() => _InventaireScreenState();
}

/// Etat minimal conserve pour rester compatible avec le hot reload.
class _InventaireScreenState extends State<InventaireScreen> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
