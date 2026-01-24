import 'package:flutter/material.dart';

/// Represents a medicine/medication in the system
class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final int typeIcon; // 1=Pill, 2=Syrup, 3=Injection, 4=Drops
  final int currentStock;
  final int lowStockThreshold;
  final int color; // Color value for visual identification
  final String? imagePath;
  final String? pharmacyName;
  final String? pharmacyPhone;
  static const Map<int, String> _typeIconAssets = {
    1: 'assets/icons/medicine/pill_capsule.png',
    2: 'assets/icons/medicine/bottle.png',
    3: 'assets/icons/medicine/injection.png',
    4: 'assets/icons/medicine/syrup.png',
  };

  Medicine({
    this.id,
    required this.name,
    this.dosage = '',
    this.typeIcon = 1,
    this.currentStock = 0,
    this.lowStockThreshold = 5,
    this.color = 0xFF2196F3, // Default blue
    this.imagePath,
    this.pharmacyName,
    this.pharmacyPhone,
  });

  /// Check if stock is low
  bool get isLowStock => currentStock <= lowStockThreshold;

  /// Calculate days remaining based on daily dosage
  int getDaysRemaining(int dailyDoses) {
    if (dailyDoses <= 0) return 365; // Far future if not taken daily
    return (currentStock / dailyDoses).floor();
  }

  /// Get estimated refill date
  DateTime getEstimatedRefillDate(int dailyDoses) {
    final days = getDaysRemaining(dailyDoses);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: days));
  }

  /// Get icon data based on type
  IconData get icon {
    switch (typeIcon) {
      case 1:
        return Icons.medication; // Pill
      case 2:
        return Icons.local_drink; // Syrup
      case 3:
        return Icons.vaccines; // Injection
      case 4:
        return Icons.water_drop; // Drops
      default:
        return Icons.medication;
    }
  }

  /// Get the asset path for the medicine icon
  String get iconAssetPath => _typeIconAssets[typeIcon] ?? _typeIconAssets[1]!;

  /// Get color object
  Color get colorValue => Color(color);

  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'type_icon': typeIcon,
      'current_stock': currentStock,
      'low_stock_threshold': lowStockThreshold,
      'color': color,
      'image_path': imagePath,
      'pharmacy_name': pharmacyName,
      'pharmacy_phone': pharmacyPhone,
    };
  }

  /// Create from database map
  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'] as int?,
      name: map['name'] as String,
      dosage: map['dosage'] as String? ?? '',
      typeIcon: map['type_icon'] as int? ?? 1,
      currentStock: map['current_stock'] as int? ?? 0,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      color: map['color'] as int? ?? 0xFF2196F3,
      imagePath: map['image_path'] as String?,
      pharmacyName: map['pharmacy_name'] as String?,
      pharmacyPhone: map['pharmacy_phone'] as String?,
    );
  }

  /// Create a copy with modified fields
  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    int? typeIcon,
    int? currentStock,
    int? lowStockThreshold,
    int? color,
    String? imagePath,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      typeIcon: typeIcon ?? this.typeIcon,
      currentStock: currentStock ?? this.currentStock,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      color: color ?? this.color,
      imagePath: imagePath ?? this.imagePath,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacyPhone: pharmacyPhone ?? this.pharmacyPhone,
    );
  }

  @override
  String toString() {
    return 'Medicine(id: $id, name: $name, dosage: $dosage, stock: $currentStock)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Medicine && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
