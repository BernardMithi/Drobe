import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'itemSelection.dart';
import 'dart:io';
import 'package:drobe/models/outfit.dart';
import 'dart:math' as math;
import 'package:drobe/utils/image_utils.dart';
import 'package:hive/hive.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/outfitStorage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


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

  // Determine if the "Save" FAB is enabled
  bool get canSave {
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
            icon: const Icon(Icons.account_circle, size: 40),
            onPressed: () {},
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
                fontSize: 14, // 👈 Smaller font size
              ),
              decoration: const InputDecoration(
                labelText: 'OUTFIT NAME',
                labelStyle: TextStyle(
                  fontSize: 15, // 👈 Optional: smaller label too
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
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
            onPressed: _isGenerating ? null : _generateOutfit,
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
            child: const Icon(Icons.check, size: 28), // ✅ Same icon & size as avatar
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
      // Process each clothing category
      for (final category in chosenClothes.keys) {
        bool success = await _ensureItemSelected(category);
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
      final accessoryCount = random.nextInt(3); // 0-2 accessories

      for (int i = 0; i < accessoryCount; i++) {
        await _selectRandomAccessory();
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

  Future<bool> _ensureItemSelected(String category) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final items = await _getItemsForCategory(category);

        if (items.isEmpty) {
          print('No items available for category: $category');
          return false;
        }

        final random = math.Random();
        final selectedItem = items[random.nextInt(items.length)];
        final selectedImageUrl = selectedItem.imageUrl;

        if (selectedImageUrl == null || selectedImageUrl.isEmpty) {
          print('Selected item has no valid image URL');
          continue;
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
            continue;
          }
        }

        setState(() {
          chosenClothes[category] = finalPath;
        });
        return true;
      } catch (e) {
        print('Error selecting item for $category (attempt ${attempt + 1}): $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return false;
  }

  // Helper method to get items for a specific category
  Future<List<Item>> _getItemsForCategory(String category) async {
    try {
      final itemsBox = await Hive.openBox('itemsBox');

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
        String itemCategory = item.category.toLowerCase();
        return itemCategory == dbCategory;
      })
          .toList();

      return filteredItems;
    } catch (e) {
      print('Error getting items for category $category: $e');
      return [];
    }
  }

  // Helper method to select a random accessory
  Future<void> _selectRandomAccessory() async {
    try {
      // Create a set of already selected accessory URLs to check for duplicates
      final selectedAccessoryUrls = chosenAccessories
          .whereType<String>()
          .toSet();

      // Get accessories directly without navigating to selection page
      final accessories = await _getItemsForCategory('Accessories');

      if (accessories.isEmpty) return;

      // Keep trying until we find a non-duplicate or hit a reasonable limit
      int attempts = 0;
      bool foundNewAccessory = false;

      while (!foundNewAccessory && attempts < 5) {
        attempts++;

        // Select a random accessory
        final random = math.Random();
        final selectedItem = accessories[random.nextInt(accessories.length)];
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

          setState(() {
            chosenAccessories.add(finalPath);
          });
        }
      }
    } catch (e) {
      print('Error selecting random accessory: $e');
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
        ),
      ),
    );

    if (result != null && result is Map && result.containsKey('item')) {
      final item = result['item'];
      if (item != null && item.imageUrl != null) {
        setState(() {
          if (replaceIndex != null && replaceIndex < chosenAccessories.length) {
            // Replace existing accessory
            chosenAccessories[replaceIndex] = item.imageUrl;
          } else {
            // Add new accessory
            chosenAccessories.add(item.imageUrl);
          }
        });
      }
    }
  }

  void _saveOutfit() async {
    if (!canSave) return;

    try {
      // Create a list to track all image paths for verification
      List<String> imagePaths = [];

      // Process and verify all clothing image paths in the outfit
      Map<String, String> verifiedClothes = {};
      for (final entry in chosenClothes.entries) {
        if (entry.value != null && entry.value!.isNotEmpty) {
          final imagePath = await _ensureProperImagePath(entry.value);
          if (imagePath != null) {
            verifiedClothes[entry.key] = imagePath;
            imagePaths.add(imagePath);
          }
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
        // Note: assuming ID is handled internally or in the storage service
      );

      // Save using the storage service
      await OutfitStorageService.saveOutfit(newOutfit);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Outfit saved successfully!')),
        );

        // Return to previous screen
        Navigator.pop(context, newOutfit);
      }
    } catch (e) {
      // Show error message
      print('Error saving outfit: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save outfit: ${e.toString()}')),
        );
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