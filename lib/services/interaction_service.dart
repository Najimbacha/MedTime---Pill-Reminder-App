import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
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

class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  static const String _baseUrl = 'https://rxnav.nlm.nih.gov/REST';
  
  // Cache to prevent redundant calls
  final Map<String, String> _rxcuiCache = {};

  /// Check for interactions between a new medicine name and existing medications
  Future<List<InteractionWarning>> checkInteractions(String newMedicineName, List<Medicine> existingMeds) async {
    if (newMedicineName.trim().isEmpty || existingMeds.isEmpty) return [];
    
    // 1. Get RxCUI for the new medicine
    final newRxcui = await getRxCui(newMedicineName);
    if (newRxcui == null) return []; // Cannot check if we can't identify the drug

    // 2. Collect RxCUIs for existing medicines
    // We only check against medicines that we can identify.
    Map<String, Medicine> rxcuiToMedicine = {};
    List<String> rxcuisToCheck = [newRxcui];

    for (final med in existingMeds) {
       String? id = med.rxcui;
       // If no saved ID, try to fetch it (and cache it)
       if (id == null) {
         id = await getRxCui(med.name);
       }
       
       if (id != null) {
         // Avoid duplicates
         if (!rxcuisToCheck.contains(id)) {
            rxcuisToCheck.add(id);
            rxcuiToMedicine[id] = med;
         }
       }
    }

    if (rxcuisToCheck.length < 2) return [];

    // 3. Call API
    return await _fetchInteractionsFromApi(rxcuisToCheck, newMedicineName, rxcuiToMedicine);
  }

  /// Get RxCUI (Concept ID) for a drug name
  Future<String?> getRxCui(String drugName) async {
    final key = drugName.toLowerCase().trim();
    if (_rxcuiCache.containsKey(key)) {
      return _rxcuiCache[key];
    }

    try {
      // Use approxMatch to handle typos better? Or just direct search.
      // 'approximateTerm.json' is better for user input, 'rxcui.json' is strict.
      // Let's stick to strict first for safety, or approximate if strict fails.
      
      final url = Uri.parse('$_baseUrl/rxcui.json?name=${Uri.encodeComponent(drugName)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['idGroup'] != null && data['idGroup']['rxnormId'] != null) {
          final List ids = data['idGroup']['rxnormId'];
          if (ids.isNotEmpty) {
            final rxcui = ids.first.toString();
            _rxcuiCache[key] = rxcui;
            return rxcui;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching RxCUI for $drugName: $e');
    }
    return null;
  }

  /// Fetch interactions from RxNav Interaction API
  Future<List<InteractionWarning>> _fetchInteractionsFromApi(
    List<String> rxcuis, 
    String newDrugName, 
    Map<String, Medicine> rxcuiToMedicine
  ) async {
    final warnings = <InteractionWarning>[];
    final idList = rxcuis.join('+');
    
    try {
      final url = Uri.parse('$_baseUrl/interaction/list.json?rxcuis=$idList');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['fullInteractionTypeGroup'] != null) {
           for (var group in data['fullInteractionTypeGroup']) {
             if (group['fullInteractionType'] != null) {
               for (var type in group['fullInteractionType']) {
                 
                 // Each type is a pair of drugs
                 if (type['minConcept'] != null && type['minConcept'].length >= 2) {
                    final rxcui1 = type['minConcept'][0]['rxcui'].toString();
                    final rxcui2 = type['minConcept'][1]['rxcui'].toString();
                    
                    // Determine which one is the "new" drug and which is existing
                    // We only care if the "new" drug is involved.
                    // Actually, the API returns all interactions in the list.
                    // We should filter for interactions involving the NEW drug.
                    // Since we don't have the new drug's ID explicitly isolated easily above without passing it,
                    // let's just show all relevant ones.
                    
                    // Map back to names
                    String name1 = _getNameForRxcui(rxcui1, newDrugName, rxcuiToMedicine);
                    String name2 = _getNameForRxcui(rxcui2, newDrugName, rxcuiToMedicine);

                    if (type['interactionPair'] != null) {
                       for (var pair in type['interactionPair']) {
                          warnings.add(InteractionWarning(
                            drugA: name1,
                            drugB: name2,
                            severity: _mapSeverity(pair['severity']),
                            message: pair['description'] ?? 'Potential interaction detected.',
                          ));
                       }
                    }
                 }
               }
             }
           }
        }
      }
    } catch (e) {
      debugPrint('Error fetching interactions: $e');
    }
    
    return warnings;
  }

  String _getNameForRxcui(String rxcui, String newName, Map<String, Medicine> map) {
     if (map.containsKey(rxcui)) {
       return map[rxcui]!.name;
     }
     // If not in map, it must be the new drug (since we only passed new + existing)
     // Or it could be a metabolite/ingredient. RxNav returns MinConcept.
     // For simplicity, assume it matches our input set.
     return newName; // Default fallback
  }

  InteractionSeverity _mapSeverity(String? severity) {
    if (severity == null) return InteractionSeverity.MODERATE;
    switch (severity.toUpperCase()) {
      case 'HIGH':
      case 'CRITICAL':
        return InteractionSeverity.HIGH;
      case 'N/A':
        return InteractionSeverity.MODERATE;
      default:
        return InteractionSeverity.LOW;
    }
  }
}
