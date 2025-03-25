import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:drobe/Outfits/createOutfit.dart';
import 'outfits.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/Outfits/outfits.dart';
import 'package:drobe/models/item.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drobe/services/hiveServiceManager.dart';

class CreatePalettePage extends StatefulWidget {
  final DateTime selectedDate;

  const CreatePalettePage({super.key, required this.selectedDate});

  @override
  State<CreatePalettePage> createState() => _CreatePalettePageState();
}

class _CreatePalettePageState extends State<CreatePalettePage> {
  late DateTime selectedDate;
  int _paletteSize = 3;
  bool _isLoading = true;
  List<ColorTile> _wardrobeColors = []; // To store all wardrobe colors

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate;
    _checkItemsExistence();
    print('InitState: Loading wardrobe colors...');
    _loadWardrobeColors();
  }

  // Initial palette
  final List<ColorTile> _palette = [
    ColorTile(color: Colors.grey.shade200),
    ColorTile(color: Colors.teal.shade100),
    ColorTile(color: Colors.teal.shade200),
    ColorTile(color: Colors.teal.shade300),
  ];

  // Load all colors from the wardrobe items
  Future<void> _loadWardrobeColors() async {
    setState(() => _isLoading = true);

    try {
      // Get box reference without trying to re-open it
      Box itemsBox;

      if (Hive.isBoxOpen('itemsBox')) {
        print('Using existing open box');
        itemsBox = Hive.box('itemsBox');
      } else {
        print('Opening box freshly');
        itemsBox = await Hive.openBox('itemsBox');
      }

      print('Box type: ${itemsBox.runtimeType}');
      print('Box item count: ${itemsBox.length}');
      print('Box keys: ${itemsBox.keys.toList()}');

      // Debug the box contents more thoroughly
      if (itemsBox.isEmpty) {
        print('Box is empty. This might be the issue.');

        // Check if items need to be added to the box
        print('Have you added any items to your wardrobe yet?');
        print('If yes, make sure they are being saved to "itemsBox"');
      } else {
        // Try to understand what's in the box
        print('Box is not empty. Let\'s check what\'s inside:');
        itemsBox.keys.forEach((key) {
          final value = itemsBox.get(key);
          print('Key: $key, Value type: ${value.runtimeType}');
        });
      }

      // Get all items with proper type handling
      List<Item> items = [];

      for (var key in itemsBox.keys) {
        try {
          final item = itemsBox.get(key);
          if (item != null && item is Item) {
            items.add(item);
            print('Added item: ${item.name}, Has colors: ${item.colors != null}');
            if (item.colors != null) {
              print('Colors: ${item.colors}');
            }
          } else if (item != null) {
            print('Found non-Item at key $key: ${item.runtimeType}');
            // Try to convert if it's a Map
            if (item is Map) {
              try {
                // Attempt to create Item from Map
                final convertedItem = Item(
                  id: item['id'] as String? ?? 'unknown',
                  imageUrl: item['imageUrl'] as String? ?? '',
                  name: item['name'] as String? ?? 'Unknown Item',
                  description: item['description'] as String? ?? '',
                  colors: item['colors'] is List ? List<int>.from(item['colors']) : null,
                  category: item['category'] as String? ?? 'uncategorized',
                  wearCount: item['wearCount'] as int? ?? 0,
                  inLaundry: item['inLaundry'] as bool? ?? false,
                );
                items.add(convertedItem);
                print('Successfully converted map to Item: ${convertedItem.name}');
              } catch (e) {
                print('Failed to convert map to Item: $e');
              }
            }
          }
        } catch (e) {
          print('Error getting item with key $key: $e');
        }
      }

      print('Processed ${items.length} items from box');

      // If we still have no items, it might be that:
      // 1. No items have been added
      // 2. Items are in a different box
      // 3. The adapter is not correctly handling the data

      if (items.isEmpty) {
        // Check if any other box might contain our items
        final boxNames = ['items', 'wardrobe', 'wardrobeItems', 'item'];
        for (final name in boxNames) {
          if (name != 'itemsBox' && Hive.isBoxOpen(name)) {
            print('Checking box "$name"');
            final altBox = Hive.box(name);
            if (altBox.isNotEmpty) {
              print('Found ${altBox.length} items in "$name" box');
              // Could add logic to copy items if needed
            }
          }
        }

        // Let's add a test item to see if that works
        print('Adding a test item with colors to the box');
        final testItem = Item(
          id: 'test-item-${DateTime.now().millisecondsSinceEpoch}',
          imageUrl: 'https://example.com/test.jpg',
          name: 'Test Item',
          description: 'Test item with colors',
          colors: [0xFF0000, 0x00FF00, 0x0000FF], // Red, Green, Blue
          category: 'test',
        );

        await itemsBox.put(testItem.id, testItem);
        print('Test item added. Box length now: ${itemsBox.length}');

        // Add to our items list
        items.add(testItem);
      }

      // Process colors
      final Map<int, ColorTile> colorMap = {};

      for (var item in items) {
        if (item.colors != null && item.colors!.isNotEmpty) {
          for (int colorValue in item.colors!) {
            // Ensure color value has alpha
            final colorWithAlpha = colorValue | 0xFF000000;
            if (!colorMap.containsKey(colorWithAlpha)) {
              try {
                colorMap[colorWithAlpha] = ColorTile(
                    color: Color(colorWithAlpha),
                    itemName: item.name
                );
                print('Added color: 0x${colorWithAlpha.toRadixString(16)} from ${item.name}');
              } catch (e) {
                print('Error creating color (${colorWithAlpha.toRadixString(16)}): $e');
              }
            }
          }
        }
      }

      final uniqueColors = colorMap.values.toList();
      print('Found ${uniqueColors.length} unique colors');

      if (mounted) {
        setState(() {
          _wardrobeColors = uniqueColors;
          if (_wardrobeColors.isNotEmpty) {
            _updatePaletteWithWardrobeColors();
          }
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error in _loadWardrobeColors: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Update palette with wardrobe colors
  void _updatePaletteWithWardrobeColors() {
    // If no wardrobe colors available, keep the default palette
    if (_wardrobeColors.isEmpty) return;

    // Use wardrobe colors for the palette
    int count = min(_palette.length, _wardrobeColors.length);

    for (int i = 0; i < count; i++) {
      if (!_palette[i].isLocked) {
        _palette[i] = ColorTile(
            color: _wardrobeColors[i].color,
            itemName: _wardrobeColors[i].itemName
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The first _paletteSize tiles
    final activePalette = _palette.take(_paletteSize).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE AN OUTFIT',style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// **Title Section**
            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                "LETS CHOOSE A COLOUR PALETTE",
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),

            /// **Palette Size Selection**
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                "COLOUR PALETTE SIZE",
                style: TextStyle(fontFamily: 'Avenir', fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  final size = index + 1;
                  final isSelected = (size == _paletteSize);

                  return GestureDetector(
                    onTap: () {
                      setState(() => _paletteSize = size);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: isSelected
                            ? const Border(
                          bottom: BorderSide(
                            color: Colors.black,
                            width: 4,
                          ),
                        )
                            : null,
                      ),
                      child: Text(
                        size.toString(),
                        style: TextStyle(
                          fontFamily: 'Avenir',
                          fontSize: 16,
                          fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            /// **Draggable Color Tiles**
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  buildDefaultDragHandles: false,
                  children: List.generate(
                    _paletteSize,
                        (i) => _buildColorTileWidget(i, key: ValueKey(i)),
                  ),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final ColorTile tile = _palette.removeAt(oldIndex);
                      _palette.insert(newIndex, tile);
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Available wardrobe colors


            /// **Bottom Buttons**
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// **Generate Palette Button**
                  FloatingActionButton.extended(
                    heroTag: 'generate_btn',
                    onPressed: _generatePalette,
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    label: const Text(
                      "GENERATE",
                      style: TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 14,
                      ),
                    ),
                  ),

                  /// **Confirm Button**
                  FloatingActionButton(
                    onPressed: () {
                      // Convert the active color tiles to a List<Color>
                      final chosenColors = activePalette.map((t) => t.color).toList();

                      // Navigate to CreateOutfitPage with the color palette
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateOutfitPage(
                            colorPalette: chosenColors,
                            savedOutfits: [],
                            selectedDate: selectedDate,
                          ),
                        ),
                      ).then((newOutfit) {
                        if (newOutfit != null) {
                          Map<String, dynamic> outfitData;

                          if (newOutfit is Map<String, dynamic>) {
                            outfitData = newOutfit;
                          } else {
                            outfitData = {
                              'name': newOutfit.name ?? "Outfit for ${selectedDate.toString().split(' ')[0]}",
                              'date': newOutfit.date?.toString() ?? selectedDate.toString(),
                              'clothes': newOutfit.clothes ?? <String, String?>{},
                              'accessories': newOutfit.accessories ?? <String>[],
                              'colorPalette': chosenColors,
                            };
                          }

                          Navigator.pop(context, outfitData);
                        }
                      });
                    },
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.check, size: 28),
                    shape: const CircleBorder(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **Build Each Color Tile**
  Widget _buildColorTileWidget(int i, {Key? key}) {
    final tile = _palette[i];

    return ReorderableDragStartListener(
      key: key!,
      index: i,
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / _paletteSize,
        height: 240,
        decoration: BoxDecoration(
          color: tile.color,
          borderRadius: BorderRadius.circular(1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            /// **Edit Button (Top)**
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () => _editColor(i),
            ),

            /// **Drag Handle (Below Edit Button)**
            const Icon(Icons.drag_indicator, color: Colors.black, size: 28),

            /// **Lock/Unlock Button**
            IconButton(
              icon: Icon(
                tile.isLocked ? Icons.lock : Icons.lock_open,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  tile.isLocked = !tile.isLocked;
                });
              },
            ),

          ],
        ),
      ),
    );
  }

  /// **Edit Color Method**
  Future<void> _editColor(int i) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select a Color",
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _wardrobeColors.map((colorTile) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _palette[i] = ColorTile(
                          color: colorTile.color,
                          isLocked: _palette[i].isLocked,
                          itemName: colorTile.itemName,
                        );
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorTile.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **Generate New Color Palette from Wardrobe Colors**
  Future<void> _generatePalette() async {
    print('Wardrobe colors count: ${_wardrobeColors.length}');

    if (_wardrobeColors.isEmpty) {
      // No wardrobe colors available
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No colors found in your wardrobe. Add some items with colors first."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      List<ColorTile> availableColors = List.from(_wardrobeColors);
      availableColors.shuffle(); // Randomize the order

      int colorIndex = 0;
      for (int i = 0; i < _palette.length; i++) {
        if (!_palette[i].isLocked && colorIndex < availableColors.length) {
          _palette[i] = ColorTile(
              color: availableColors[colorIndex].color,
              itemName: availableColors[colorIndex].itemName
          );
          colorIndex++;
        }

        // If we run out of wardrobe colors, wrap around to the beginning
        if (colorIndex >= availableColors.length) colorIndex = 0;
      }
    });
  }

  // Helper method to check if two colors are similar enough
  bool _colorsAreSimilar(Color color1, Color color2) {
    // Simple color comparison - you could make this more sophisticated
    // Currently checking if individual R,G,B components are within a threshold
    const threshold = 30; // Maximum difference in each color component

    return (color1.red - color2.red).abs() <= threshold &&
        (color1.green - color2.green).abs() <= threshold &&
        (color1.blue - color2.blue).abs() <= threshold;
  }
}


Future<void> _checkItemsExistence() async {
  try {
    final itemsBox = await HiveManager().getBox(ITEMS_BOX_NAME);
    print('Items box exists: ${itemsBox != null}');
    print('Items count: ${itemsBox.length}');


    // List all keys in the box
    print('Item keys: ${itemsBox.keys.toList()}');

    // Try to get the first item if any exists
    if (itemsBox.isNotEmpty) {
      final firstKey = itemsBox.keys.first;
      final firstItem = itemsBox.get(firstKey);
      print('First item: ${firstItem?.name}, Colors: ${firstItem?.colors}');
    }
  } catch (e) {
    print('Error checking items: $e');
  }
}

/// **ColorTile Class**
class ColorTile {
  Color color;
  bool isLocked = false;
  String? itemName; // To track which wardrobe item this color comes from

  ColorTile({required this.color, this.isLocked = false, this.itemName});
}