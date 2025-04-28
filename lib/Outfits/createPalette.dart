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
import 'package:drobe/auth/authService.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

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
  String? _currentUserId;
  final AuthService _authService = AuthService();
  String _selectedColorScheme = 'custom'; // Default to custom
  final List<String> _colorSchemes = ['custom', 'monochromatic', 'complementary', 'analogous'];
  String? _colorTheoryTip;
  Color? _baseTheoryColor;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate;
    _getCurrentUserId();
    print('InitState: Loading wardrobe colors...');
  }

  // Get current user ID
  Future<void> _getCurrentUserId() async {
    try {
      final userData = await _authService.getCurrentUser();
      final userId = userData['id'];
      setState(() {
        _currentUserId = userId;
      });
      print('Current user ID: $_currentUserId');
      _checkItemsExistence();
      _loadWardrobeColors();
    } catch (e) {
      print('Error getting current user ID: $e');
      // Still try to load colors, but they won't be filtered by user
      _checkItemsExistence();
      _loadWardrobeColors();
    }
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
            // Filter by user ID if available
            if (_currentUserId != null && item.userId != null && item.userId != _currentUserId) {
              print('Skipping item ${item.name} - belongs to user ${item.userId}, not $_currentUserId');
              continue;
            }

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
                  userId: item['userId'] as String? ?? _currentUserId,
                );

                // Filter by user ID if available
                if (_currentUserId != null && convertedItem.userId != null &&
                    convertedItem.userId != _currentUserId) {
                  continue;
                }

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
    _colorTheoryTip = _analyzePalette();
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
            icon: Icon(
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
            const SizedBox(height: 5),

            /// **Palette Size Selection**
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                "COLOUR PALETTE SIZE",
                style: TextStyle(fontFamily: 'Avenir', fontSize: 15, fontWeight: FontWeight.w600),
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

            /// **Color Theory Selection**
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: Text(
                "COLOR THEORY",
                style: TextStyle(fontFamily: 'Avenir', fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _colorSchemes.map((scheme) {
                    final isSelected = (scheme == _selectedColorScheme);

                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedColorScheme = scheme);
                          if (scheme != 'custom') {
                            _generateTheoryBasedPalette();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            scheme.capitalize(),
                            style: TextStyle(
                              fontFamily: 'Avenir',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            if (_colorTheoryTip != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _colorTheoryTip!,
                    style: TextStyle(
                      fontFamily: 'Avenir',
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),

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

                      // If we're in a color theory mode, update the base color if the first tile changed
                      if (_selectedColorScheme != 'custom') {
                        _baseTheoryColor = _palette[0].color;
                      }
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
                    label: Text(
                      _selectedColorScheme == 'custom'
                          ? "GENERATE"
                          : "GENERATE ${_selectedColorScheme.toUpperCase()}",
                      style: const TextStyle(
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
                              'userId': _currentUserId, // Add user ID to the outfit
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

            // Display item name if available
            if (tile.itemName != null && tile.itemName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tile.itemName!,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
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
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorsToShow.map((colorTile) {
                      return Tooltip(
                        message: colorTile.itemName ?? '',
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _palette[i] = ColorTile(
                                color: colorTile.color,
                                isLocked: _palette[i].isLocked,
                                itemName: colorTile.itemName,
                              );

                              // If this is the first color and we're in a color theory mode,
                              // update the base color
                              if (i == 0 && _selectedColorScheme != 'custom') {
                                _baseTheoryColor = colorTile.color;
                                // Generate new palette based on this color
                                _generateTheoryBasedPalette();
                              }
                            });
                            _colorTheoryTip = _analyzePalette();
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
                        ),
                      );
                    }).toList(),
                  ),
                ),
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

    // If a color theory scheme is selected, use that instead
    if (_selectedColorScheme != 'custom') {
      _generateTheoryBasedPalette();
      return;
    }

    // Only use grey palette if there are no wardrobe colors
    if (_wardrobeColors.isEmpty) {
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

  // Convert Color to HSL values
  Map<String, double> _colorToHSL(Color color) {
    // Convert RGB to HSL
    final r = color.red / 255;
    final g = color.green / 255;
    final b = color.blue / 255;

    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));

    double h = 0, s = 0, l = (max + min) / 2;

    if (max != min) {
      final d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

      if (max == r) {
        h = (g - b) / d + (g < b ? 6 : 0);
      } else if (max == g) {
        h = (b - r) / d + 2;
      } else if (max == b) {
        h = (r - g) / d + 4;
      }

      h /= 6;
    }

    return {'h': h * 360, 's': s, 'l': l};
  }

  // Convert HSL to Color
  Color _hslToColor(double h, double s, double l) {
    // Convert HSL to RGB
    double r, g, b;

    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      final p = 2 * l - q;

      r = _hueToRGB(p, q, h + 1/3);
      g = _hueToRGB(p, q, h);
      b = _hueToRGB(p, q, h - 1/3);
    }

    return Color.fromARGB(
      255,
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }

  double _hueToRGB(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1/6) return p + (q - p) * 6 * t;
    if (t < 1/2) return q;
    if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
    return p;
  }

  // Replace the _generateTheoryBasedPalette method with this updated version that introduces variation
  void _generateTheoryBasedPalette() {
    if (_wardrobeColors.isEmpty) {
      _showGreyPaletteNotification("No wardrobe colors available for color theory.");
      return;
    }

    // Reset color theory tip
    _colorTheoryTip = null;

    // Choose a base color from wardrobe or current palette if not already set
    if (_baseTheoryColor == null || _selectedColorScheme == 'custom') {
      if (_palette.isNotEmpty && !_useGreyPalette) {
        // Use the first unlocked color or the first color if all are locked
        int baseIndex = _palette.indexWhere((tile) => !tile.isLocked);
        if (baseIndex == -1) baseIndex = 0;
        _baseTheoryColor = _palette[baseIndex].color;
      } else {
        // Choose a random color from wardrobe
        _baseTheoryColor = _wardrobeColors[math.Random().nextInt(_wardrobeColors.length)].color;
      }
    }

    // Convert to HSL for easier manipulation
    final hsl = _colorToHSL(_baseTheoryColor!);

    // Generate new palette based on selected scheme
    List<Color> newColors = [];
    final random = math.Random();

    switch (_selectedColorScheme) {
      case 'monochromatic':
      // Create variations with same hue, different saturation/lightness
      // Add randomness to saturation and lightness while keeping the hue constant
        newColors = [
          _baseTheoryColor!, // Original color always stays the same
          _hslToColor(
              hsl['h']! / 360,
              math.min(1.0, hsl['s']! * (0.6 + random.nextDouble() * 0.4)),
              math.min(0.9, hsl['l']! * (1.2 + random.nextDouble() * 0.3))
          ), // Lighter with randomness
          _hslToColor(
              hsl['h']! / 360,
              math.min(1.0, hsl['s']! * (1.0 + random.nextDouble() * 0.4)),
              math.max(0.1, hsl['l']! * (0.7 + random.nextDouble() * 0.3))
          ), // Darker with randomness
          _hslToColor(
              hsl['h']! / 360,
              math.min(1.0, hsl['s']! * (0.4 + random.nextDouble() * 0.3)),
              math.min(0.95, hsl['l']! * (1.0 + random.nextDouble() * 0.2))
          ), // Desaturated with randomness
        ];
        _colorTheoryTip = "Monochromatic: These colors are all variations of the same hue, creating a harmonious and cohesive look.";
        break;

      case 'complementary':
      // Create a complementary color (opposite on color wheel) and variations
      // Add slight randomness to the complementary hue
        double complementaryHue = (hsl['h']! + 180 + (random.nextDouble() * 20 - 10)) % 360;
        newColors = [
          _baseTheoryColor!, // Original color always stays the same
          _hslToColor(
              complementaryHue / 360,
              math.min(1.0, hsl['s']! * (0.9 + random.nextDouble() * 0.2)),
              math.min(0.9, hsl['l']! * (0.9 + random.nextDouble() * 0.2))
          ), // Complementary with slight variation
          _hslToColor(
              hsl['h']! / 360,
              math.min(1.0, hsl['s']! * (0.7 + random.nextDouble() * 0.3)),
              math.min(0.9, hsl['l']! * (1.1 + random.nextDouble() * 0.2))
          ), // Lighter original with randomness
          _hslToColor(
              complementaryHue / 360,
              math.min(1.0, hsl['s']! * (0.7 + random.nextDouble() * 0.3)),
              math.min(0.9, hsl['l']! * (1.1 + random.nextDouble() * 0.2))
          ), // Lighter complementary with randomness
        ];
        _colorTheoryTip = "Complementary: These colors are opposite each other on the color wheel, creating a vibrant contrast.";
        break;

      case 'analogous':
      // Create colors adjacent on the color wheel with some randomness
        double angle1 = -30 + (random.nextDouble() * 10 - 5); // -35 to -25 degrees
        double angle2 = 30 + (random.nextDouble() * 10 - 5);  // 25 to 35 degrees
        double angle3 = 60 + (random.nextDouble() * 10 - 5);  // 55 to 65 degrees

        newColors = [
          _baseTheoryColor!, // Original color always stays the same
          _hslToColor(
              ((hsl['h']! + angle1) + 360) % 360 / 360,
              math.min(1.0, hsl['s']! * (0.9 + random.nextDouble() * 0.2)),
              math.min(0.9, hsl['l']! * (0.9 + random.nextDouble() * 0.2))
          ), // Adjacent with variation
          _hslToColor(
              ((hsl['h']! + angle2) + 360) % 360 / 360,
              math.min(1.0, hsl['s']! * (0.9 + random.nextDouble() * 0.2)),
              math.min(0.9, hsl['l']! * (0.9 + random.nextDouble() * 0.2))
          ), // Adjacent with variation
          _hslToColor(
              ((hsl['h']! + angle3) + 360) % 360 / 360,
              math.min(1.0, hsl['s']! * (0.9 + random.nextDouble() * 0.2)),
              math.min(0.9, hsl['l']! * (0.9 + random.nextDouble() * 0.2))
          ), // Adjacent with variation
        ];
        _colorTheoryTip = "Analogous: These colors are adjacent to each other on the color wheel, creating a harmonious and natural look.";
        break;

      default: // 'custom'
      // Just use random wardrobe colors
        _generatePalette();
        return;
    }

    // Update palette with new colors
    setState(() {
      for (int i = 0; i < _palette.length; i++) {
        if (!_palette[i].isLocked && i < newColors.length) {
          _palette[i] = ColorTile(
            color: newColors[i],
            itemName: i == 0 ? "Base Color" : "${_selectedColorScheme.capitalize()} ${i}",
          );
        }
      }

      // Show tip if available
      if (_colorTheoryTip != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_colorTheoryTip!),
                backgroundColor: Colors.black87,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
      }
    });
  }

  // Analyze current palette and provide color theory suggestions
  String _analyzePalette() {
    if (_palette.isEmpty || _paletteSize < 2) {
      return "Add more colors to get color theory suggestions.";
    }

    List<Map<String, double>> hslColors = [];
    for (int i = 0; i < _paletteSize; i++) {
      hslColors.add(_colorToHSL(_palette[i].color));
    }

    // Check if monochromatic
    bool isMonochromatic = true;
    double baseHue = hslColors[0]['h']!;
    for (int i = 1; i < hslColors.length; i++) {
      if ((hslColors[i]['h']! - baseHue).abs() > 15) {
        isMonochromatic = false;
        break;
      }
    }

    if (isMonochromatic) {
      return "Your palette is monochromatic. Consider adding a complementary color for more contrast.";
    }

    // Check if analogous
    bool isAnalogous = true;
    for (int i = 1; i < hslColors.length; i++) {
      double hueDiff = (hslColors[i]['h']! - baseHue).abs();
      if (hueDiff > 60 && hueDiff < 300) {
        isAnalogous = false;
        break;
      }
    }

    if (isAnalogous) {
      return "Your palette is analogous. These colors work well together for a harmonious look.";
    }

    // Check if complementary
    bool hasComplementary = false;
    for (int i = 1; i < hslColors.length; i++) {
      double hueDiff = (hslColors[i]['h']! - baseHue).abs();
      if (hueDiff > 150 && hueDiff < 210) {
        hasComplementary = true;
        break;
      }
    }

    if (hasComplementary) {
      return "Your palette includes complementary colors, which create a vibrant contrast.";
    }

    return "Your custom palette combines multiple color relationships.";
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
