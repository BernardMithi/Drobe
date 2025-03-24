import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'productDetails.dart';
import 'package:drobe/models/item.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';

class ItemSelectionPage extends StatefulWidget {
  final String? slot;
  final bool fromCreateOutfit;
  final bool autoSelect;
  final bool preloadOnly;

  const ItemSelectionPage({
    Key? key,
    this.slot,
    this.fromCreateOutfit = false,
    this.autoSelect = false,
    this.preloadOnly = false,
  }) : super(key: key);

  @override
  State<ItemSelectionPage> createState() => _ItemSelectionPageState();
}

class _ItemSelectionPageState extends State<ItemSelectionPage> {
  late Box itemsBox;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _hasHandledInitialNavigation = false;

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox');
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
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

  List<Item> get filteredItems {
    return itemsBox.values.cast<Item>().where((item) {
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

      return matchesSlot && matchesSearch;
    }).toList();
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
    final items = filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.slot ?? "").toUpperCase() + " ITEMS",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), // ✅ Correct usage
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
                // Removed background
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
              child: Text(
                'No items found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
                    if (Navigator.of(context).canPop()) {
                      Navigator.pop(context, {'item': item});
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