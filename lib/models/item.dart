import 'package:hive/hive.dart';

part 'item.g.dart';

@HiveType(typeId: 0)
class Item extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imageUrl;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final List<int>? colors;

  @HiveField(5)
  final String category;

  @HiveField(6)
  int wearCount; // ✅ Stores the number of times worn

  @HiveField(7)
  bool inLaundry; // ✅ Indicates if the item is in laundry

  Item({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.description,
    this.colors,
    required this.category,
    this.wearCount = 0,
    this.inLaundry = false,
  });

  // ✅ Dynamically determine wear status based on conditions
  String get wearStatus {
    if (inLaundry) return 'In Laundry';
    if (wearCount > 0) return 'Clean';
    return 'Not Worn';
  }

  // ✅ Methods to update wear status dynamically
  void markAsWorn() {
    wearCount += 1;
    save();
  }

  void moveToLaundry() {
    inLaundry = true;
    save();
  }

  void markAsClean() {
    inLaundry = false;
    save();
  }

  // ✅ Add this `copyWith` method
  Item copyWith({
    String? id,
    String? imageUrl,
    String? name,
    String? description,
    List<int>? colors,
    String? category,
    int? wearCount,
    bool? inLaundry,
  }) {
    return Item(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      description: description ?? this.description,
      colors: colors ?? this.colors,
      category: category ?? this.category,
      wearCount: wearCount ?? this.wearCount,
      inLaundry: inLaundry ?? this.inLaundry,
    );
  }
}