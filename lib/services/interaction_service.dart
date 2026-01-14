import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/medicine.dart';

/// Severity levels for drug interactions
enum InteractionSeverity {
  CRITICAL,
  HIGH,
  MODERATE,
  LOW
}

/// Represents a detected drug interaction warning
class InteractionWarning {
  final String drugA;
  final String drugB;
  final InteractionSeverity severity;
  final String message;

  InteractionWarning({
    required this.drugA,
    required this.drugB,
    required this.severity,
    required this.message,
  });
}

/// Service to handle drug interaction logic
class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  List<Map<String, dynamic>> _interactions = [];
  bool _isLoaded = false;

  /// Load interactions from assets
  Future<void> loadInteractions() async {
    if (_isLoaded) return;
    try {
      final String response = await rootBundle.loadString('assets/data/drug_interactions.json');
      final data = await json.decode(response);
      _interactions = List<Map<String, dynamic>>.from(data['interactions']);
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading interactions: $e');
    }
  }

  /// Check for interactions between a new medicine name and existing medications
  Future<List<InteractionWarning>> checkInteractions(String medicineName, List<Medicine> existingMeds) async {
    if (!_isLoaded) await loadInteractions();
    
    List<InteractionWarning> warnings = [];
    final String targetName = medicineName.trim().toLowerCase();

    for (var interaction in _interactions) {
      final List<String> drugsInInteraction = List<String>.from(interaction['drugs']);
      
      // Check if medicineName matches any drug in this interaction rule
      int matchIndex = -1;
      for (int i = 0; i < drugsInInteraction.length; i++) {
        if (drugsInInteraction[i].toLowerCase() == targetName) {
          matchIndex = i;
          break;
        }
      }

      if (matchIndex != -1) {
        // Now check if any of the OTHER drugs in this rule are in existingMeds
        for (int i = 0; i < drugsInInteraction.length; i++) {
          if (i == matchIndex) continue;
          
          final String otherDrug = drugsInInteraction[i];
          final bool exists = existingMeds.any((m) => m.name.toLowerCase() == otherDrug.toLowerCase());
          
          if (exists) {
            warnings.add(InteractionWarning(
              drugA: medicineName,
              drugB: otherDrug,
              severity: _parseSeverity(interaction['severity']),
              message: interaction['warning'],
            ));
          }
        }
      }
    }

    return warnings;
  }

  InteractionSeverity _parseSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return InteractionSeverity.CRITICAL;
      case 'HIGH': return InteractionSeverity.HIGH;
      case 'MODERATE': return InteractionSeverity.MODERATE;
      case 'LOW': return InteractionSeverity.LOW;
      default: return InteractionSeverity.LOW;
    }
  }
}
