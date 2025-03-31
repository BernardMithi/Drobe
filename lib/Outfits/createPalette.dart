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
import 'package:drobe/settings/profile.dart';

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
  bool _useGreyPalette = false; // Only use grey when needed

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate;
    _checkItemsExistence();
    print('InitState: Loading wardrobe colors...');
    _loadWardrobeColors();
  }

  // Initial palette with shades of grey only
  final List<ColorTile> _palette = [
    ColorTile(color: Colors.grey.shade200),
    ColorTile(color: Colors.grey.shade300),
    ColorTile(color: Colors.grey.shade400),
    ColorTile(color: Colors.grey.shade500),
  ];

  // Get a list of grey shades for default palette
  List<Color> _getGreyShades() {
    return [
      Colors.grey.shade200,
      Colors.grey.shade300,
      Colors.grey.shade400,
      Colors.grey.shade500,
      Colors.grey.shade600,
      Colors.grey.shade700,
    ];
  }

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

        // Reset palette to grey shades
        _resetToGreyPalette();
        _useGreyPalette = true;

        // Show notification to user after UI is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showGreyPaletteNotification("Using grayscale palette because your wardrobe is empty.");
          }
        });
      }

      // Process colors
      final Map<int, ColorTile> colorMap = {};

      for (var item in items) {
        if (item.colors != null && item.colors!.isNotEmpty) {
          for (int colorValue in item.colors!) {
            // Ensure color value has alpha
            final colorWithAlpha = colorValue | 0xFF000000;

            // Skip pure red, green, and blue colors (more comprehensive check)
            Color color = Color(colorWithAlpha);
            bool isPureRed = color.red > 240 && color.green < 30 && color.blue < 30;
            bool isPureGreen = color.green > 240 && color.red < 30 && color.blue < 30;
            bool isPureBlue = color.blue > 240 && color.red < 30 && color.green < 30;

            if (isPureRed || isPureGreen || isPureBlue) {
              print('Filtered out test color: 0x${colorWithAlpha.toRadixString(16)}');
              continue;
            }

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

      // Check if we have any real wardrobe colors
      if (uniqueColors.isEmpty) {
        _useGreyPalette = true;

        // Show notification to user after UI is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showGreyPaletteNotification("Using grayscale palette because no colors were found in your wardrobe items.");
          }
        });
      } else {
        // We have real colors from the wardrobe
        _useGreyPalette = false;
      }

      if (mounted) {
        setState(() {
          _wardrobeColors = uniqueColors;
          if (_wardrobeColors.isNotEmpty && !_useGreyPalette) {
            _updatePaletteWithWardrobeColors();
          } else {
            // If no wardrobe colors were found, ensure we use grey palette
            _resetToGreyPalette();
          }
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error in _loadWardrobeColors: $e');
      if (mounted) {
        setState(() {
          // On error, reset to grey palette
          _resetToGreyPalette();
          _useGreyPalette = true;
          _isLoading = false;
        });

        // Show notification to user after UI is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showGreyPaletteNotification("Using grayscale palette due to an error loading your wardrobe colors.");
          }
        });
      }
    }
  }

  // Show notification about using grey palette
  void _showGreyPaletteNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[700],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Reset palette to grey shades
  void _resetToGreyPalette() {
    List<Color> greyShades = _getGreyShades();

    for (int i = 0; i < _palette.length; i++) {
      _palette[i] = ColorTile(
        color: greyShades[i % greyShades.length],
      );
    }
  }

  // Update palette with wardrobe colors
  void _updatePaletteWithWardrobeColors() {
    // If no wardrobe colors available or we're forcing grey palette, keep the default palette
    if (_wardrobeColors.isEmpty || _useGreyPalette) {
      _resetToGreyPalette();
      return;
    }

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
            icon:  Icon(
              Icons.account_circle,
              size: 42,
              color: Colors.grey[800],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfilePage()),
              );
            },
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
                      ).then((result) {
                        if (result != null) {
                          Map<String, dynamic> outfitData;

                          if (result is Map<String, dynamic>) {
                            outfitData = result;
                            // Make sure we include the date in the returned data
                            if (!outfitData.containsKey('date') && result.containsKey('outfit')) {
                              final outfit = result['outfit'];
                              outfitData['date'] = outfit.date?.toString() ?? selectedDate.toString();
                            }
                          } else {
                            outfitData = {
                              'name': result.name ?? "Outfit for ${selectedDate.toString().split(' ')[0]}",
                              'date': result.date?.toString() ?? selectedDate.toString(),
                              'clothes': result.clothes ?? <String, String?>{},
                              'accessories': result.accessories ?? <String>[],
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

    // Determine if the background color is light or dark
    final brightness = ThemeData.estimateBrightnessForColor(tile.color);
    final iconColor = brightness == Brightness.light ? Colors.black : Colors.grey[300];

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
              icon: Icon(Icons.edit, color: iconColor),
              onPressed: () => _editColor(i),
            ),

            /// **Drag Handle (Below Edit Button)**
            Icon(Icons.drag_indicator, color: iconColor, size: 28),

            /// **Lock/Unlock Button**
            IconButton(
              icon: Icon(
                tile.isLocked ? Icons.lock : Icons.lock_open,
                color: iconColor,
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
    // Choose which colors to show based on availability
    List<ColorTile> colorsToShow = _useGreyPalette || _wardrobeColors.isEmpty
        ? _getGreyShades().map((color) => ColorTile(color: color)).toList()
        : _wardrobeColors;

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
              Text(
                _useGreyPalette ? "Select a Grayscale Color" : "Select a Color from Your Wardrobe",
                style: const TextStyle(
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
                children: colorsToShow.map((colorTile) {
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
    print('Use grey palette: $_useGreyPalette');

    // Only use grey palette if there are no wardrobe colors
    if (_wardrobeColors.isEmpty) {
      print('No wardrobe colors available, using grey shades');
      setState(() {
        List<Color> greyShades = _getGreyShades();
        greyShades.shuffle(); // Randomize the order

        for (int i = 0; i < _palette.length; i++) {
          if (!_palette[i].isLocked) {
            _palette[i] = ColorTile(
              color: greyShades[i % greyShades.length],
            );
          }
        }
      });
      return;
    }

    // Use wardrobe colors if available
    print('Using colors from wardrobe');
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
    final itemsBox = await HiveManager().getBox('itemsBox');
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

