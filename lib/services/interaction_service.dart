import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/medicine.dart';

class InteractionResult {
  final List<String> drugs;
  final String severity;
  final String warning;

  InteractionResult({
    required this.drugs,
    required this.severity,
    required this.warning,
  });

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
}

class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  InteractionService._internal();
  factory InteractionService() => _instance;

  List<dynamic> _interactionData = [];
  bool _isLoaded = false;

  /// Load interaction data from JSON asset
  Future<void> loadData() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/data/drug_interactions.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      _interactionData = data['interactions'] ?? [];
      _isLoaded = true;
    } catch (e) {
      print('Error loading interaction data: $e');
    }
  }

  /// Check for interactions between a new medicine and existing list
  /// Returns a list of all detected interactions
  List<InteractionResult> checkInteractions(String newMedName, List<Medicine> cabinetMeds) {
    if (!_isLoaded || newMedName.isEmpty) return [];

    final results = <InteractionResult>[];
    final normalizedNewName = newMedName.toLowerCase().trim();

    for (final existingMed in cabinetMeds) {
      final normalizedExistingName = existingMed.name.toLowerCase().trim();
      
      // Skip if comparing to itself
      if (normalizedNewName == normalizedExistingName) continue;

      for (final interaction in _interactionData) {
        final drugs = List<String>.from(interaction['drugs'] ?? []);
        if (drugs.length < 2) continue;

        // Check if both drugs are present in this interaction pair
        final drug1 = drugs[0].toLowerCase();
        final drug2 = drugs[1].toLowerCase();

        bool match = false;
        // Check Pair: (New == A && Existing == B) OR (New == B && Existing == A)
        if (normalizedNewName.contains(drug1) && normalizedExistingName.contains(drug2)) match = true;
        if (normalizedNewName.contains(drug2) && normalizedExistingName.contains(drug1)) match = true;

        if (match) {
          results.add(InteractionResult(
            drugs: drugs,
            severity: interaction['severity'] ?? 'UNKNOWN',
            warning: interaction['warning'] ?? 'Potential interaction detected.',
          ));
        }
      }
    }
    return results;
  }
}
