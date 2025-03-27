import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'outfit.g.dart';

@HiveType(typeId: 1)
class Outfit extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final Map<String, String?> clothes;

  @HiveField(4)
  final List<String?> accessories;

  @HiveField(5)
  List<int> colorCodes;

  @HiveField(6)
  List<String> colorPaletteStrings = [];

  // Non-persisted field, computed from colorCodes
  List<Color> get colorPalette => colorCodes.map((code) => Color(code)).toList();

  Outfit({
    this.id,
    required this.name,
    required this.clothes,
    required List<dynamic> accessories,
    required this.date,
    List<Color>? colorPalette,
    List<String>? colorPaletteStrings,
  }) :
        accessories = accessories
            .where((item) => item != null)
            .map((item) => item as String)
            .toList(),
        colorCodes = colorPalette?.map((color) => color.value).toList() ?? [] {
    // Initialize colorPaletteStrings in the constructor body if provided
    if (colorPaletteStrings != null) {
      this.colorPaletteStrings = colorPaletteStrings;
    }

    // Ensure we have a valid name
    if (name.isEmpty) {
      name = 'Outfit ${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Create a copy of this outfit with optional new values
  Outfit copyWith({
    String? id,
    String? name,
    DateTime? date,
    Map<String, String?>? clothes,
    List<String?>? accessories,
    List<Color>? colorPalette,
    List<String>? colorPaletteStrings,
  }) {
    return Outfit(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      clothes: clothes ?? Map<String, String?>.from(this.clothes),
      accessories: accessories ?? List<String?>.from(this.accessories),
      colorPalette: colorPalette ?? this.colorPalette,
      colorPaletteStrings: colorPaletteStrings ?? List<String>.from(this.colorPaletteStrings),
    );
  }

  // Factory constructor
  factory Outfit.fromMap(Map<String, dynamic> map) {
    try {
      return Outfit(
        id: map['id'] as String?,
        name: map['name'] as String? ?? 'Unnamed Outfit',
        clothes: Map<String, String?>.from(map['clothes'] ?? {}),
        accessories: List<String?>.from(map['accessories'] ?? []),
        colorPalette: (map['colorCodes'] as List?)?.map((code) => Color(code as int)).toList(),
        date: map['date'] is DateTime
            ? map['date']
            : DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error creating Outfit from map: $e');
      // Return a fallback outfit
      return Outfit(
        name: 'Recovery Outfit',
        clothes: {},
        accessories: [],
        date: DateTime.now(),
      );
    }
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clothes': clothes,
      'accessories': accessories,
      'colorCodes': colorCodes,
      'date': date.toIso8601String(),
    };
  }

  bool isComplete() {
    return name.isNotEmpty && clothes.values.any((url) => url != null && url.isNotEmpty);
  }

  @override
  String toString() {
    return 'Outfit(id: $id, name: $name, date: $date)';
  }
}

