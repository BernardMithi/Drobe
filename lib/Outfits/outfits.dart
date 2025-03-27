import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'createOutfit.dart';
import 'package:drobe/models/item.dart';
import 'itemSelection.dart';
import 'createPalette.dart';
import 'package:drobe/models/outfit.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/services/outfitStorage.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:drobe/settings/profile.dart';

class OutfitsPage extends StatefulWidget {
  const OutfitsPage({Key? key}) : super(key: key);

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> {
  DateTime selectedDate = DateTime.now();
  final PageController _outfitController = PageController();
  int _currentOutfitIndex = 0;
  bool _isEditing = false;
  bool _isLoading = true;
  Timer? _debounceTimer;


  // Stores only Outfit objects
  final Map<DateTime, List<Outfit>> outfitsPerDay = {};

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  @override
  void dispose() {
    _outfitController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _getFormattedDate(DateTime date) {
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  // This method resolves the correct file path
  Future<String?> _resolveFilePath(String imagePath) async {
    try {
      // If it's a network image, return as is
      if (imagePath.startsWith('http')) {
        return imagePath;
      }

      // Try to use the path directly first
      if (await File(imagePath).exists()) {
        return imagePath;
      }

      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imagePath);

      // Try to find the file in the wardrobe_images directory
      final wardrobeDir = Directory('${appDir.path}/wardrobe_images');
      final wardrobePath = path.join(wardrobeDir.path, fileName);

      if (await File(wardrobePath).exists()) {
        return wardrobePath;
      }

      // Try in the main documents directory
      final possiblePath = path.join(appDir.path, fileName);
      if (await File(possiblePath).exists()) {
        return possiblePath;
      }

      // Try in temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, fileName);
      if (await File(tempPath).exists()) {
        return tempPath;
      }

      print('Could not resolve path for: $imagePath');
      return null;
    } catch (e) {
      print('Error resolving path: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedDate = _normalizeDate(selectedDate);
    final outfitsForSelectedDate = outfitsPerDay[normalizedDate] ?? [];
    final int outfitCount = outfitsForSelectedDate.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OUTFITS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FloatingActionButton(
                heroTag: 'editBtn',
                backgroundColor: Colors.grey[300],
                shape: const CircleBorder(),
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
                child: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.black),
              ),
              FloatingActionButton(
                heroTag: 'addBtn',
                backgroundColor: Colors.grey[300],
                shape: const CircleBorder(),
                onPressed: () async {
                  if (_isEditing) {
                    // Delete functionality when in edit mode
                    final normalizedDate = _normalizeDate(selectedDate);
                    final outfitsForSelectedDate = outfitsPerDay[normalizedDate] ?? [];

                    if (outfitsForSelectedDate.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Outfit'),
                          content: const Text('Are you sure you want to delete this outfit?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final normalizedDate = _normalizeDate(selectedDate);
                                final outfitToDelete = outfitsPerDay[normalizedDate]![_currentOutfitIndex];

                                if (outfitToDelete.id != null) {
                                  await OutfitStorageService.deleteOutfit(outfitToDelete.id!);
                                }

                                setState(() {
                                  outfitsPerDay[normalizedDate]!.removeAt(_currentOutfitIndex);

                                  // If removed last outfit for this day, remove the date entry
                                  if (outfitsPerDay[normalizedDate]!.isEmpty) {
                                    outfitsPerDay.remove(normalizedDate);
                                  }
                                  // Adjust current index if needed
                                  else if (_currentOutfitIndex > 0 &&
                                      _currentOutfitIndex >= outfitsPerDay[normalizedDate]!.length) {
                                    _currentOutfitIndex--;
                                    _outfitController.jumpToPage(_currentOutfitIndex);
                                  }
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    }
                  } else {
                    // Add functionality when not in edit mode
                    final newPalette = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePalettePage(
                          selectedDate: selectedDate,
                        ),
                      ),
                    );

                    if (newPalette != null) {
                      setState(() {
                        DateTime outfitDate = _normalizeDate(selectedDate);
                        if (!outfitsPerDay.containsKey(outfitDate)) {
                          outfitsPerDay[outfitDate] = [];
                        }

                        // Convert Color objects to hex strings for storing
                        List<String> colorPaletteStrings = [];
                        List<Color> colorPalette = [];

                        if (newPalette['colorPalette'] != null) {
                          colorPalette = List<Color>.from(newPalette['colorPalette'] as List<dynamic>);
                          colorPaletteStrings = colorPalette
                              .map((color) => '#${color.value.toRadixString(16).substring(2)}')
                              .toList();
                        }
                        if (colorPalette.isEmpty) {
                          colorPalette = [Colors.grey]; // Default gray
                          colorPaletteStrings = ['#9E9E9E'];
                        }

                        outfitsPerDay[outfitDate]!.add(
                          Outfit(
                            name: newPalette['name'] as String,
                            date: DateTime.parse(newPalette['date'] as String),
                            clothes: Map<String, String?>.from(newPalette['clothes']),
                            accessories: (newPalette['accessories'] as List<dynamic>?)
                                ?.where((item) => item != null)
                                ?.cast<String>()
                                ?.toList() ?? [], // Filter out nulls
                            colorPalette: colorPalette, // Pass List<Color> here
                            colorPaletteStrings: colorPaletteStrings, // Pass the string representation
                          ),
                        );
                      });
                    }
                  }
                },
                child: Icon(_isEditing ? Icons.delete : Icons.add, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
        child: Column(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        selectedDate = _normalizeDate(selectedDate.subtract(const Duration(days: 1)));
                        _currentOutfitIndex = 0;
                      });
                    },
                  ),
                  GestureDetector(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = _normalizeDate(pickedDate);
                          _currentOutfitIndex = 0;
                        });
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        _getFormattedDate(selectedDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        selectedDate = _normalizeDate(selectedDate.add(const Duration(days: 1)));
                        _currentOutfitIndex = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(12),
                child: outfitCount > 0
                    ? Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _isEditing
                            ? SizedBox(
                            width: 300,
                            child:
                            TextFormField(
                              key: ValueKey('outfit-name-${outfitsForSelectedDate[_currentOutfitIndex].id}'),
                              initialValue: outfitsForSelectedDate[_currentOutfitIndex].name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (newValue) {
                                final oldName = outfitsForSelectedDate[_currentOutfitIndex].name;
                                final outfitId = outfitsForSelectedDate[_currentOutfitIndex].id;
                                print('Changing outfit name from "$oldName" to "$newValue" (ID: $outfitId)');

                                // Create a new outfit with the updated name
                                final updatedOutfit = outfitsForSelectedDate[_currentOutfitIndex].copyWith(
                                  name: newValue,
                                );

                                setState(() {
                                  outfitsPerDay[normalizedDate]![_currentOutfitIndex] = updatedOutfit;
                                });

                                // Auto-save after a brief delay to avoid saving on every keystroke
                                _debouncedSave(_currentOutfitIndex);
                              },
                              onEditingComplete: () {
                                // Still save when Enter is pressed
                                _updateOutfit(_currentOutfitIndex);
                                // Remove focus from the text field
                                FocusScope.of(context).unfocus();
                              },
                              onFieldSubmitted: (_) {
                                _updateOutfit(_currentOutfitIndex);
                              },
                            )
                        )
                            : Text(
                          outfitsForSelectedDate[_currentOutfitIndex].name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_currentOutfitIndex + 1}/${outfitsForSelectedDate.length}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      flex: 3,
                      child: PageView.builder(
                        controller: _outfitController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentOutfitIndex = index;
                          });
                        },
                        itemCount: outfitCount,
                        itemBuilder: (context, outfitIndex) {
                          final Outfit outfit = outfitsForSelectedDate[outfitIndex];
                          return Column(
                            children: [
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                  children: outfit.clothes.entries.map((entry) {
                                    return _buildClothingItem(entry.key, entry.value, outfitIndex);
                                  }).toList(),
                                ),
                              ),

                              if (outfit.accessories.isNotEmpty || _isEditing)
                                SizedBox(
                                  height: 140,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                                            child: Text(
                                              "Accessories",
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (_isEditing)
                                            IconButton(
                                              icon: const Icon(Icons.add_circle, color: Colors.grey),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => _addNewAccessory(outfitIndex),
                                            ),
                                        ],
                                      ),
                                      Expanded(
                                        child: outfit.accessories.isEmpty && !_isEditing
                                            ? const Center(
                                          child: Text(
                                            'No accessories',
                                            style: TextStyle(color: Colors.grey),
                                          ),
                                        )
                                            : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: outfit.accessories.length,
                                          itemBuilder: (context, index) {
                                            final accessoryUrl = outfit.accessories[index];
                                            return _buildAccessoryItem(accessoryUrl, outfitIndex, index);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                )
                    : const Center(
                  child: Text(
                    'No outfits for this day.\nTap + to add some',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothingItem(String category, String? imageUrl, int outfitIndex) {
    return GestureDetector(
      onTap: () => _isEditing ? _editItem(category, outfitIndex) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<String?>(
            future: imageUrl != null ? _resolveFilePath(imageUrl) : Future.value(null),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              final resolvedPath = snapshot.data;

              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: resolvedPath != null
                      ? DecorationImage(
                      image: resolvedPath.startsWith('http')
                          ? NetworkImage(resolvedPath)
                          : FileImage(File(resolvedPath)) as ImageProvider,
                      fit: BoxFit.cover)
                      : null,
                ),
                child: resolvedPath == null
                    ? _buildBrokenImagePlaceholder(category)
                    : null,
              );
            },
          ),

          // Split Overlay for Edit/Delete Actions
          if (_isEditing)
            Positioned.fill(
              child: Row(
                children: [
                  // Left Side (DELETE)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _deleteItem(category, outfitIndex),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: GestureDetector(
                      onTap: () => _editItem(category, outfitIndex),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.edit, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccessoryItem(String? accessoryUrl, int outfitIndex, int accessoryIndex) {
    return FutureBuilder<String?>(
      future: accessoryUrl != null ? _resolveFilePath(accessoryUrl) : Future.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(right: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[200],
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final resolvedPath = snapshot.data;

        return Container(
          width: 80, // Ensure consistent width
          height: 80,
          margin: const EdgeInsets.only(right: 8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            fit: StackFit.expand, // Make sure Stack takes full size
            children: [
              // IMAGE
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: resolvedPath != null
                    ? Image(
                  image: resolvedPath.startsWith('http')
                      ? NetworkImage(resolvedPath)
                      : FileImage(File(resolvedPath)) as ImageProvider,
                  fit: BoxFit.cover, // Ensure it covers full space
                )
                    : _buildBrokenImagePlaceholder("Accessory"),
              ),

              // OVERLAY FOR EDIT & DELETE
              if (_isEditing)
                Positioned.fill(
                  child: Row(
                    children: [
                      // Left Side (DELETE)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _deleteAccessory(outfitIndex, accessoryIndex),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.5),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                bottomLeft: Radius.circular(4),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.delete, color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editAccessory(outfitIndex, accessoryIndex),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(4),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.edit, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrokenImagePlaceholder(String category) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          Text(
            "NO $category",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _editItem(String category, int outfitIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(slot: category, fromCreateOutfit: true),
      ),
    );

    if (result != null) {
      final normalizedDate = _normalizeDate(selectedDate);
      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];

      // Create a new map with the updated item
      final updatedClothes = Map<String, String?>.from(currentOutfit.clothes);
      updatedClothes[category] = result['item'].imageUrl as String?;

      // Create a new outfit with the updated clothes
      final updatedOutfit = currentOutfit.copyWith(
        clothes: updatedClothes,
      );

      setState(() {
        outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
      });

      // Save the updated outfit to Hive
      await _updateOutfit(outfitIndex);
    }
  }

  void _editAccessory(int outfitIndex, int accessoryIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(slot: 'Accessories', fromCreateOutfit: true),
      ),
    );

    if (result != null) {
      final normalizedDate = _normalizeDate(selectedDate);
      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];
      final item = result['item'];
      String? newImageUrl = item.imageUrl;

      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        // Create a new list with the updated accessory
        final updatedAccessories = List<String?>.from(currentOutfit.accessories);
        updatedAccessories[accessoryIndex] = newImageUrl;

        // Create a new outfit with the updated accessories
        final updatedOutfit = currentOutfit.copyWith(
          accessories: updatedAccessories,
        );

        setState(() {
          outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
        });

        // Save the updated outfit to Hive
        await _updateOutfit(outfitIndex);
      }
    }
  }

  void _addNewAccessory(int outfitIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(slot: 'Accessories', fromCreateOutfit: true),
      ),
    );

    if (result != null) {
      final normalizedDate = _normalizeDate(selectedDate);
      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];
      String? newImageUrl = result['item'].imageUrl;

      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        // Create a new list with the added accessory
        final updatedAccessories = List<String?>.from(currentOutfit.accessories);
        updatedAccessories.add(newImageUrl);

        // Create a new outfit with the updated accessories
        final updatedOutfit = currentOutfit.copyWith(
          accessories: updatedAccessories,
        );

        setState(() {
          outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
        });

        // Save the updated outfit to Hive
        await _updateOutfit(outfitIndex);
      }
    }
  }

  void _deleteAccessory(int outfitIndex, int accessoryIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Accessory'),
        content: const Text('Are you sure you want to remove this accessory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final normalizedDate = _normalizeDate(selectedDate);
              final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];

              // Create a new list without the removed accessory
              final updatedAccessories = List<String?>.from(currentOutfit.accessories);
              updatedAccessories.removeAt(accessoryIndex);

              // Create a new outfit with the updated accessories
              final updatedOutfit = currentOutfit.copyWith(
                accessories: updatedAccessories,
              );

              setState(() {
                outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
              });

              // Save the updated outfit to Hive
              await _updateOutfit(outfitIndex);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Method to handle item deletion
  void _deleteItem(String category, int outfitIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Are you sure you want to remove this $category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final normalizedDate = _normalizeDate(selectedDate);
              final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];

              // Create a new map with the removed item
              final updatedClothes = Map<String, String?>.from(currentOutfit.clothes);
              updatedClothes[category] = null;

              // Create a new outfit with the updated clothes
              final updatedOutfit = currentOutfit.copyWith(
                clothes: updatedClothes,
              );

              setState(() {
                outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
              });

              // Save the updated outfit to Hive
              await _updateOutfit(outfitIndex);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadOutfits() async {
    try {
      final allOutfits = await OutfitStorageService.getAllOutfits();

      // Group outfits by date
      for (var outfit in allOutfits) {
        // Ensure the outfit has an ID
        if (outfit.id == null || outfit.id!.isEmpty) {
          outfit.id = const Uuid().v4();
          await OutfitStorageService.updateOutfit(outfit);
        }

        final normalizedDate = _normalizeDate(outfit.date);

        if (!outfitsPerDay.containsKey(normalizedDate)) {
          outfitsPerDay[normalizedDate] = [];
        }

        outfitsPerDay[normalizedDate]!.add(outfit);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading outfits: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOutfit(int outfitIndex) async {
    final normalizedDate = _normalizeDate(selectedDate);
    final outfit = outfitsPerDay[normalizedDate]![outfitIndex];

    print('BEFORE UPDATE - Outfit details:');
    print('  ID: ${outfit.id}');
    print('  Name: ${outfit.name}');

    try {
      // CRITICAL: Make sure we have a valid ID before updating
      if (outfit.id == null || outfit.id!.isEmpty) {
        // Generate a new ID if needed
        final newId = const Uuid().v4();
        print('Generated new ID: $newId for outfit with name: ${outfit.name}');

        // Update the outfit with the new ID
        final updatedOutfit = outfit.copyWith(id: newId);

        // Update our local state
        setState(() {
          outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
        });

        // Save as a new outfit
        await OutfitStorageService.saveOutfit(updatedOutfit);
        print('Saved outfit with new ID: $newId, Name: ${updatedOutfit.name}');
      } else {
        // We have an ID, so update the existing outfit
        print('Updating existing outfit - ID: ${outfit.id}, Name: ${outfit.name}');

        // CRITICAL: First delete the existing outfit to avoid duplicates
        await OutfitStorageService.deleteOutfit(outfit.id!);
        print('Deleted existing outfit with ID: ${outfit.id} before update');

        // Then save it again with the same ID
        await OutfitStorageService.saveOutfit(outfit);
        print('Re-saved outfit with ID: ${outfit.id}, Name: ${outfit.name}');
      }

      // Verify the update worked by loading all outfits
      final allOutfits = await OutfitStorageService.getAllOutfits();
      print('After update, total outfits: ${allOutfits.length}');

      // Check for duplicates
      final names = <String>[];
      final duplicates = <String>[];
      for (final o in allOutfits) {
        if (names.contains(o.name)) {
          duplicates.add(o.name);
        } else {
          names.add(o.name);
        }
      }

      if (duplicates.isNotEmpty) {
        print('WARNING: Found duplicate outfit names: $duplicates');
      } else {
        print('No duplicate outfit names found.');
      }

    } catch (e) {
      print('Error in _updateOutfit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating outfit: $e')),
      );
    }
  }

  void _debouncedSave(int outfitIndex) {
    // Cancel previous timer if it exists
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    // Start a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateOutfit(outfitIndex);
    });
  }

  Future<void> _saveOutfit(Outfit outfit) async {
    try {
      await OutfitStorageService.saveOutfit(outfit);

      // Update the local map
      final normalizedDate = _normalizeDate(outfit.date);
      setState(() {
        if (!outfitsPerDay.containsKey(normalizedDate)) {
          outfitsPerDay[normalizedDate] = [];
        }

        outfitsPerDay[normalizedDate]!.add(outfit);
      });
    } catch (e) {
      print('Error saving outfit: $e');
    }
  }
}

