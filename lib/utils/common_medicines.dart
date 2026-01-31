import 'package:flutter/material.dart';

class MedicineDefaults {
  final String name;
  final int typeIcon; // 1: pill, 2: bottle, 3: needle, 4: syrup
  final int color;

  const MedicineDefaults({
    required this.name,
    required this.typeIcon,
    required this.color,
  });
}

class CommonMedicines {
  static const List<MedicineDefaults> defaults = [
    // Pain Relief
    MedicineDefaults(name: 'Paracetamol', typeIcon: 1, color: 0xFF2196F3),
    MedicineDefaults(name: 'Panadol', typeIcon: 1, color: 0xFF2196F3),
    MedicineDefaults(name: 'Ibuprofen', typeIcon: 1, color: 0xFFEF5350),
    MedicineDefaults(name: 'Advil', typeIcon: 1, color: 0xFFEF5350),
    MedicineDefaults(
      name: 'Aspirin',
      typeIcon: 1,
      color: 0xFF78909C,
    ), // Blue Grey
    MedicineDefaults(name: 'Tylenol', typeIcon: 1, color: 0xFFEF5350),
    MedicineDefaults(name: 'Naproxen', typeIcon: 1, color: 0xFF42A5F5),

    // Antibiotics
    MedicineDefaults(name: 'Amoxicillin', typeIcon: 1, color: 0xFFFFCA28),
    MedicineDefaults(name: 'Augmentin', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Azithromycin', typeIcon: 1, color: 0xFFAB47BC),
    MedicineDefaults(name: 'Ciprofloxacin', typeIcon: 1, color: 0xFF78909C),

    // Chronic
    MedicineDefaults(name: 'Metformin', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Lipitor', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Omeprazole', typeIcon: 1, color: 0xFFAB47BC),
    MedicineDefaults(name: 'Amlodipine', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Lisinopril', typeIcon: 1, color: 0xFFFFCA28),
    MedicineDefaults(name: 'Levothyroxine', typeIcon: 1, color: 0xFFAB47BC),

    // Vitamins
    MedicineDefaults(name: 'Vitamin D', typeIcon: 1, color: 0xFFFFCA28),
    MedicineDefaults(name: 'Vitamin C', typeIcon: 1, color: 0xFFFFA726),
    MedicineDefaults(name: 'Multivitamin', typeIcon: 1, color: 0xFF66BB6A),
    MedicineDefaults(name: 'Iron', typeIcon: 1, color: 0xFF8D6E63),
    MedicineDefaults(name: 'Magnesium', typeIcon: 1, color: 0xFF78909C),

    // Allergies
    MedicineDefaults(name: 'Zyrtec', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Claritin', typeIcon: 1, color: 0xFF78909C),
    MedicineDefaults(name: 'Benadryl', typeIcon: 1, color: 0xFFEC407A),
  ];

  static List<String> get names => defaults.map((m) => m.name).toList();

  static MedicineDefaults? find(String name) {
    try {
      return defaults.firstWhere(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
