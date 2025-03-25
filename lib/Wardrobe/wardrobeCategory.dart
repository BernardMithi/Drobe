import 'package:flutter/material.dart';
import 'wardrobeProductDetails.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/hiveServiceManager.dart'; // Use our service
import 'package:hive/hive.dart';
import 'addItem.dart';
import 'editItem.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class WardrobeCategoryPage extends StatefulWidget {
  final String category;

  const WardrobeCategoryPage({super.key, required this.category});

  @override
  State<WardrobeCategoryPage> createState() => _WardrobeCategoryPageState();
}

class _WardrobeCategoryPageState extends State<WardrobeCategoryPage> {
  Box? itemsBox; // Start with null
  final HiveManager _hiveManager = HiveManager(); // Use the centralized service
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBox();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  Future<void> _loadBox() async {
    try {
      itemsBox = await _hiveManager.getBox(ITEMS_BOX_NAME);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading box: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> get filteredItems {
    if (_isLoading || itemsBox == null) {
      return [];
    }

    try {
      final List<Item> items = [];

      for (var value in itemsBox!.values) {
        if (value is Item) {
          final item = value;
          if (item.category == widget.category &&
              (_searchText.isEmpty ||
                  item.name.toLowerCase().contains(_searchText.toLowerCase()) ||
                  item.description.toLowerCase().contains(_searchText.toLowerCase()))) {
            items.add(item);
          }
        }
      }

      return items;
    } catch (e) {
      print('Error filtering items: $e');
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
      return;
    }

    setState(() {
      try {
        // Find the key for this item
        final key = itemsBox?.keys.firstWhere(
              (k) => itemsBox?.get(k) is Item && (itemsBox?.get(k) as Item).id == selectedItem.id,
          orElse: () => null,
        );

        if (key != null) {
          itemsBox?.put(key, result);
        }
      } catch (e) {
        print('Error updating item: $e');
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
      setState(() {}); // Refresh the list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.toUpperCase(),
            style: const TextStyle(fontFamily: 'Avenir')),
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
              itemBuilder: (context, index) {
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