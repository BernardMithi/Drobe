import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/utils/category_utils.dart';

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
  String _currentUserId = '';
  final AuthService _authService = AuthService();

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
      // Get current user ID
      final userData = await _authService.getCurrentUser();
      _currentUserId = userData['id'] ?? '';

      if (_currentUserId.isEmpty) {
        print('Error: Unable to get current user ID');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error: Unable to get user information')),
          );
        }
      }

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
    if (widget.colorPalette == null ||
        widget.colorPalette!.isEmpty ||
        item.colors == null ||
        item.colors!.isEmpty) {
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
    final bool isBalanced = (color.red - avgRgb).abs() < 15 &&
        (color.green - avgRgb).abs() < 15 &&
        (color.blue - avgRgb).abs() < 15;

    return isLowSaturation && isHighValue && isHighBrightness && isBalanced;
  }

  List<Item> get filteredItems {
    if (itemsBox == null) return [];

    final List<Item> items = itemsBox!.values.whereType<Item>().where((item) {
      // Filter by user ID first
      if (_currentUserId.isNotEmpty && item.userId != _currentUserId) {
        return false;
      }

      // Check if slot is null first
      if (widget.slot == null) {
        // No slot specified, show all items
        final bool matchesSearch = _searchText.isEmpty ||
            item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            item.description.toLowerCase().contains(_searchText.toLowerCase());
        return matchesSearch;
      }

      final bool matchesSlot = categoriesMatch(widget.slot!, item.category);

      // Only show items matching the search query
      final bool matchesSearch = _searchText.isEmpty ||
          item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchText.toLowerCase());

      // Check if we need to filter by color palette
      final bool matchesColorPalette =
          !_filterByColorPalette || _itemMatchesColorPalette(item);

      return matchesSlot && matchesSearch && matchesColorPalette;
    }).toList();

    // If color palette filtering is enabled, sort items by color similarity
    if (_filterByColorPalette &&
        widget.colorPalette != null &&
        widget.colorPalette!.isNotEmpty) {
      items.sort((a, b) {
        // If one item has colors and the other doesn't, prioritize the one with colors
        if ((a.colors == null || a.colors!.isEmpty) &&
            (b.colors != null && b.colors!.isNotEmpty)) {
          return 1;
        }
        if ((a.colors != null && a.colors!.isNotEmpty) &&
            (b.colors == null || b.colors!.isEmpty)) {
          return -1;
        }

        // If neither has colors, maintain original order
        if ((a.colors == null || a.colors!.isEmpty) &&
            (b.colors == null || b.colors!.isEmpty)) {
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
    const Color ink = Color(0xFF1C1A18);
    const Color mutedInk = Color(0xFF8A847D);
    const Color line = Color(0xFFEAE6E0);
    const Color surface = Colors.white;
    const Color accent = Color(0xFF8B6C52);

    const Map<String, String> slotTitles = {
      'SHIRT': 'SHIRTS',
      'LAYER': 'LAYERS',
      'BOTTOMS': 'BOTTOMS',
      'SHOES': 'SHOES',
      'ACCESSORIES': 'ACCESSORIES',
      'Accessories': 'ACCESSORIES',
    };
    final String displayTitle = slotTitles[widget.slot] ??
        (widget.slot ?? '').toUpperCase();

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: ink,
          elevation: 0,
          centerTitle: true,
          title: Text(
            displayTitle,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 22,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final items = filteredItems;
    final bool hasPalette =
        widget.colorPalette != null && widget.colorPalette!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 22),
          onPressed: () {
            if (Navigator.of(context).canPop()) Navigator.pop(context);
          },
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontFamily: 'BarlowCondensed',
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    hintStyle: const TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: mutedInk,
                    ),
                    prefixIcon: const Icon(CupertinoIcons.search, size: 18, color: mutedInk),
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: mutedInk),
                    ),
                    suffixIcon: _searchText.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(CupertinoIcons.xmark_circle_fill,
                                size: 16, color: mutedInk),
                          ),
                  ),
                ),

                // Palette bar + toggle
                if (hasPalette) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEAE6E0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.colorPalette!.map((color) {
                        return Expanded(
                          child: Container(color: color),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Filter by palette',
                        style: TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: mutedInk,
                        ),
                      ),
                      Transform.scale(
                        scale: 0.78,
                        child: Switch(
                          value: _filterByColorPalette,
                          activeColor: ink,
                          onChanged: (v) => setState(() => _filterByColorPalette = v),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Items grid
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'NO MATCHING ITEMS',
                      style: TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: mutedInk,
                        letterSpacing: 1.4,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return GestureDetector(
                        onTap: () {
                          if (item.inLaundry && widget.fromCreateOutfit) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  'Item in Laundry',
                                  style: TextStyle(
                                    fontFamily: 'BarlowCondensed',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    color: ink,
                                  ),
                                ),
                                content: Text(
                                  '${item.name} is currently in laundry.',
                                  style: const TextStyle(color: mutedInk),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel',
                                        style: TextStyle(color: mutedInk)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.pop(context, {'item': item});
                                      }
                                    },
                                    child: const Text('Use Anyway',
                                        style: TextStyle(color: ink)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            if (Navigator.of(context).canPop()) {
                              Navigator.pop(context, {'item': item});
                            }
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: line),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(17),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    color: const Color(0xFFF5F5F5),
                                    child: item.imageUrl.isNotEmpty
                                        ? _buildImage(item.imageUrl)
                                        : const Center(
                                            child: Icon(CupertinoIcons.photo,
                                                size: 36, color: mutedInk),
                                          ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontFamily: 'BarlowCondensed',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w300,
                                        color: ink,
                                        height: 1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.inLaundry ? 'In Laundry' : 'Clean',
                                      style: TextStyle(
                                        fontFamily: 'BarlowCondensed',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w300,
                                        color: item.inLaundry
                                            ? const Color(0xFFB04040)
                                            : accent,
                                      ),
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
