import 'package:flutter/material.dart';

/// Represents a recurring routine in the system.
class Routine {
  final int? id;
  final String name;
  final String dosage;
  final int typeIcon; // 1=Water, 2=Read, 3=Walk, 4=Care, 5=Sleep, 6=Home, 7=Move, 8=Calm
  final int color; // Color value for visual identification
  static const Map<int, String> _typeIconAssets = {
    1: 'assets/icons/routine/3d/tablet.png',
    2: 'assets/icons/routine/3d/liquid.png',
    3: 'assets/icons/routine/3d/injection.png',
    4: 'assets/icons/routine/3d/drop.png',
  };

  Routine({
    this.id,
    required this.name,
    this.dosage = '',
    this.typeIcon = 1,
    this.color = 0xFF2196F3, // Default blue
  });

  /// Get icon data based on type
  IconData get icon {
    switch (typeIcon) {
      case 1:
        return Icons.water_drop_rounded;
      case 2:
        return Icons.menu_book_rounded;
      case 3:
        return Icons.directions_walk_rounded;
      case 4:
        return Icons.spa_rounded;
      case 5:
        return Icons.bedtime_rounded;
      case 6:
        return Icons.home_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  /// Get the asset path for the routine icon
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
      'color': color,
    };
  }

  /// Create from database map
  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'] as int?,
      name: map['name'] as String,
      dosage: map['dosage'] as String? ?? '',
      typeIcon: map['type_icon'] as int? ?? 1,
      color: map['color'] as int? ?? 0xFF2196F3,
    );
  }

  /// Create a copy with modified fields
  Routine copyWith({
    int? id,
    String? name,
    String? dosage,
    int? typeIcon,
    int? color,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      typeIcon: typeIcon ?? this.typeIcon,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'Routine(id: $id, name: $name, dosage: $dosage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Routine && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
