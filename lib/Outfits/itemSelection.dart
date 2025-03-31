import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

class ItemSelectionPage extends StatefulWidget {
  final String? slot;
  final bool fromCreateOutfit;
  final bool autoSelect;
  final bool preloadOnly;
  final List<Color>? colorPalette; // Added color palette parameter

  const ItemSelectionPage({
    Key? key,
    this.slot,
    this.fromCreateOutfit = false,
    this.autoSelect = false,
    this.preloadOnly = false,
    this.colorPalette, // New parameter for color palette
  }) : super(key: key);

  @override
  State<ItemSelectionPage> createState() => _ItemSelectionPageState();
}

class _ItemSelectionPageState extends State<ItemSelectionPage> {
  Box? itemsBox;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _hasHandledInitialNavigation = false;
  bool _filterByColorPalette = true; // Default to filtering by color palette
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItemsBox();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  Future<void> _loadItemsBox() async {
    try {
      final hiveManager = HiveManager();
      itemsBox = await hiveManager.getBox('itemsBox');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading items box: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Handle navigation once after build is complete
    if (!_hasHandledInitialNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigationAfterBuild();
      });
    }
  }

  void _handleNavigationAfterBuild() {
    if (!mounted || _hasHandledInitialNavigation) return;
    _hasHandledInitialNavigation = true;

    // Add a small delay to ensure the widget tree is fully built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (widget.preloadOnly) {
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
      } else if (widget.autoSelect && filteredItems.isNotEmpty) {
        _selectRandomItem();
      }
    });
  }

  void _selectRandomItem() {
    if (!mounted) return;

    final items = filteredItems;
    if (items.isNotEmpty) {
      final random = math.Random();
      final randomIndex = random.nextInt(items.length);
      final selectedItem = items[randomIndex];

      // Add safety check before navigation
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context, {'item': selectedItem});
      }
    } else {
      // If no items are found, communicate this back
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context, {'error': 'No items found for ${widget.slot}'});
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Simplified color distance calculation that's more reliable
  double _calculateColorDistance(Color color1, Color color2) {
    // Calculate Euclidean distance in RGB space
    final dr = (color1.red - color2.red).abs();
    final dg = (color1.green - color2.green).abs();
    final db = (color1.blue - color2.blue).abs();

    // Calculate weighted distance (human eye is more sensitive to green)
    return math.sqrt(0.299 * dr * dr + 0.587 * dg * dg + 0.114 * db * db);
  }

  // IMPROVED: Check if an item's colors match the color palette with better thresholds
  bool _itemMatchesColorPalette(Item item) {
    // If no color palette is provided or item has no colors, return true
    if (widget.colorPalette == null || widget.colorPalette!.isEmpty ||
        item.colors == null || item.colors!.isEmpty) {
      return true;
    }

    // Special case for white shoes - they match with any palette
    if (widget.slot?.toLowerCase() == "shoes" && _isWhiteOrOffWhite(item)) {
      return true;
    }

    // For each color in the item, find the closest palette color
    double bestScore = double.infinity;

    for (final colorInt in item.colors!) {
      final itemColor = Color(colorInt | 0xFF000000); // Ensure alpha is set

      for (final paletteColor in widget.colorPalette!) {
        final score = _calculateColorDistance(itemColor, paletteColor);
        if (score < bestScore) {
          bestScore = score;
        }
      }
    }

    // Apply appropriate thresholds based on item category
    // Lower thresholds = stricter matching
    double threshold;
    String? slotLower = widget.slot?.toLowerCase();

    if (slotLower == "accessories") {
      threshold = 100.0; // More lenient for accessories
    } else if (slotLower == "shoes") {
      threshold = 80.0; // Slightly more strict for shoes
    } else {
      threshold = 60.0; // Strictest for main clothing items
    }

    return bestScore <= threshold;
  }

  // Check if an item is white or off-white (for shoes special case)
  bool _isWhiteOrOffWhite(Item item) {
    if (item.colors == null || item.colors!.isEmpty) return false;

    for (final colorInt in item.colors!) {
      final color = Color(colorInt | 0xFF000000);

      // Check if the color is white or off-white
      if (_isWhiteColor(color)) {
        return true;
      }
    }

    return false;
  }

  // IMPROVED: Helper to determine if a color is white or off-white with better detection
  bool _isWhiteColor(Color color) {
    // Convert to HSV for better white detection
    final HSVColor hsv = HSVColor.fromColor(color);

    // White has very low saturation and high value
    final bool isLowSaturation = hsv.saturation < 0.15;
    final bool isHighValue = hsv.value > 0.85;

    // Also check RGB values are all high and close to each other
    final int avgRgb = (color.red + color.green + color.blue) ~/ 3;
    final bool isHighBrightness = avgRgb > 220;
    final bool isBalanced =
        (color.red - avgRgb).abs() < 15 &&
            (color.green - avgRgb).abs() < 15 &&
            (color.blue - avgRgb).abs() < 15;

    return isLowSaturation && isHighValue && isHighBrightness && isBalanced;
  }

  List<Item> get filteredItems {
    if (itemsBox == null) return [];

    final List<Item> items = itemsBox!.values.whereType<Item>().where((item) {
      // Check if slot is null first
      if (widget.slot == null) {
        // No slot specified, show all items
        final bool matchesSearch = _searchText.isEmpty ||
            item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            item.description.toLowerCase().contains(_searchText.toLowerCase());
        return matchesSearch;
      }

      // Handle category mapping for singular/plural mismatches
      String slotToMatch = widget.slot!.toLowerCase();
      String itemCategory = item.category.toLowerCase();

      bool matchesSlot = false;

      // For Layer/Layers
      if (slotToMatch == "layer" && itemCategory == "layers") {
        matchesSlot = true;
      }
      // For Shirt/Shirts
      else if (slotToMatch == "shirt" && itemCategory == "shirts") {
        matchesSlot = true;
      }
      // For Bottoms/Bottom
      else if (slotToMatch == "bottoms" && itemCategory == "bottom") {
        matchesSlot = true;
      }
      // For Shoes/Shoe
      else if (slotToMatch == "shoes" && itemCategory == "shoe") {
        matchesSlot = true;
      }
      // For Accessories/Accessory
      else if (slotToMatch == "accessories" && itemCategory == "accessory") {
        matchesSlot = true;
      }
      // Default exact match comparison
      else {
        matchesSlot = itemCategory == slotToMatch;
      }

      // Only show items matching the search query
      final bool matchesSearch = _searchText.isEmpty ||
          item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchText.toLowerCase());

      // Check if we need to filter by color palette
      final bool matchesColorPalette = !_filterByColorPalette || _itemMatchesColorPalette(item);

      return matchesSlot && matchesSearch && matchesColorPalette;
    }).toList();

    // If color palette filtering is enabled, sort items by color similarity
    if (_filterByColorPalette && widget.colorPalette != null && widget.colorPalette!.isNotEmpty) {
      items.sort((a, b) {
        // If one item has colors and the other doesn't, prioritize the one with colors
        if ((a.colors == null || a.colors!.isEmpty) && (b.colors != null && b.colors!.isNotEmpty)) {
          return 1;
        }
        if ((a.colors != null && a.colors!.isNotEmpty) && (b.colors == null || b.colors!.isEmpty)) {
          return -1;
        }

        // If neither has colors, maintain original order
        if ((a.colors == null || a.colors!.isEmpty) && (b.colors == null || b.colors!.isEmpty)) {
          return 0;
        }

        // Calculate best match score for each item
        double bestScoreA = double.infinity;
        double bestScoreB = double.infinity;

        for (final colorInt in a.colors!) {
          final itemColor = Color(colorInt | 0xFF000000);
          for (final paletteColor in widget.colorPalette!) {
            final score = _calculateColorDistance(itemColor, paletteColor);
            if (score < bestScoreA) bestScoreA = score;
          }
        }

        for (final colorInt in b.colors!) {
          final itemColor = Color(colorInt | 0xFF000000);
          for (final paletteColor in widget.colorPalette!) {
            final score = _calculateColorDistance(itemColor, paletteColor);
            if (score < bestScoreB) bestScoreB = score;
          }
        }

        // Sort by best match score (lower is better)
        return bestScoreA.compareTo(bestScoreB);
      });
    }

    return items;
  }

  Future<String> _getImageAbsolutePath(String imagePath) async {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$imagePath';
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
      );
    } else {
      return FutureBuilder<String>(
        future: _getImageAbsolutePath(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          final absolutePath = snapshot.data;
          if (absolutePath != null) {
            final file = File(absolutePath);
            if (file.existsSync()) {
              return Image.file(file, fit: BoxFit.cover);
            }
          }
          return const Icon(Icons.image_not_supported, size: 50);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while the box is being loaded
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text((widget.slot ?? "").toUpperCase() + " ITEMS"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final items = filteredItems;
    final bool hasPalette = widget.colorPalette != null && widget.colorPalette!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.slot ?? "").toUpperCase() + " ITEMS",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // Color palette filter controls - centered and compact
          if (hasPalette)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Color palette display (more compact)
                  Container(
                    height: 24,
                    width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: widget.colorPalette!.map((color) {
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              border: Border.all(color: Colors.black12, width: 0.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Compact filter toggle with label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Filter by palette",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Transform.scale(
                        scale: 0.8, // Make switch smaller
                        child: Switch(
                          value: _filterByColorPalette,
                          onChanged: (value) {
                            setState(() {
                              _filterByColorPalette = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Filter status indicator
          if (hasPalette && _filterByColorPalette)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Showing ${items.length} matching items",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),

          // Items grid
          Expanded(
            child: items.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.palette_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No matching items found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  if (hasPalette && _filterByColorPalette)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _filterByColorPalette = false;
                          });
                        },
                        child: const Text("Show all items"),
                      ),
                    ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () {
                    if (item.inLaundry && widget.fromCreateOutfit) {
                      // Show warning dialog for items in laundry
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Item in Laundry'),
                          content: Text(
                            'This ${item.name} is currently in laundry. Remember to do laundry before the day you plan to wear it!',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Close dialog
                                if (Navigator.of(context).canPop()) {
                                  Navigator.pop(context, {'item': item}); // Return the item anyway
                                }
                              },
                              child: const Text('Use Anyway'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Item is clean or not for an outfit, return it directly
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context, {'item': item});
                      }
                    }
                  },
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              color: Colors.grey[200],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: item.imageUrl.isNotEmpty
                                  ? _buildImage(item.imageUrl)
                                  : const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.inLaundry ? "In Laundry" : "Clean",
                                style: TextStyle(
                                  // Red for laundry, blue for clean
                                  color: item.inLaundry ? Colors.red : Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

