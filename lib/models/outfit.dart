// lib/models/outfit.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'outfit.g.dart'; // This will be auto-generated

@HiveType(typeId: 2) // Choose a unique type ID
class Outfit {
  @HiveField(0)
  String name;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  final Map<String, String?> clothes;

  @HiveField(3)
  final List<String?> accessories;

  @HiveField(4)
  List<int> colorCodes; // We'll store colors as ints

  @HiveField(5)
  String? id;

  @HiveField(6)  // Ensure this is annotated
  List<String> colorPaletteStrings = []; // Initialized with empty list

  // Getter that converts colorCodes back to Color objects
  List<Color> get colorPalette => colorCodes.map((code) => Color(code)).toList();


  Outfit({
    required this.name,
    required this.clothes,
    required List<dynamic> accessories,
    required this.date,
    List<Color>? colorPalette, // Make colorPalette optional
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
  }


  // Factory constructor
  factory Outfit.fromMap(Map<String, dynamic> map) {
    return Outfit(
      name: map['name'] as String,
      clothes: Map<String, String?>.from(map['clothes']),
      accessories: List<String?>.from(map['accessories']),
      colorPalette: (map['colorCodes'] as List).map((code) => Color(code as int)).toList(),
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date'] as String),
    );
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
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
}