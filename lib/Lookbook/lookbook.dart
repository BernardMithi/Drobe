import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drobe/models/lookbookItem.dart';
import 'package:drobe/services/lookbookStorage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:drobe/settings/profile.dart';
import 'lookbookDetail.dart';
import 'addLookbookItem.dart';
import 'package:intl/intl.dart';
import 'package:drobe/main.dart';
import 'package:drobe/settings/profileAvatar.dart';
import 'package:drobe/auth/authService.dart';

class LookbookPage extends StatefulWidget {
  const LookbookPage({Key? key}) : super(key: key);

  @override
  State<LookbookPage> createState() => _LookbookPageState();
}

class _LookbookPageState extends State<LookbookPage> with RouteAware {
  bool _isLoading = true;
  List<LookbookItem> _lookbookItems = [];
  List<LookbookItem> _filteredItems = [];
  List<String> _allTags = [];
  String? _selectedTag;
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newestFirst;

  @override
  void initState() {
    super.initState();
    _loadLookbookItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Refresh when returning to this page
    _loadLookbookItems();
    super.didPopNext();
  }

  Future<void> _loadLookbookItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Initialize the service first
      await LookbookStorageService.init();

      // Load all items
      final items = await LookbookStorageService.getAllItems();

      // Load all tags
      final tags = await LookbookStorageService.getAllTags();

      setState(() {
        _lookbookItems = items;
        _filteredItems = List.from(items);
        _allTags = tags;
        _applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading lookbook items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFiltersAndSort() {
    // First, apply tag filter if selected
    var filtered = _lookbookItems;

    if (_selectedTag != null) {
      filtered = filtered.where((item) =>
          item.tags.contains(_selectedTag!.toLowerCase())).toList();
    }

    // Then, apply search filter if any
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) =>
      item.name.toLowerCase().contains(query) ||
          (item.notes?.toLowerCase().contains(query) ?? false) ||
          item.tags.any((tag) => tag.toLowerCase().contains(query))).toList();
    }

    // Finally, sort the results
    switch (_sortOption) {
      case SortOption.newestFirst:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.oldestFirst:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.alphabetical:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    setState(() {
      _filteredItems = filtered;
    });
  }

  Future<String?> _resolveFilePath(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

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

      // Try to find the file in various directories
      final List<String> possiblePaths = [
        imagePath,
        path.join(appDir.path, fileName),
        path.join(appDir.path, 'wardrobe_images', fileName),
        path.join(appDir.path, 'lookbook_images', fileName),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOOKBOOK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Use Navigator.push().then() to ensure refresh happens when returning
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddLookbookItemPage()),
          ).then((_) {
            // Always refresh when returning from add screen
            _loadLookbookItems();
          });
        },
        backgroundColor: Colors.grey[300],
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          _buildTagsRow(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                ? _buildEmptyState()
                : _buildGridView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search inspirations',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFiltersAndSort();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption option) {
              setState(() {
                _sortOption = option;
                _applyFiltersAndSort();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.newestFirst,
                child: Text('Newest First'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.oldestFirst,
                child: Text('Oldest First'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.alphabetical,
                child: Text('Alphabetical'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsRow() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // "All" tag
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedTag == null,
              backgroundColor: Colors.grey[300],
              selectedColor: Colors.grey[400],
              onSelected: (selected) {
                setState(() {
                  _selectedTag = null;
                  _applyFiltersAndSort();
                });
              },
            ),
          ),
          // Tag filters
          ..._allTags.map((tag) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(tag),
              selected: _selectedTag == tag,
              backgroundColor: Colors.grey[300],
              selectedColor: Colors.grey[400],
              onSelected: (selected) {
                setState(() {
                  _selectedTag = selected ? tag : null;
                  _applyFiltersAndSort();
                });
              },
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty || _selectedTag != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No matching inspirations found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedTag = null;
                  _applyFiltersAndSort();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
              ),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Your lookbook is empty',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add outfit inspirations to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildLookbookItemCard(item);
      },
    );
  }

  Widget _buildLookbookItemCard(LookbookItem item) {
    return GestureDetector(
      onTap: () {
        // Use Navigator.push().then() to ensure refresh happens when returning
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LookbookDetailPage(id: item.id!),
          ),
        ).then((_) {
          // Always refresh when returning from detail screen
          _loadLookbookItems();
        });
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
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
                      return Image.network(
                        imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        ),
                      );
                    } else {
                      return Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                        ),
                      );
                    }
                  } else {
                    // No image
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.style, size: 64, color: Colors.grey),
                      ),
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
                mainAxisSize: MainAxisSize.min, // Use minimum vertical space
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
                    DateFormat('MMM d, yyyy').format(item.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (item.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 20, // Fixed height for tags
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: item.tags.take(2).map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[800],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SortOption {
  newestFirst,
  oldestFirst,
  alphabetical,
}

