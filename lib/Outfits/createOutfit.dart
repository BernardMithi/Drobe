import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'itemSelection.dart';
import 'dart:math' as math;
import 'package:drobe/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:drobe/models/item.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/settings/profile.dart';
import 'package:drobe/models/outfit.dart';
import 'package:drobe/auth/authService.dart';
import 'package:uuid/uuid.dart';

class CreateOutfitPage extends StatefulWidget {
  final List<Color> colorPalette;
  final List<Outfit> savedOutfits;
  final DateTime selectedDate;

  const CreateOutfitPage({
    super.key,
    required this.colorPalette,
    required this.savedOutfits,
    required this.selectedDate,
  });

  @override
  State<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends State<CreateOutfitPage> {
  late DateTime selectedDate;
  final TextEditingController _outfitNameController = TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false; // Add flag to prevent double-saving
  final AuthService _authService = AuthService();
  String _currentUserId = '';

  // Store color tiles from the chosen palette
  late List<ColorTile> _paletteTiles;

  // Map holding the selected image URL for each clothing slot
  Map<String, String?> chosenClothes = {
    'LAYER': null,
    'SHIRT': null,
    'BOTTOMS': null,
    'SHOES': null,
  };

  // List for accessories
  List<String?> chosenAccessories = [];

  // Track previously selected items to ensure variety
  final Map<String, Set<String>> _previouslySelectedItems = {
    'LAYER': {},
    'SHIRT': {},
    'BOTTOMS': {},
    'SHOES': {},
    'ACCESSORIES': {},
  };

  // Track currently selected accessory IDs to prevent duplicates in the same outfit
  final Set<String> _currentOutfitAccessoryIds = {};

  // Determine if the "Save" FAB is enabled
  bool get canSave {
    if (_isSaving || _isGenerating) return false;
    final hasName = _outfitNameController.text.trim().isNotEmpty;
    final hasAtLeastOneClothing =
    chosenClothes.values.any((url) => (url != null && url.isNotEmpty));
    return hasName && hasAtLeastOneClothing;
  }

  @override
  void initState() {
    super.initState();
    selectedDate = widget.selectedDate;
    _paletteTiles = widget.colorPalette.map((c) => ColorTile(color: c)).toList();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    try {
      final userData = await _authService.getCurrentUser();
      setState(() {
        _currentUserId = userData['id'] ?? '';
      });

      if (_currentUserId.isEmpty) {
        print('Error: Unable to get current user ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Unable to get user information')),
        );
      }
    } catch (e) {
      print('Error getting current user: $e');
    }
  }

  @override
  void dispose() {
    // Add dispose for text controller to prevent memory leaks
    _outfitNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFABs(),

      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 115),
        child: Column(
          children: [
            // ** Outfit Name Field **
            TextField(
              controller: _outfitNameController,
              style: const TextStyle(
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                labelText: 'OUTFIT NAME',
                labelStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(),
              ),
              // Remove the onChanged handler that updates state continuously
              // Only update when the user presses done on the keyboard
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                // This will be called when the user presses done on the keyboard
                setState(() {
                  // Update state to refresh the UI if needed
                });
              },
            ),

            const SizedBox(height: 10),

            // ** Palette Display **
            SizedBox(
              height: 40,
              child: Row(
                children: _paletteTiles.map((tile) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tile.color,
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // **Outfit Section: Clothes + Accessories**
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildClothingTile('LAYER'),
                          _buildClothingTile('SHIRT'),
                          _buildClothingTile('BOTTOMS'),
                          _buildClothingTile('SHOES'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Accessories Row
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCESSORIES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                // Use a more dynamic approach for accessories
                                ...List.generate(
                                  // Show selected accessories + one empty tile
                                  math.max(1, chosenAccessories.length + 1),
                                      (index) => index < chosenAccessories.length
                                      ? _buildAccessoryTile(index)
                                      : _buildAccessoryTile(null),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build empty tile with no image
  Widget _buildEmptyTile(String category) {
    return GestureDetector(
      onTap: () => _selectItem(category),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(5),
        ),
        child: _buildClothingPlaceholder(category),
      ),
    );
  }

  // Build clothing tile with image & selection logic
  Widget _buildClothingTile(String category) {
    final String? imageUrl = chosenClothes[category];
    print('Building clothing tile for $category with URL: $imageUrl');

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildEmptyTile(category);
    }

    return GestureDetector(
      onTap: () => _selectItem(category),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(5),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImageWidget(imageUrl),
          ),
          // Add X button to remove the selected item
          Positioned(
            top: 5,
            right: 5,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  chosenClothes[category] = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build image widget with proper handling of different sources
  Widget _buildImageWidget(String imageUrl) {
    print('Building image widget for: $imageUrl');

    if (imageUrl.startsWith('http')) {
      // Network image handling
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          return _buildErrorImagePlaceholder();
        },
      );
    } else if (imageUrl.startsWith('/')) {
      // If it's already an absolute path, use it directly
      final file = File(imageUrl);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading file image: $error');
          return _buildErrorImagePlaceholder();
        },
      );
    } else {
      // Use FutureBuilder to handle async image path resolution
      return FutureBuilder<String>(
        future: getAbsoluteImagePath(imageUrl), // Convert relative path to absolute path
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            final absPath = snapshot.data!;
            print('Loading image from absolute path: $absPath');

            final file = File(absPath);
            if (!file.existsSync()) {
              print('Error: File not found at path $absPath');
              return _buildErrorImagePlaceholder();
            }

            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading file image: $error');
                return _buildErrorImagePlaceholder();
              },
            );
          } else {
            print('Error: Unable to resolve image path');
            return _buildErrorImagePlaceholder();
          }
        },
      );
    }
  }
  // Clothing placeholder - just text, no icon, no background
  Widget _buildClothingPlaceholder([String? category]) {
    return Center(
      child: Text(
        category ?? '',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }

  // Accessory placeholder - just plus icon, no text, no background
  Widget _buildAccessoryPlaceholder() {
    return const Center(
      child: Icon(
        Icons.add,
        size: 32,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildErrorImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(
          Icons.broken_image,
          size: 40,
          color: Colors.red,
        ),
      ),
    );
  }

  // Build accessory item tile - modified to ensure square proportions
  Widget _buildAccessoryTile([int? index]) {
    final bool hasImage = index != null && index < chosenAccessories.length;
    final String? imageUrl = hasImage ? chosenAccessories[index] : null;

    // Calculate the height based on available space
    // Using AspectRatio to force a square shape
    return AspectRatio(
      aspectRatio: 1, // This forces a square shape
      child: GestureDetector(
        onTap: () {
          if (hasImage) {
            // Allow replacing or removing existing accessories
            _editAccessory(index);
          } else {
            // Add new accessory
            _selectAccessory();
          }
        },
        child: Container(
          margin: const EdgeInsets.only(right: 5),
          child: Stack(
            fit: StackFit.expand, // Make sure stack fills the container
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? _buildImageWidget(imageUrl)
                    : _buildAccessoryPlaceholder(), // Use accessory-specific placeholder
              ),
              if (hasImage && imageUrl != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        chosenAccessories.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Show options to edit or remove an accessory
  void _editAccessory(int index) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Replace'),
                onTap: () {
                  Navigator.pop(context);
                  _selectAccessory(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove'),
                onTap: () {
                  setState(() {
                    chosenAccessories.removeAt(index);
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Build the floating action buttons
  Widget _buildFABs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton.extended(
            heroTag: 'generate_fab',
            onPressed: _isGenerating || _isSaving ? null : _generateOutfit,
            label: _isGenerating
                ? const Text('GENERATING...')
                : const Text('GENERATE'),
            backgroundColor: Colors.grey[300],
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),

          // Save Button - Conditionally enabled
          FloatingActionButton(
            onPressed: canSave ? _saveOutfit : null,
            backgroundColor: Colors.grey[300], // ✅ Light Grey (matches avatar)
            foregroundColor: Colors.black, // ✅ Black icon color
            shape: const CircleBorder(), // ✅ Ensures a perfect circle
            child: _isSaving
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.check, size: 28), // ✅ Same icon & size as avatar
          ),
        ],
      ),
    );
  }

  // Generate random outfit
  Future<void> _generateOutfit() async {
    if (_isGenerating) return; // Prevent multiple generations

    setState(() {
      _isGenerating = true;
    });

    // Generate a random outfit name if empty
    if (_outfitNameController.text.trim().isEmpty) {
      final adjectives = ['Cool', 'Casual', 'Elegant', 'Stylish', 'Chic', 'Modern', 'Classic'];
      final nouns = ['Look', 'Outfit', 'Style', 'Ensemble', 'Attire'];
      final random = math.Random();
      final adjective = adjectives[random.nextInt(adjectives.length)];
      final noun = nouns[random.nextInt(nouns.length)];
      _outfitNameController.text = '$adjective $noun';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Clear the current outfit accessory IDs when generating a new outfit
      _currentOutfitAccessoryIds.clear();

      // Track which palette colors are used to ensure variety
      final usedPaletteColors = <Color>{};

      // Process each clothing category in a specific order to ensure coordination
      // Start with main items (shirt, bottoms) then add layers and shoes
      final orderedCategories = ['SHIRT', 'BOTTOMS', 'LAYER', 'SHOES'];

      for (final category in orderedCategories) {
        bool success = await _ensureItemSelected(category, usedPaletteColors);
        if (success) {
          print('Item selected for $category: ${chosenClothes[category]}');
        } else {
          print('Warning: Failed to select item for $category');
        }
      }

      // Handle accessories - clear existing and add new ones
      setState(() {
        chosenAccessories.clear();
      });

      final random = math.Random();
      final accessoryCount = random.nextInt(3) + 1; // 1-3 accessories for more variety

      for (int i = 0; i < accessoryCount; i++) {
        await _selectRandomAccessory(usedPaletteColors);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      print('Error generating outfit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating outfit: $e')),
      );
    } finally {
      // Dismiss loading indicator
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      setState(() {
        _isGenerating = false;
      });
    }
  }

// Enhanced method to select items based on color matching
  Future<bool> _ensureItemSelected(String category, [Set<Color>? usedPaletteColors]) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final items = await _getItemsForCategory(category);

        if (items.isEmpty) {
          print('No items available for category: $category');
          return false;
        }

        // Get items sorted by color similarity to the palette
        final sortedItems = _sortItemsByColorSimilarity(items, category);

        if (sortedItems.isEmpty) {
          print('No suitable items found for $category after color matching with strict thresholds');

          // Try again with more lenient thresholds as a fallback
          final lenientSortedItems = _getLenientColorMatches(items, category);

          if (lenientSortedItems.isNotEmpty) {
            print('Found ${lenientSortedItems.length} items with lenient color matching');
            final selectedItem = _selectItemWithVariety(lenientSortedItems, category);
            return await _selectAndSetItem(selectedItem, category);
          }

          // If still no matches, fall back to random selection
          print('Falling back to random selection');
          final random = math.Random();
          final randomItem = items[random.nextInt(items.length)];
          return await _selectAndSetItem(randomItem, category);
        }

        // Select an item with weighted randomness to ensure variety
        final selectedItem = _selectItemWithVariety(sortedItems, category);
        return await _selectAndSetItem(selectedItem, category);
      } catch (e) {
        print('Error selecting item for $category (attempt ${attempt + 1}): $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

// Helper method to select and set an item
  Future<bool> _selectAndSetItem(Item item, String category) async {
    final selectedImageUrl = item.imageUrl;

    if (selectedImageUrl == null || selectedImageUrl.isEmpty) {
      print('Selected item has no valid image URL');
      return false;
    }

    print('About to update state for $category with URL: $selectedImageUrl');

    // Get absolute path if needed
    String finalPath;
    if (selectedImageUrl.startsWith('http') || selectedImageUrl.startsWith('/')) {
      finalPath = selectedImageUrl;
    } else {
      finalPath = await getAbsoluteImagePath(selectedImageUrl);
    }

    // Verify file exists for local paths
    if (!selectedImageUrl.startsWith('http')) {
      final file = File(finalPath);
      final exists = await file.exists();
      if (!exists) {
        print('File does not exist at path: $finalPath');
        return false;
      }
    }

    // Add to previously selected items to track variety
    _previouslySelectedItems[category]!.add(item.id);

    // Limit the history size to prevent it from growing too large
    if (_previouslySelectedItems[category]!.length > 10) {
      _previouslySelectedItems[category] =
          _previouslySelectedItems[category]!.skip(_previouslySelectedItems[category]!.length - 10).toSet();
    }

    setState(() {
      chosenClothes[category] = finalPath;
    });
    return true;
  }

// Select an item with weighted randomness to ensure variety
  Item _selectItemWithVariety(List<Item> sortedItems, String category) {
    // If we have few items, just use the best match
    if (sortedItems.length <= 2) {
      return sortedItems.first;
    }

    // Create a weighted list favoring items not recently used
    final weightedItems = <Item>[];
    final recentlyUsedIds = _previouslySelectedItems[category]!;

    // Take the top items for consideration, but use a dynamic percentage based on category
    // This allows more variety for accessories and shoes, less for main clothing
    double percentageToConsider;
    if (category == 'ACCESSORIES') {
      percentageToConsider = 0.7; // Consider 70% of matches for accessories
    } else if (category == 'SHOES') {
      percentageToConsider = 0.6; // Consider 60% of matches for shoes
    } else {
      percentageToConsider = 0.5; // Consider 50% of matches for main clothing
    }

    final candidateCount = math.max(3, (sortedItems.length * percentageToConsider).ceil());
    final candidates = sortedItems.take(candidateCount).toList();

    // Shuffle the candidates slightly to introduce more randomness while preserving general order
    if (candidates.length > 3) {
      // Keep the top 3 items in order, shuffle the rest
      final topItems = candidates.take(3).toList();
      final restItems = candidates.skip(3).toList();
      restItems.shuffle();
      candidates.clear();
      candidates.addAll(topItems);
      candidates.addAll(restItems);
    }

    for (final item in candidates) {
      // Add items multiple times based on their priority
      // Items not recently used get added more times (higher chance of selection)
      int weight = recentlyUsedIds.contains(item.id) ? 1 : 3;

      // Give higher weight to top matches, but with diminishing returns
      final index = candidates.indexOf(item);
      if (index < 3) {
        weight += (3 - index);
      } else if (index < 6) {
        weight += 1; // Small boost for items in positions 3-5
      }

      // Add a small random factor to increase variety
      weight += math.Random().nextInt(2);

      for (int i = 0; i < weight; i++) {
        weightedItems.add(item);
      }
    }

    // Select randomly from the weighted list
    final random = math.Random();
    return weightedItems[random.nextInt(weightedItems.length)];
  }

// Enhanced method to sort items by color similarity
  List<Item> _sortItemsByColorSimilarity(List<Item> items, String category) {
    // Filter items that have colors defined
    final itemsWithColors = items.where((item) =>
    item.colors != null && item.colors!.isNotEmpty).toList();

    if (itemsWithColors.isEmpty) {
      print('No items with defined colors found for $category');
      return [];
    }

    // Create a map to store items with their best color match score
    final Map<Item, double> itemScores = {};

    // Track which palette color was the best match for each item
    final Map<Item, Color> bestMatchingPaletteColor = {};

    // Count how many items match each palette color to ensure variety
    final Map<Color, int> paletteColorUsageCount = {};
    for (final color in widget.colorPalette) {
      paletteColorUsageCount[color] = 0;
    }

    for (final item in itemsWithColors) {
      // Special case for white shoes - they match with any palette
      if (category == 'SHOES' && _isWhiteOrOffWhite(item)) {
        itemScores[item] = 0.0; // Perfect score for white shoes
        // Assign a random palette color to avoid skewing the distribution
        bestMatchingPaletteColor[item] = widget.colorPalette[
        math.Random().nextInt(widget.colorPalette.length)
        ];
        continue;
      }

      double bestScore = double.infinity;
      Color? bestColor;

      // For each color in the item, find the closest palette color
      for (final colorInt in item.colors!) {
        final itemColor = Color(colorInt | 0xFF000000); // Ensure alpha is set

        for (final paletteColor in widget.colorPalette) {
          final score = _calculateEnhancedColorDistance(itemColor, paletteColor);
          if (score < bestScore) {
            bestScore = score;
            bestColor = paletteColor;
          }
        }
      }

      // Apply a threshold to determine if the color is "close enough"
      // The threshold is more lenient for accessories and shoes to allow for more variety
      double threshold;
      if (category == 'ACCESSORIES') {
        threshold = 90.0; // Reduced from 120.0 to be more selective
      } else if (category == 'SHOES') {
        threshold = 80.0; // Reduced from 100.0 to be more selective
      } else {
        threshold = 15.0; // Reduced from 70.0 for even stricter matching on main clothing
      }

      if (bestScore <= threshold && bestColor != null) {
        itemScores[item] = bestScore;
        bestMatchingPaletteColor[item] = bestColor;
        paletteColorUsageCount[bestColor] = (paletteColorUsageCount[bestColor] ?? 0) + 1;
      }
    }

    // Sort items by their best match score (lower is better)
    final sortedItems = itemScores.keys.toList();

    // Apply a balanced sorting that considers both color match quality and color variety
    sortedItems.sort((a, b) {
      // Get the best matching palette color for each item
      final colorA = bestMatchingPaletteColor[a];
      final colorB = bestMatchingPaletteColor[b];

      // If they match different palette colors, prioritize the less used color
      if (colorA != colorB && colorA != null && colorB != null) {
        final countA = paletteColorUsageCount[colorA] ?? 0;
        final countB = paletteColorUsageCount[colorB] ?? 0;

        // If one color is significantly more used than the other, prioritize the less used one
        if ((countA - countB).abs() > 1) {
          return countA.compareTo(countB);
        }
      }

      // Otherwise, sort by color match score
      return itemScores[a]!.compareTo(itemScores[b]!);
    });

    // Print some debug info
    if (sortedItems.isNotEmpty) {
      print('Found ${sortedItems.length} matching items for $category');
      print('Best matching item: ${sortedItems.first.name} with score: ${itemScores[sortedItems.first]}');
    }

    return sortedItems;
  }

// Check if an item is white or off-white (for shoes special case)
  bool _isWhiteOrOffWhite(Item item) {
    if (item.colors == null || item.colors!.isEmpty) return false;

    for (final colorInt in item.colors!) {
      final color = Color(colorInt | 0xFF000000);

      // Check if the color is white or off-white
      // White/off-white has high RGB values and low saturation
      if (_isWhiteColor(color)) {
        return true;
      }
    }

    return false;
  }

// Helper to determine if a color is white or off-white
  bool _isWhiteColor(Color color) {
    // Convert to HSV for better white detection
    final double max = math.max(color.red, math.max(color.green, color.blue)) / 255.0;
    final double min = math.min(color.red, math.min(color.green, color.blue)) / 255.0;

    // Calculate saturation: difference between max and min values
    final double saturation = max > 0 ? (max - min) / max : 0;

    // White has high brightness and low saturation
    final bool isHighBrightness = (color.red + color.green + color.blue) / 3 > 220;
    final bool isLowSaturation = saturation < 0.15;

    return isHighBrightness && isLowSaturation;
  }

// Enhanced color distance calculation using HSV color space
  double _calculateEnhancedColorDistance(Color color1, Color color2) {
    // Convert RGB to HSV components for better perceptual comparison
    final HSVColor hsv1 = HSVColor.fromColor(color1);
    final HSVColor hsv2 = HSVColor.fromColor(color2);

    // Calculate hue distance (considering the circular nature of hue)
    double hueDiff = (hsv1.hue - hsv2.hue).abs();
    if (hueDiff > 180) hueDiff = 360 - hueDiff;

    // Normalize hue difference to 0-1 range
    hueDiff /= 180.0;

    // Calculate saturation and value differences
    final double satDiff = (hsv1.saturation - hsv2.saturation).abs();
    final double valDiff = (hsv1.value - hsv2.value).abs();

    // Apply stricter non-linear scaling to hue differences
    // Colors with even slightly different hues should be penalized more
    double scaledHueDiff = hueDiff;
    if (hueDiff > 0.10) { // Reduced from 0.15 to be more sensitive to hue differences
      // Apply stronger exponential scaling for hue differences
      scaledHueDiff = 0.10 + (hueDiff - 0.10) * (hueDiff - 0.10) * 3.0; // Increased multiplier from 2.5 to 3.0
    }

    // Weight the components with increased emphasis on hue and saturation
    final double weightedDiff = (scaledHueDiff * 0.75) + (satDiff * 0.20) + (valDiff * 0.05);

    // Scale to a more intuitive range (0-100)
    return weightedDiff * 100;
  }

// Add a new method to get color matches with more lenient thresholds as a fallback
  List<Item> _getLenientColorMatches(List<Item> items, String category) {
    // Filter items that have colors defined
    final itemsWithColors = items.where((item) =>
    item.colors != null && item.colors!.isNotEmpty).toList();

    if (itemsWithColors.isEmpty) {
      return [];
    }

    // Create a map to store items with their best color match score
    final Map<Item, double> itemScores = {};

    for (final item in itemsWithColors) {
      // Special case for white shoes - they match with any palette
      if (category == 'SHOES' && _isWhiteOrOffWhite(item)) {
        itemScores[item] = 0.0; // Perfect score for white shoes
        continue;
      }

      double bestScore = double.infinity;

      // For each color in the item, find the closest palette color
      for (final colorInt in item.colors!) {
        final itemColor = Color(colorInt | 0xFF000000); // Ensure alpha is set

        for (final paletteColor in widget.colorPalette) {
          final score = _calculateEnhancedColorDistance(itemColor, paletteColor);
          if (score < bestScore) {
            bestScore = score;
          }
        }
      }

      // Apply more lenient thresholds for fallback matches
      double threshold;
      if (category == 'ACCESSORIES') {
        threshold = 130.0; // More lenient than primary threshold
      } else if (category == 'SHOES') {
        threshold = 110.0; // More lenient than primary threshold
      } else {
        threshold = 15.0; // More lenient than primary threshold
      }

      if (bestScore <= threshold) {
        itemScores[item] = bestScore;
      }
    }

    // Sort items by their best match score (lower is better)
    final sortedItems = itemScores.keys.toList()
      ..sort((a, b) => itemScores[a]!.compareTo(itemScores[b]!));

    return sortedItems;
  }

  // Helper method to get items for a specific category
  Future<List<Item>> _getItemsForCategory(String category) async {
    try {
      final itemsBox = await HiveManager().getBox('itemsBox');

      // Handle singular/plural mismatches
      String categoryToMatch = category.toLowerCase();

      // Convert from UI category to database category if needed
      String dbCategory;
      if (categoryToMatch == "layer") dbCategory = "layers";
      else if (categoryToMatch == "shirt") dbCategory = "shirts";
      else if (categoryToMatch == "bottoms") dbCategory = "bottoms";
      else if (categoryToMatch == "shoes") dbCategory = "shoes";
      else if (categoryToMatch == "accessories") dbCategory = "accessories";
      else dbCategory = categoryToMatch;

      final filteredItems = itemsBox.values
          .whereType<Item>() // Use whereType instead of cast
          .where((item) {
        // Filter by user ID first
        if (_currentUserId.isNotEmpty && item.userId != _currentUserId) {
          return false;
        }

        String itemCategory = item.category.toLowerCase();

        // Filter out items that are in laundry during automatic generation
        if (item.inLaundry) {
          print('Skipping item ${item.name} because it is in laundry');
          return false;
        }

        return itemCategory == dbCategory;
      })
          .toList();

      return filteredItems;
    } catch (e) {
      print('Error getting items for category $category: $e');
      return [];
    }
  }

  // Enhanced method to select a random accessory with color matching
  Future<void> _selectRandomAccessory([Set<Color>? usedPaletteColors]) async {
    try {
      // Create a set of already selected accessory URLs to check for duplicates
      final selectedAccessoryUrls = chosenAccessories
          .whereType<String>()
          .toSet();

      // Get accessories directly without navigating to selection page
      final accessories = await _getItemsForCategory('Accessories');

      if (accessories.isEmpty) return;

      // Filter out accessories that are already in the current outfit
      // AND filter out accessories that are in laundry
      final availableAccessories = accessories.where((item) =>
      !_currentOutfitAccessoryIds.contains(item.id) && !item.inLaundry).toList();

      if (availableAccessories.isEmpty) {
        print('No more unique accessories available');
        return;
      }

      // Sort accessories by color similarity to the palette
      final sortedAccessories = _sortItemsByColorSimilarity(availableAccessories, 'ACCESSORIES');

      // If no color matches found, use random selection
      if (sortedAccessories.isEmpty) {
        _selectRandomAccessoryFromList(availableAccessories, selectedAccessoryUrls);
        return;
      }

      // Select an accessory with weighted randomness to ensure variety
      final selectedItem = _selectItemWithVariety(sortedAccessories, 'ACCESSORIES');
      final newAccessoryUrl = selectedItem.imageUrl;

      if (newAccessoryUrl != null && newAccessoryUrl.isNotEmpty &&
          !selectedAccessoryUrls.contains(newAccessoryUrl)) {

        // Get absolute path if needed
        String finalPath;
        if (newAccessoryUrl.startsWith('http') || newAccessoryUrl.startsWith('/')) {
          finalPath = newAccessoryUrl;
        } else {
          finalPath = await getAbsoluteImagePath(newAccessoryUrl);
        }

        // Add to previously selected items to track variety
        _previouslySelectedItems['ACCESSORIES']!.add(selectedItem.id);

        // Add to current outfit accessory IDs to prevent duplicates
        _currentOutfitAccessoryIds.add(selectedItem.id);

        setState(() {
          chosenAccessories.add(finalPath);
        });
      } else {
        // If the selected item is already in the accessories or has no valid URL, try another one
        _selectRandomAccessoryFromList(availableAccessories, selectedAccessoryUrls);
      }
    } catch (e) {
      print('Error selecting random accessory: $e');
    }
  }

// Modify the _selectRandomAccessoryFromList method to ensure we're only using clean items
  void _selectRandomAccessoryFromList(List<Item> accessories, Set<String> selectedAccessoryUrls) async {
    int attempts = 0;
    bool foundNewAccessory = false;

    while (!foundNewAccessory && attempts < 5) {
      attempts++;

      // Select a random accessory
      final random = math.Random();
      final selectedItem = accessories[random.nextInt(accessories.length)];

      // Double-check it's not in laundry (should already be filtered, but just to be safe)
      if (selectedItem.inLaundry) {
        print('Skipping ${selectedItem.name} because it is in laundry');
        continue;
      }

      final newAccessoryUrl = selectedItem.imageUrl;

      // Check if this accessory is already selected
      if (newAccessoryUrl != null && newAccessoryUrl.isNotEmpty &&
          !selectedAccessoryUrls.contains(newAccessoryUrl)) {
        foundNewAccessory = true;

        // Get absolute path if needed
        String finalPath;
        if (newAccessoryUrl.startsWith('http') || newAccessoryUrl.startsWith('/')) {
          finalPath = newAccessoryUrl;
        } else {
          finalPath = await getAbsoluteImagePath(newAccessoryUrl);
        }

        // Add to previously selected items to track variety
        _previouslySelectedItems['ACCESSORIES']!.add(selectedItem.id);

        // Add to current outfit accessory IDs to prevent duplicates
        _currentOutfitAccessoryIds.add(selectedItem.id);

        setState(() {
          chosenAccessories.add(finalPath);
        });
      }
    }
  }

  // Logic for selecting a clothing item - updated to properly filter by category
  void _selectItem(String category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemSelectionPage(
          slot: category,  // This will be used to filter items by category
          fromCreateOutfit: true,
          colorPalette: widget.colorPalette, // Pass the color palette
        ),
      ),
    );

    if (result != null && result is Map && result.containsKey('item')) {
      final item = result['item'];
      if (item != null && item.imageUrl != null) {
        setState(() {
          chosenClothes[category] = item.imageUrl;
        });
      }
    }
  }

  // Logic for selecting an accessory - similar to _selectItem but for accessories
  void _selectAccessory([int? replaceIndex]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemSelectionPage(
          slot: 'Accessories', // This filters items to show only accessories
          fromCreateOutfit: true,
          colorPalette: widget.colorPalette, // Pass the color palette
        ),
      ),
    );

    if (result != null && result is Map && result.containsKey('item')) {
      final item = result['item'];
      if (item != null && item.imageUrl != null) {
        // If replacing an existing accessory, remove the old one from tracking
        if (replaceIndex != null && replaceIndex < chosenAccessories.length) {
          // We don't have the ID of the old accessory, so we can't remove it from _currentOutfitAccessoryIds

          setState(() {
            chosenAccessories[replaceIndex] = item.imageUrl;
          });
        } else {
          // Add new accessory
          setState(() {
            chosenAccessories.add(item.imageUrl);
          });
        }
      }
    }
  }

  void _saveOutfit() async {
    if (!canSave) return;

    // Prevent multiple saves
    setState(() {
      _isSaving = true;
    });

    try {
      // Create a list to track all image paths for verification
      List<String> imagePaths = [];

      // Process and verify all clothing image paths in the outfit
      Map<String, String?> verifiedClothes = {};

      // Ensure all standard categories are included in the outfit, even if empty
      final standardCategories = ['LAYER', 'SHIRT', 'BOTTOMS', 'SHOES'];
      for (final category in standardCategories) {
        final value = chosenClothes[category];
        if (value != null && value.isNotEmpty) {
          final imagePath = await _ensureProperImagePath(value);
          if (imagePath != null) {
            verifiedClothes[category] = imagePath;
            imagePaths.add(imagePath);
          }
        } else {
          // Include the category with null value to ensure it appears in the outfit
          verifiedClothes[category] = null;
        }
      }

      // Process and verify all accessories image paths
      List<String> verifiedAccessories = [];
      for (final accessoryPath in chosenAccessories) {
        if (accessoryPath != null && accessoryPath.isNotEmpty) {
          final verifiedPath = await _ensureProperImagePath(accessoryPath);
          if (verifiedPath != null) {
            verifiedAccessories.add(verifiedPath);
            imagePaths.add(verifiedPath);
          }
        }
      }

      // Log all image paths for debugging
      print('Saving outfit with the following images:');
      for (final path in imagePaths) {
        if (!path.startsWith('http')) {
          bool exists = await File(path).exists();
          print('  - $path (exists: $exists)');
        } else {
          print('  - $path (network image)');
        }
      }

      // Create a new outfit object with verified paths
      final newOutfit = Outfit(
        name: _outfitNameController.text.trim(),
        clothes: verifiedClothes,
        accessories: verifiedAccessories,
        date: selectedDate,
        colorPalette: widget.colorPalette,
        userId: _currentUserId, // Add the user ID to the outfit
        // Note: ID will be generated by the OutfitStorageService
      );

      // Return the outfit to the previous screen instead of saving it here
      // This prevents double-saving since the calling screen will handle the save
      if (context.mounted) {
        // Return to previous screen with the outfit data and the selected date
        Navigator.pop(context, {
          'outfit': newOutfit,
          'date': selectedDate,
        });
      }
    } catch (e) {
      // Show error message
      print('Error preparing outfit: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare outfit: ${e.toString()}')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String?> _ensureProperImagePath(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      // If it's a network image, return as is
      if (imagePath.startsWith('http')) {
        return imagePath;
      }

      // If it's already an absolute path, verify it exists
      if (imagePath.startsWith('/')) {
        final file = File(imagePath);
        if (await file.exists()) {
          return imagePath;
        }
      }

      // Try to get absolute path from relative path
      try {
        final absolutePath = await getAbsoluteImagePath(imagePath);
        final file = File(absolutePath);
        if (await file.exists()) {
          return absolutePath;
        }
      } catch (e) {
        print('Error resolving absolute path: $e');
      }

      // Get the app's documents directory and try different locations
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imagePath);

      // Try in the wardrobe_images directory
      final wardrobeImagesPath = path.join(appDir.path, 'wardrobe_images');
      final wardrobePath = path.join(wardrobeImagesPath, fileName);
      if (await File(wardrobePath).exists()) {
        return wardrobePath;
      }

      // Try in the main documents directory
      final possiblePath = path.join(appDir.path, fileName);
      if (await File(possiblePath).exists()) {
        return possiblePath;
      }

      // Try with the original path as a fallback
      if (await File(imagePath).exists()) {
        return imagePath;
      }

      print('Warning: Could not find valid path for image: $imagePath');
      return imagePath; // Return original path as fallback
    } catch (e) {
      print('Error resolving path: $e');
      return imagePath; // Return original path in case of error
    }
  }
}

// Simple ColorTile class
class ColorTile {
  final Color color;
  ColorTile({required this.color});
}

// Helper function to convert stored relative paths to absolute paths.
Future<String> getAbsoluteImagePath(String storedPath) async {
  final directory = await getApplicationDocumentsDirectory();
  if (storedPath.contains('/Documents/')) {
    const docsKeyword = '/Documents/';
    final index = storedPath.indexOf(docsKeyword);
    final relativePath = storedPath.substring(index + docsKeyword.length);
    return path.join(directory.path, relativePath);
  } else {
    return path.join(directory.path, storedPath);
  }
}

