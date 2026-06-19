/// Repository pour la gestion des positions de change
/// Abstraction pour permettre stockage en BD, SharedPreferences, ou en mémoire

import 'dart:async';

import '../services/foreign_exchange_risk_service.dart';

/// Interface pour la persistance des positions de change
abstract class ForeignExchangeRepository {
  /// Récupère toutes les positions de change
  Future<List<ForeignExchangePosition>> getAllPositions();

  /// Ajoute ou met à jour une position pour une devise
  Future<void> savePosition(ForeignExchangePosition position);

  /// Supprime une position pour une devise
  Future<void> deletePosition(String currency);

  /// Efface toutes les positions
  Future<void> clearAll();

  /// Écoute les changements (stream pour UI reactive)
  Stream<List<ForeignExchangePosition>> get positionsStream;
}

/// Implémentation en mémoire (à remplacer par BD plus tard)
class InMemoryForeignExchangeRepository implements ForeignExchangeRepository {
  final Map<String, ForeignExchangePosition> _positions = {};
  final _positionsController = StreamController<List<ForeignExchangePosition>>.broadcast();

  static final InMemoryForeignExchangeRepository _instance =
      InMemoryForeignExchangeRepository._internal();

  factory InMemoryForeignExchangeRepository() {
    return _instance;
  }

  InMemoryForeignExchangeRepository._internal();

  @override
  Future<List<ForeignExchangePosition>> getAllPositions() async {
    return List.from(_positions.values);
  }

  @override
  Future<void> savePosition(ForeignExchangePosition position) async {
    _positions[position.currency] = position;
    _notifyListeners();
  }

  @override
  Future<void> deletePosition(String currency) async {
    _positions.remove(currency);
    _notifyListeners();
  }

  @override
  Future<void> clearAll() async {
    _positions.clear();
    _notifyListeners();
  }

  @override
  Stream<List<ForeignExchangePosition>> get positionsStream =>
      _positionsController.stream;

  void _notifyListeners() {
    _positionsController.add(List.from(_positions.values));
  }

  /// Ajoute des données de démonstration
  void loadDemoData() {
    final demoPositions = [
      ForeignExchangePosition(
        currency: 'USD',
        assets: 500000000,
        liabilities: 200000000,
        forwardPurchases: 50000000,
        forwardSales: 0,
      ),
      ForeignExchangePosition(
        currency: 'EUR',
        assets: 300000000,
        liabilities: 400000000,
        forwardPurchases: 0,
        forwardSales: 100000000,
      ),
      ForeignExchangePosition(
        currency: 'XOF',
        assets: 150000000,
        liabilities: 80000000,
        forwardPurchases: 0,
        forwardSales: 0,
      ),
    ];

    for (final pos in demoPositions) {
      _positions[pos.currency] = pos;
    }
    _notifyListeners();
  }

  void dispose() {
    _positionsController.close();
  }
}
