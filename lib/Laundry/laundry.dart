import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drobe/models/item.dart';
import 'package:hive/hive.dart';
import 'package:drobe/settings/profile.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';

class LaundryPage extends StatefulWidget {
  const LaundryPage({Key? key}) : super(key: key);

  @override
  State<LaundryPage> createState() => _LaundryPageState();
}

class _LaundryPageState extends State<LaundryPage> {
  bool _isLoading = true;
  List<Item> _laundryItems = [];
  Set<String> _selectedItems = {};
  late Box itemsBox;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserAndLoadItems();
  }

  Future<void> _getCurrentUserAndLoadItems() async {
    try {
      // Get current user ID
      final userData = await AuthService().getCurrentUser();
      _currentUserId = userData['id'] ?? '';

      if (_currentUserId.isEmpty) {
        print('Error: Unable to get current user ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Unable to get user information')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Load laundry items for the current user
      await _loadLaundryItems();
    } catch (e) {
      print('Error getting current user: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLaundryItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get the Hive box using HiveManager
      final HiveManager hiveManager = HiveManager();
      final box = await hiveManager.getBox('itemsBox');

      // Filter for items in laundry that belong to the current user
      final List<Item> laundryItems = [];
      for (var item in box.values) {
        if (item is Item &&
            item.inLaundry &&
            item.userId == _currentUserId) {
          laundryItems.add(item);
        }
      }

      setState(() {
        _laundryItems = laundryItems;
        itemsBox = box; // Store the box for later use
        _isLoading = false;
        _selectedItems.clear();
      });

      debugPrint('Loaded ${_laundryItems.length} laundry items for user $_currentUserId');
    } catch (e) {
      print('Error loading laundry items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

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

      // If the path is a relative path (like 'wardrobe_images/file.jpg')
      if (!path.isAbsolute(imagePath)) {
        final fullPath = path.join(appDir.path, imagePath);
        if (await File(fullPath).exists()) {
          return fullPath;
        }
      }

      // Try to find the file by filename
      final fileName = path.basename(imagePath);
      final List<String> possiblePaths = [
        imagePath,
        path.join(appDir.path, fileName),
        path.join(appDir.path, 'wardrobe_images', fileName),
      ];

      for (final possiblePath in possiblePaths) {
        if (await File(possiblePath).exists()) {
          return possiblePath;
        }
      }

      print('Could not resolve path for: $imagePath');
      return null;
    } catch (e) {
      print('Error resolving path: $e');
      return null;
    }
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  Future<void> _washSelectedItems() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items selected')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int updatedCount = 0;

      // Mark selected items as clean
      for (final itemId in _selectedItems) {
        // Find the item in the box
        for (final key in itemsBox.keys) {
          final item = itemsBox.get(key);
          if (item is Item &&
              item.id == itemId &&
              item.userId == _currentUserId) {
            // Mark as clean (removes from laundry)
            item.inLaundry = false;

            // Save the item back to the box
            await item.save();
            updatedCount++;
            break;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$updatedCount items marked as clean')),
      );

      // Reload the list
      await _loadLaundryItems();
    } catch (e) {
      print('Error washing items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error washing items: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _washAllItems() async {
    if (_laundryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in laundry')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      int updatedCount = 0;

      // Mark all items as clean
      for (final item in _laundryItems) {
        if (item.userId == _currentUserId) {
          // Mark as clean (removes from laundry)
          item.inLaundry = false;

          // Save the item back to the box
          await item.save();
          updatedCount++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$updatedCount items marked as clean')),
      );

      // Reload the list
      await _loadLaundryItems();
    } catch (e) {
      print('Error washing all items: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error washing all items: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LAUNDRY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    key: ValueKey('laundry_avatar_${DateTime.now().millisecondsSinceEpoch}'),
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
      body: Column(
        children: [
          // Header with item count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items in Laundry: ${_laundryItems.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Selected: ${_selectedItems.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons - moved to top for better accessibility
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedItems.isNotEmpty ? _washSelectedItems : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('WASH SELECTED (${_selectedItems.length})'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _laundryItems.isNotEmpty ? _washAllItems : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('WASH ALL'),
                  ),
                ),
              ],
            ),
          ),

          // Laundry items grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _laundryItems.isEmpty
                ? _buildEmptyState()
                : _buildLaundryGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_laundry_service, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'NO ITEMS IN LAUNDRY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Items marked for laundry will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLaundryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _laundryItems.length,
      itemBuilder: (context, index) {
        final item = _laundryItems[index];
        return _buildLaundryItemCard(item);
      },
    );
  }

  Widget _buildLaundryItemCard(Item item) {
    final isSelected = _selectedItems.contains(item.id);

    return GestureDetector(
      onTap: () => _toggleItemSelection(item.id),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.grey[400]! : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: FutureBuilder<String?>(
                future: _resolveFilePath(item.imageUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final imagePath = snapshot.data;

                  if (imagePath != null) {
                    // Image exists
                    if (imagePath.startsWith('http')) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.black, size: 20),
                              ),
                            ),
                        ],
                      );
                    } else {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.black, size: 20),
                              ),
                            ),
                        ],
                      );
                    }
                  } else {
                    // No image
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.local_laundry_service, size: 64, color: Colors.grey),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.black, size: 20),
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            ),

            // Item info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
  }
}

