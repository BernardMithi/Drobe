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
      // Open the items box from Hive
      final itemsBox = await Hive.openBox<Item>('itemsBox');
      final items = itemsBox.values.toList();

      print('Found ${items.length} items in wardrobe'); // Debug log item count

      // Map to track unique colors (using color value as key)
      final Map<int, ColorTile> colorMap = {};

      for (var item in items) {
        print('Item: ${item.name}, Colors: ${item.colors}'); // Log each item and its colors

        // Extract colors from item - more forgiving approach
        if (item.colors != null) {
          List<int> colorsList = [];

          // Handle different potential formats of item.colors
          if (item.colors is List<int>) {
            colorsList = item.colors as List<int>;
          } else if (item.colors is List<dynamic>) {
            // Try to convert dynamic list to int list
            colorsList = (item.colors as List<dynamic>)
                .whereType<int>()
                .toList();
          }

          print('Processed colors list: $colorsList'); // Log processed colors list

          for (int colorValue in colorsList) {
            // Ensure color value is valid (has alpha channel)
            final adjustedColorValue = colorValue | 0xFF000000; // Ensure alpha is set

            print('Adding color: 0x${adjustedColorValue.toRadixString(16)}'); // Log each color

            // Add to our map if we haven't seen this color before
            if (!colorMap.containsKey(adjustedColorValue)) {
              try {
                final color = Color(adjustedColorValue);
                colorMap[adjustedColorValue] = ColorTile(
                    color: color,
                    itemName: item.name
                );
              } catch (e) {
                print('Error creating color: $e');
              }
            }
          }
        }
      }

      // Convert map values to our available colors list
      final uniqueColors = colorMap.values.toList();
      print('Extracted ${uniqueColors.length} unique colors: $uniqueColors'); // Log unique colors

      setState(() {
        _wardrobeColors = uniqueColors;
        print('Set _wardrobeColors to ${_wardrobeColors.length} colors'); // Log after setting

        // Generate initial palette from wardrobe colors
        _updatePaletteWithWardrobeColors();

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading wardrobe colors: $e');
      setState(() => _isLoading = false);
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

            // Available wardrobe colors
            if (_wardrobeColors.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AVAILABLE COLORS IN YOUR WARDROBE",
                      style: TextStyle(
                        fontFamily: 'Avenir',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _wardrobeColors.length,
                        itemBuilder: (context, index) {
                          final colorTile = _wardrobeColors[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                // When tapped, replace the first unlocked color in the palette
                                for (int i = 0; i < _palette.length; i++) {
                                  if (!_palette[i].isLocked) {
                                    setState(() {
                                      _palette[i] = ColorTile(
                                          color: colorTile.color,
                                          itemName: colorTile.itemName
                                      );
                                    });
                                    break;
                                  }
                                }
                              },
                              child: Tooltip(
                                message: colorTile.itemName ?? "Wardrobe color",
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: colorTile.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.black12),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

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
        height: 320,
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

            // Show item source if available
            if (tile.itemName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tile.itemName!,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// **Edit Color Method**
  Future<void> _editColor(int i) async {
    TextEditingController colorController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.grey[200],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// **Dialog Title**
              const Text(
                "Enter HEX Color",
                style: TextStyle(
                  fontFamily: 'Avenir',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              /// **HEX Input Field**
              TextField(
                controller: colorController,
                style: const TextStyle(fontFamily: 'Avenir', color: Colors.black),
                decoration: InputDecoration(
                  hintText: "e.g., #A1A1A1",
                  hintStyle: TextStyle(fontFamily: 'Avenir', color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[300],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(color: Colors.grey[500]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              /// **Dialog Buttons**
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// **Cancel Button**
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),

                  /// **Confirm Button**
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      String hexColor = colorController.text.trim();

                      // If it doesn't start with #, add it
                      if (!hexColor.startsWith('#') && hexColor.length == 6) {
                        hexColor = "#$hexColor";
                      }

                      // Convert hex to Color if valid
                      Color? newColor;
                      try {
                        // Remove # and parse
                        if (hexColor.startsWith('#') && hexColor.length == 7) {
                          final hexValue = int.parse('FF${hexColor.substring(1)}', radix: 16);
                          newColor = Color(hexValue);
                        }
                      } catch (e) {
                        print('Invalid hex color: $e');
                      }

                      if (newColor != null) {
                        // Check if this color exists in the wardrobe
                        bool colorInWardrobe = false;
                        for (var wardrobeColor in _wardrobeColors) {
                          // Allow some flexibility in color matching
                          // Check if the colors are similar enough
                          if (_colorsAreSimilar(wardrobeColor.color, newColor)) {
                            colorInWardrobe = true;
                            break;
                          }
                        }

                        if (!colorInWardrobe) {
                          // Show warning but still allow using the color
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Warning: This color doesn't exist in your wardrobe. "
                                      "You might not have matching items."
                              ),
                              duration: Duration(seconds: 3),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }

                        // Update the color and close dialog
                        setState(() {
                          _palette[i] = ColorTile(
                            color: newColor!,
                            isLocked: _palette[i].isLocked,
                            // Clear the item name since this is a custom color
                            itemName: colorInWardrobe ? null : "Custom color",
                          );
                        });
                        Navigator.pop(context);
                      } else {
                        // Show error for invalid hex
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Invalid HEX color format. Use format #RRGGBB."),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text("OK"),
                  ),
                ],
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
    final itemsBox = await Hive.openBox<Item>('items');
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