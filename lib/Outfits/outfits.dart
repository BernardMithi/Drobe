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
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/main.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';

class OutfitsPage extends StatefulWidget {
  const OutfitsPage({Key? key}) : super(key: key);

  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> with RouteAware {
  DateTime selectedDate = DateTime.now();
  final PageController _outfitController = PageController();
  int _currentOutfitIndex = 0;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false; // Add flag to prevent double-saving
  Timer? _debounceTimer;

  // Add a TextEditingController to manage the outfit name
  final TextEditingController _outfitNameController = TextEditingController();
  // Track the current outfit ID being edited
  String? _currentEditingOutfitId;

  // Stores only Outfit objects
  final Map<DateTime, List<Outfit>> outfitsPerDay = {};

  @override
  void initState() {
    super.initState();
    _loadOutfits();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPopNext() {
    // Refresh when returning to this page.
    _loadOutfits();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _outfitController.dispose();
    _outfitNameController.dispose();
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
    final bool hasOutfits = outfitCount > 0;

    // Update the text controller when the current outfit index changes
    if (hasOutfits && _currentOutfitIndex < outfitCount) {
      final currentOutfit = outfitsForSelectedDate[_currentOutfitIndex];

      // Only update if we're showing a different outfit
      if (_currentEditingOutfitId != currentOutfit.id) {
        _outfitNameController.text = currentOutfit.name;
        _currentEditingOutfitId = currentOutfit.id;
        print('Updated text controller with outfit name: ${currentOutfit.name}, ID: ${currentOutfit.id}');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('OUTFITS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                ).then((_) {
                  // Refresh when returning from profile page
                  setState(() {});
                });
              },
              child: FutureBuilder<Map<String, String>>(
                future: AuthService().getCurrentUser(),
                builder: (context, snapshot) {
                  final userData = snapshot.data ?? {'id': '', 'name': '', 'email': ''};
                  return ProfileAvatar(
                    key: ValueKey('outfits_avatar_${DateTime.now().millisecondsSinceEpoch}'),
                    size: 42,
                    userId: userData['id'] ?? '',
                    name: userData['name'] ?? '',
                    email: userData['email'] ?? '',
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: hasOutfits ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
            children: [
              // Only show edit button if there are outfits
              if (hasOutfits)
                FloatingActionButton(
                  heroTag: 'editBtn',
                  backgroundColor: Colors.grey[300],
                  shape: const CircleBorder(),
                  onPressed: () {
                    if (_isEditing) {
                      // Save the outfit name when exiting edit mode
                      final normalizedDate = _normalizeDate(selectedDate);
                      if (outfitsPerDay.containsKey(normalizedDate) &&
                          outfitsPerDay[normalizedDate]!.isNotEmpty &&
                          _currentOutfitIndex < outfitsPerDay[normalizedDate]!.length) {

                        final currentOutfit = outfitsPerDay[normalizedDate]![_currentOutfitIndex];

                        // Only update if the name has actually changed
                        if (currentOutfit.name != _outfitNameController.text) {
                          print('Saving outfit name from "${currentOutfit.name}" to "${_outfitNameController.text}" (ID: ${currentOutfit.id})');

                          // Create a new outfit with the updated name
                          final updatedOutfit = currentOutfit.copyWith(
                            name: _outfitNameController.text,
                            id: currentOutfit.id,
                          );

                          setState(() {
                            outfitsPerDay[normalizedDate]![_currentOutfitIndex] = updatedOutfit;
                          });

                          // Save the updated outfit
                          _updateOutfit(_currentOutfitIndex);
                        }
                      }
                    }

                    setState(() {
                      _isEditing = !_isEditing;

                      // Update the text controller when entering edit mode
                      if (_isEditing && outfitCount > 0) {
                        final currentOutfit = outfitsForSelectedDate[_currentOutfitIndex];
                        _outfitNameController.text = currentOutfit.name;
                        _currentEditingOutfitId = currentOutfit.id;
                      }
                    });
                  },
                  child: Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.black),
                ),
              FloatingActionButton(
                heroTag: 'addBtn',
                backgroundColor: Colors.grey[300],
                shape: const CircleBorder(),
                onPressed: _isSaving ? null : () async {
                  if (_isEditing && hasOutfits) {
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
                                    _isEditing = false; // Exit edit mode if no outfits left
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
                    if (_isSaving) return; // Prevent multiple taps

                    setState(() {
                      _isSaving = true;
                    });

                    final result = await Navigator.push<dynamic>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePalettePage(
                          selectedDate: selectedDate,
                        ),
                      ),
                    );

                    if (result != null) {
                      try {
                        // Check if the result is an Outfit object (from CreateOutfitPage)
                        if (result is Outfit) {
                          // Save the outfit directly
                          final savedOutfit = await OutfitStorageService.saveOutfit(result);
                          print('Saved outfit with ID: ${savedOutfit.id}, Name: ${savedOutfit.name}');

                          // Set the selected date to the outfit's date
                          setState(() {
                            selectedDate = _normalizeDate(savedOutfit.date);
                            _isSaving = false;
                          });

                          // Reload outfits to show the newly added outfit
                          await _loadOutfits();
                          return;
                        }

                        // Otherwise, handle as a palette result (Map<String, dynamic>)
                        final newPalette = result as Map<String, dynamic>;

                        // Get the outfit date - either from the result or use the current selected date
                        DateTime outfitDate;
                        if (newPalette.containsKey('date') && newPalette['date'] != null) {
                          // Try to parse the date from the result
                          try {
                            outfitDate = DateTime.parse(newPalette['date'] as String);
                          } catch (e) {
                            outfitDate = _normalizeDate(selectedDate);
                          }
                        } else {
                          outfitDate = _normalizeDate(selectedDate);
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

                        // If the result contains an outfit object, use it directly
                        Outfit newOutfit;
                        if (newPalette.containsKey('outfit') && newPalette['outfit'] != null) {
                          final outfitObj = newPalette['outfit'];
                          if (outfitObj is Outfit) {
                            newOutfit = outfitObj.copyWith(
                              id: const Uuid().v4(), // Generate ID immediately
                            );
                          } else {
                            // Create the new outfit from the palette data
                            newOutfit = Outfit(
                              id: const Uuid().v4(), // Generate ID immediately
                              name: newPalette['name'] as String,
                              date: outfitDate,
                              clothes: Map<String, String?>.from(newPalette['clothes']),
                              accessories: (newPalette['accessories'] as List<dynamic>?)
                                  ?.where((item) => item != null)
                                  ?.cast<String>()
                                  ?.toList() ?? [], // Filter out nulls
                              colorPalette: colorPalette,
                              colorPaletteStrings: colorPaletteStrings,
                            );
                          }
                        } else {
                          // Create the new outfit from the palette data
                          newOutfit = Outfit(
                            id: const Uuid().v4(), // Generate ID immediately
                            name: newPalette['name'] as String,
                            date: outfitDate,
                            clothes: Map<String, String?>.from(newPalette['clothes']),
                            accessories: (newPalette['accessories'] as List<dynamic>?)
                                ?.where((item) => item != null)
                                ?.cast<String>()
                                ?.toList() ?? [], // Filter out nulls
                            colorPalette: colorPalette,
                            colorPaletteStrings: colorPaletteStrings,
                          );
                        }

                        // Save the outfit
                        await OutfitStorageService.saveOutfit(newOutfit);
                        print('Saved new outfit with ID: ${newOutfit.id}, Name: ${newOutfit.name}');

                        // Update the selected date to match the outfit's date
                        setState(() {
                          selectedDate = _normalizeDate(newOutfit.date);
                          _isSaving = false;
                        });

                        // Reload outfits to show the newly added outfit
                        await _loadOutfits();
                      } catch (e) {
                        print('Error saving outfit: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving outfit: $e')),
                        );
                        setState(() {
                          _isSaving = false;
                        });
                      }
                    } else {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                },
                child: _isSaving
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
                    : Icon(_isEditing ? Icons.delete : Icons.add, color: Colors.black),
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
                        // Exit edit mode when changing date
                        if (_isEditing) {
                          _isEditing = false;
                        }
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
                          // Exit edit mode when changing date
                          if (_isEditing) {
                            _isEditing = false;
                          }
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
                        // Exit edit mode when changing date
                        if (_isEditing) {
                          _isEditing = false;
                        }
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasOutfits
                    ? Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _isEditing
                            ? SizedBox(
                            width: 300,
                            child: TextField(
                              controller: _outfitNameController,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 6),
                                border: OutlineInputBorder(),
                              ),
                              // Remove onChanged handler to prevent continuous updates
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                // Update the outfit with the new name
                                final normalizedDate = _normalizeDate(selectedDate);
                                final currentOutfit = outfitsPerDay[normalizedDate]![_currentOutfitIndex];
                                final outfitId = _currentEditingOutfitId;

                                // Only update if the name has actually changed
                                if (currentOutfit.name != _outfitNameController.text) {
                                  print('Updating outfit name from "${currentOutfit.name}" to "${_outfitNameController.text}" (ID: $outfitId)');

                                  // Create a new outfit with the updated name
                                  final updatedOutfit = currentOutfit.copyWith(
                                    name: _outfitNameController.text,
                                    id: outfitId,
                                  );

                                  setState(() {
                                    outfitsPerDay[normalizedDate]![_currentOutfitIndex] = updatedOutfit;
                                  });

                                  // Save the updated outfit
                                  _updateOutfit(_currentOutfitIndex);
                                }

                                // Remove focus from the text field
                                FocusScope.of(context).unfocus();
                              },
                              onSubmitted: (_) {
                                // This is called when the user presses the "done" button on the keyboard
                                final normalizedDate = _normalizeDate(selectedDate);
                                final currentOutfit = outfitsPerDay[normalizedDate]![_currentOutfitIndex];
                                final outfitId = _currentEditingOutfitId;

                                // Only update if the name has actually changed
                                if (currentOutfit.name != _outfitNameController.text) {
                                  print('Updating outfit name from "${currentOutfit.name}" to "${_outfitNameController.text}" (ID: $outfitId)');

                                  // Create a new outfit with the updated name
                                  final updatedOutfit = currentOutfit.copyWith(
                                    name: _outfitNameController.text,
                                    id: outfitId,
                                  );

                                  setState(() {
                                    outfitsPerDay[normalizedDate]![_currentOutfitIndex] = updatedOutfit;
                                  });

                                  // Save the updated outfit
                                  _updateOutfit(_currentOutfitIndex);
                                }
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

                            // Update the text controller when changing pages
                            if (outfitsForSelectedDate.isNotEmpty) {
                              final currentOutfit = outfitsForSelectedDate[index];
                              _outfitNameController.text = currentOutfit.name;
                              _currentEditingOutfitId = currentOutfit.id;
                            }
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
                                  children: [
                                    // Always show these four standard clothing categories, regardless of whether they exist in the outfit
                                    _buildClothingItem('LAYER', outfit.clothes['LAYER'], outfitIndex),
                                    _buildClothingItem('SHIRT', outfit.clothes['SHIRT'], outfitIndex),
                                    _buildClothingItem('BOTTOMS', outfit.clothes['BOTTOMS'], outfitIndex),
                                    _buildClothingItem('SHOES', outfit.clothes['SHOES'], outfitIndex),
                                  ],
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

  // Modify the _buildClothingItem function to allow adding items to empty slots when in edit mode

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
                  border: Border.all(color: Colors.grey.shade300),
                  image: resolvedPath != null
                      ? DecorationImage(
                      image: resolvedPath.startsWith('http')
                          ? NetworkImage(resolvedPath)
                          : FileImage(File(resolvedPath)) as ImageProvider,
                      fit: BoxFit.cover)
                      : null,
                ),
                child: resolvedPath == null
                    ? _isEditing
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.grey[600], size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "ADD $category",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : _buildBrokenImagePlaceholder(category)
                    : null,
              );
            },
          ),

          // Split Overlay for Edit/Delete Actions - Only show for items that exist
          if (_isEditing && imageUrl != null)
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

  // In the _editItem method, add null checks to safely handle the result
// In the _editItem method, modify the code to properly handle the result from ProductDetailsPage
// Replace the existing _editItem method with this updated version:

  void _editItem(String category, int outfitIndex) async {
    try {
      print('Starting _editItem for category: $category, outfitIndex: $outfitIndex');

      // First, check if the date and outfit exist
      final normalizedDate = _normalizeDate(selectedDate);
      if (!outfitsPerDay.containsKey(normalizedDate) ||
          outfitsPerDay[normalizedDate] == null ||
          outfitsPerDay[normalizedDate]!.isEmpty ||
          outfitIndex >= outfitsPerDay[normalizedDate]!.length) {
        print('Error: Invalid outfit data - Date: $normalizedDate, Index: $outfitIndex');
        return;
      }

      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];
      print('Current outfit: ${currentOutfit.name}, ID: ${currentOutfit.id}');

      final result = await Navigator.push<Map<String, dynamic>?>(
        context,
        MaterialPageRoute(
          builder: (_) => ItemSelectionPage(slot: category, fromCreateOutfit: true),
        ),
      );

      print('Result from ItemSelectionPage: $result');

      if (result == null) {
        print('User cancelled selection');
        return;
      }

      if (!result.containsKey('item')) {
        print('Result does not contain item key');
        return;
      }

      final item = result['item'];
      print('Item from result: $item (${item.runtimeType})');

      if (item == null) {
        print('Item is null');
        return;
      }

      // Initialize newImageUrl as null
      String? newImageUrl;

      // Handle different possible structures of the item
      if (item is Map<String, dynamic>) {
        // If item is a Map, access imageUrl as a key
        newImageUrl = item['imageUrl'] as String?;
        print('Item is a Map, imageUrl: $newImageUrl');
      } else if (item is Item) {
        // If item is an Item object, access imageUrl as a property
        newImageUrl = item.imageUrl;
        print('Item is an Item object, imageUrl: $newImageUrl');
      } else {
        // If item is some other object, try to access imageUrl dynamically
        try {
          // Use dynamic access with null safety
          final dynamic dynamicItem = item;
          newImageUrl = dynamicItem?.imageUrl;
          print('Item is a dynamic object, imageUrl: $newImageUrl');
        } catch (e) {
          print('Error accessing imageUrl from dynamic object: $e');
        }
      }

      print('Final newImageUrl: $newImageUrl');

      // Safely update the outfit with null checks
      if (currentOutfit.clothes != null && newImageUrl != null) {
        // Create a new map with the updated item
        final updatedClothes = Map<String, String?>.from(currentOutfit.clothes);
        updatedClothes[category] = newImageUrl;

        // Create a new outfit with the updated clothes
        final updatedOutfit = currentOutfit.copyWith(
          clothes: updatedClothes,
        );

        // Save the updated outfit to Hive BEFORE updating the state
        // This ensures the data is persisted even if the state update fails
        try {
          await OutfitStorageService.updateOutfit(updatedOutfit);
          print('Successfully saved updated outfit to storage');

          // Now update the state if the widget is still mounted
          if (mounted) {
            setState(() {
              outfitsPerDay[normalizedDate]![outfitIndex] = updatedOutfit;
            });
            print('Successfully updated state with new item');
          }
        } catch (e) {
          print('Error saving outfit: $e');
          // Show error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating outfit: $e')),
            );
          }
        }
      } else {
        print('Error: currentOutfit.clothes is null or newImageUrl is null');
        if (currentOutfit.clothes == null) {
          print('currentOutfit.clothes is null');
        }
        if (newImageUrl == null) {
          print('newImageUrl is null');
        }
      }
    } catch (e, stackTrace) {
      print('Error in _editItem: $e');
      print('Stack trace: $stackTrace');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating outfit: $e')),
        );
      }
    }
  }

// Replace the _editAccessory method with this updated version
  void _editAccessory(int outfitIndex, int accessoryIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(slot: 'Accessories', fromCreateOutfit: true),
      ),
    );

    if (result != null && result.containsKey('item')) {
      final normalizedDate = _normalizeDate(selectedDate);
      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];

      // Get the item from the result
      final item = result['item'];

      // Initialize newImageUrl as null
      String? newImageUrl;

      // Handle different possible structures of the item
      if (item is Map<String, dynamic>) {
        // If item is a Map, access imageUrl as a key
        newImageUrl = item['imageUrl'] as String?;
        print('Accessory: Item is a Map, imageUrl: $newImageUrl');
      } else if (item is Item) {
        // If item is an Item object, access imageUrl as a property
        newImageUrl = item.imageUrl;
        print('Accessory: Item is an Item object, imageUrl: $newImageUrl');
      } else if (item != null) {
        // If item is some other object, try to access imageUrl dynamically
        try {
          newImageUrl = (item as dynamic).imageUrl;
          print('Accessory: Item is a dynamic object, imageUrl: $newImageUrl');
        } catch (e) {
          print('Accessory: Error accessing imageUrl from dynamic object: $e');
        }
      }

      print('Accessory: Final newImageUrl: $newImageUrl');

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

// Also update the _addNewAccessory method
  void _addNewAccessory(int outfitIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemSelectionPage(slot: 'Accessories', fromCreateOutfit: true),
      ),
    );

    if (result != null && result.containsKey('item')) {
      final normalizedDate = _normalizeDate(selectedDate);
      final currentOutfit = outfitsPerDay[normalizedDate]![outfitIndex];

      // Get the item from the result
      final item = result['item'];

      // Initialize newImageUrl as null
      String? newImageUrl;

      // Handle different possible structures of the item
      if (item is Map<String, dynamic>) {
        // If item is a Map, access imageUrl as a key
        newImageUrl = item['imageUrl'] as String?;
        print('Add Accessory: Item is a Map, imageUrl: $newImageUrl');
      } else if (item is Item) {
        // If item is an Item object, access imageUrl as a property
        newImageUrl = item.imageUrl;
        print('Add Accessory: Item is an Item object, imageUrl: $newImageUrl');
      } else if (item != null) {
        // If item is some other object, try to access imageUrl dynamically
        try {
          newImageUrl = (item as dynamic).imageUrl;
          print('Add Accessory: Item is a dynamic object, imageUrl: $newImageUrl');
        } catch (e) {
          print('Add Accessory: Error accessing imageUrl from dynamic object: $e');
        }
      }

      print('Add Accessory: Final newImageUrl: $newImageUrl');

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
      // Clear the existing outfits map to prevent duplicates
      outfitsPerDay.clear();

      final allOutfits = await OutfitStorageService.getAllOutfits();
      print('Loading all outfits. Total from storage: ${allOutfits.length}');

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

      // Log the number of outfits per day for debugging
      outfitsPerDay.forEach((date, outfits) {
        print('Date: ${DateFormat('yyyy-MM-dd').format(date)}, Outfits: ${outfits.length}');
      });

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
    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    final normalizedDate = _normalizeDate(selectedDate);
    if (!outfitsPerDay.containsKey(normalizedDate) ||
        outfitIndex >= outfitsPerDay[normalizedDate]!.length) {
      print('ERROR: Invalid outfit index: $outfitIndex for date: $normalizedDate');
      setState(() {
        _isSaving = false;
      });
      return;
    }

    final outfit = outfitsPerDay[normalizedDate]![outfitIndex];

    print('UPDATING OUTFIT - Details:');
    print('  ID: ${outfit.id}');
    print('  Name: ${outfit.name}');

    try {
      // Ensure we have a valid ID
      if (outfit.id == null || outfit.id!.isEmpty) {
        final newId = const Uuid().v4();
        print('Generated new ID: $newId for outfit with name: ${outfit.name}');

        // Update the outfit with the new ID
        final updatedOutfit = outfit.copyWith(id: newId);

        // Save to storage
        await OutfitStorageService.saveOutfit(updatedOutfit);
        print('Saved outfit with new ID: $newId, Name: ${updatedOutfit.name}');
      } else {
        // We have an ID, so update the existing outfit
        print('Updating existing outfit - ID: ${outfit.id}, Name: ${outfit.name}');
        await OutfitStorageService.updateOutfit(outfit);
        print('Updated outfit with ID: ${outfit.id}, Name: ${outfit.name}');
      }

      // Reload outfits instead of refreshing the page
      await _reloadOutfits();
      setState(() {
        _isSaving = false;
      });

    } catch (e) {
      print('Error in _updateOutfit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating outfit: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Add this new method to reload outfits after updates
  Future<void> _reloadOutfits() async {
    try {
      // Clear current outfits
      outfitsPerDay.clear();

      // Reload all outfits from storage
      final allOutfits = await OutfitStorageService.getAllOutfits();
      print('After update, total outfits: ${allOutfits.length}');

      // Check for duplicates
      final idMap = <String, Outfit>{};
      final duplicateIds = <String>[];

      for (final outfit in allOutfits) {
        if (outfit.id != null) {
          if (idMap.containsKey(outfit.id)) {
            duplicateIds.add(outfit.id!);
          } else {
            idMap[outfit.id!] = outfit;
          }
        }

        // Group by date
        final normalizedDate = _normalizeDate(outfit.date);
        if (!outfitsPerDay.containsKey(normalizedDate)) {
          outfitsPerDay[normalizedDate] = [];
        }
        outfitsPerDay[normalizedDate]!.add(outfit);
      }

      if (duplicateIds.isNotEmpty) {
        print('WARNING: Found duplicate outfit IDs: $duplicateIds');
      } else {
        print('No duplicate outfit IDs found.');
      }

      // Update UI
      setState(() {});

    } catch (e) {
      print('Error reloading outfits: $e');
    }
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

