import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

part 'lookbookItem.g.dart';

@HiveType(typeId: 2)
class LookbookItem extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String name;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  String? imageUrl;

  @HiveField(4)
  List<String> tags;

  @HiveField(5)
  String? notes;

  @HiveField(6)
  String? source;

  @HiveField(7)
  List<int> colorCodes = [];

  // Non-persisted field, computed from colorCodes
  List<Color> get colorPalette => colorCodes.map((code) => Color(code)).toList();

  LookbookItem({
    this.id,
    required this.name,
    required this.createdAt,
    this.imageUrl,
    List<String>? tags,
    this.notes,
    this.source,
    List<Color>? colorPalette,
  }) :
        tags = tags ?? [],
        colorCodes = colorPalette?.map((color) => color.value).toList() ?? [];

  // Create a copy of this lookbook item with optional new values
  LookbookItem copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    String? imageUrl,
    List<String>? tags,
    String? notes,
    String? source,
    List<Color>? colorPalette,
  }) {
    return LookbookItem(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? List<String>.from(this.tags),
      notes: notes ?? this.notes,
      source: source ?? this.source,
      colorPalette: colorPalette ?? this.colorPalette,
    );
  }

  // Factory constructor
  factory LookbookItem.fromMap(Map<String, dynamic> map) {
    try {
      return LookbookItem(
        id: map['id'] as String?,
        name: map['name'] as String? ?? 'Unnamed Inspiration',
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt']
            : DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
        imageUrl: map['imageUrl'] as String?,
        tags: (map['tags'] as List<dynamic>?)?.cast<String>().toList() ?? [],
        notes: map['notes'] as String?,
        source: map['source'] as String?,
        colorPalette: (map['colorCodes'] as List?)?.map((code) => Color(code as int)).toList(),
      );
    } catch (e) {
      debugPrint('Error creating LookbookItem from map: $e');
      // Return a fallback lookbook item
      return LookbookItem(
        name: 'Recovery Inspiration',
        createdAt: DateTime.now(),
      );
    }
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'tags': tags,
      'notes': notes,
      'source': source,
      'colorCodes': colorCodes,
    };
  }

  @override
  String toString() {
    return 'LookbookItem(id: $id, name: $name, tags: $tags)';
  }
}
