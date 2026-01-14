import 'dart:convert';

class Caregiver {
  final String name;
  final String phoneNumber;
  final bool notifyOnMissedDose;
  final bool notifyOnLowStock;

  Caregiver({
    required this.name,
    required this.phoneNumber,
    this.notifyOnMissedDose = true,
    this.notifyOnLowStock = true,
  });

  Caregiver copyWith({
    String? name,
    String? phoneNumber,
    bool? notifyOnMissedDose,
    bool? notifyOnLowStock,
  }) {
    return Caregiver(
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notifyOnMissedDose: notifyOnMissedDose ?? this.notifyOnMissedDose,
      notifyOnLowStock: notifyOnLowStock ?? this.notifyOnLowStock,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phoneNumber': phoneNumber,
      'notifyOnMissedDose': notifyOnMissedDose,
      'notifyOnLowStock': notifyOnLowStock,
    };
  }

  factory Caregiver.fromMap(Map<String, dynamic> map) {
    return Caregiver(
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      notifyOnMissedDose: map['notifyOnMissedDose'] ?? true,
      notifyOnLowStock: map['notifyOnLowStock'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory Caregiver.fromJson(String source) => Caregiver.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Caregiver(name: $name, phone: $phoneNumber, missed: $notifyOnMissedDose, stock: $notifyOnLowStock)';
  }
}
