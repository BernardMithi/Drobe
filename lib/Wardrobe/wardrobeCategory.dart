import 'package:flutter/material.dart';
import 'wardrobeProductDetails.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart'; // Use our service
import 'package:hive/hive.dart';
import 'addItem.dart';
import 'editItem.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:drobe/auth/authService.dart';

class WardrobeCategoryPage extends StatefulWidget {
  final String category;

  const WardrobeCategoryPage({super.key, required this.category});

  @override
  State<WardrobeCategoryPage> createState() => _WardrobeCategoryPageState();
}

class _WardrobeCategoryPageState extends State<WardrobeCategoryPage> {
  final HiveManager _hiveManager = HiveManager(); // Use the centralized service
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isLoading = true;
  List<Item> _items = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserItems();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  Future<void> _loadUserItems() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Get the current user ID
      final authService = AuthService();
      await authService.ensureInitialized();
      final userData = await authService.getCurrentUser();
      _currentUserId = userData['id'];

      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('Warning: No current user ID available in wardrobeCategory');
        if (mounted) {
          setState(() {
            _items = [];
            _isLoading = false;
          });

          // Show a message to the user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to view your items'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Get items for the current user and category
      final box = await _hiveManager.getBox('itemsBox');
      final List<Item> allItems = [];

      // Iterate through all items and filter by user ID and category
      for (var item in box.values) {
        if (item is Item) {
          // ONLY include items that explicitly match the current user ID
          if (item.userId == _currentUserId && item.category == widget.category) {
            allItems.add(item);
          }
        }
      }

      // Debug logging
      debugPrint('Loaded ${allItems.length} items for user $_currentUserId in category ${widget.category}');

      if (mounted) {
        setState(() {
          _items = allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user items: $e');
      if (mounted) {
        setState(() {
          _items = [];
          _isLoading = false;
        });

        // Show an error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading items: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> get filteredItems {
    if (_isLoading || _items.isEmpty) {
      return [];
    }

    try {
      if (_searchText.isEmpty) {
        return _items;
      }

      return _items.where((item) =>
      item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchText.toLowerCase())
      ).toList();
    } catch (e) {
      debugPrint('Error filtering items: $e');
      return [];
    }
  }

  Future<void> _selectItem(Item selectedItem) async {
    final result = await Navigator.push<Item?>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(item: selectedItem),
      ),
    );

    if (result == null) { // Item was deleted
      setState(() {}); // Refresh UI immediately after deletion
      _loadUserItems(); // Reload items from storage
      return;
    }

    // Item was updated
    setState(() {
      final index = _items.indexWhere((item) => item.id == result.id);
      if (index >= 0) {
        _items[index] = result;
      }
    });
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

  Future<void> _addNewItem() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemPage(category: widget.category),
      ),
    );

    if (result != null) {
      _loadUserItems(); // Reload items to include the new one
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.category.toUpperCase(),
            style: const TextStyle(
                fontFamily: 'Avenir',
                fontSize: 18,
                fontWeight: FontWeight.bold
            )
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'SEARCH ${widget.category}...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "LET'S GET SOME ${widget.category} IN HERE",
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (BuildContext context, int index) {
                final item = filteredItems[index];
                return GestureDetector(
                  onTap: () => _selectItem(item),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: _buildImage(item.imageUrl),
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
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

