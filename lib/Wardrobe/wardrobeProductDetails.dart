import 'package:flutter/material.dart';
import 'editItem.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:drobe/models/item.dart';
import 'package:path_provider/path_provider.dart';

class ProductDetailsPage extends StatefulWidget {
  final Item item;
  const ProductDetailsPage({Key? key, required this.item}) : super(key: key);

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late Box itemsBox;
  late Item item;
  late List<int> _selectedColors;
  String? _fullImagePath;

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox');
    item = widget.item;
    _selectedColors = item.colors ?? [];

    // Get the full image path
    _getFullImagePath();
  }

  // Add this method to get the full path
  Future<void> _getFullImagePath() async {
    if (item.imageUrl.isNotEmpty && !item.imageUrl.startsWith("http")) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fullPath = "${directory.path}/${item.imageUrl}";
        final file = File(fullPath);

        if (file.existsSync()) {
          setState(() {
            _fullImagePath = fullPath;
          });
        }
      } catch (e) {
        print("Error getting full path: $e");
      }
    }
  }

  void _moveToLaundry() {
    setState(() {
      item.moveToLaundry();
    });
  }

  void _markAsClean() {
    setState(() {
      item.markAsClean();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if the item is an accessory
    bool isAccessory = item.category.toLowerCase() == "accessories";

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              int itemIndex = itemsBox.values.toList().indexWhere((i) => i.id == item.id);
              if (itemIndex != -1) {
                final result = await Navigator.push<dynamic>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditItemPage(itemIndex: itemIndex),
                  ),
                );

                if (result == true) {
                  // ✅ Navigate back to `wardrobeCategory.dart` if item was deleted
                  if (mounted) {
                    Navigator.pop(context);
                  }
                } else if (result is Item) {
                  setState(() {
                    item = result;
                    _selectedColors = List<int>.from(item.colors ?? []);

                    // Reset the full path and recalculate it
                    _fullImagePath = null;
                    _getFullImagePath();
                  });
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                height: 400,
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Builder(
                  builder: (context) {
                    if (item.imageUrl.isEmpty) {
                      return const Icon(Icons.image, size: 100, color: Colors.grey);
                    }

                    if (item.imageUrl.startsWith("http")) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print("Error loading network image: $error");
                            return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      );
                    } else if (_fullImagePath != null) {
                      // Use the full path if available
                      final file = File(_fullImagePath!);
                      try {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print("Error loading file image with full path: $error");
                              return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                            },
                          ),
                        );
                      } catch (e) {
                        print("Error showing image with full path: $e");
                        return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                      }
                    } else {
                      // Fallback to trying the direct path
                      try {
                        final file = File(item.imageUrl);
                        if (file.existsSync()) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print("Error loading file image: $error");
                                return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
                              },
                            ),
                          );
                        }
                      } catch (e) {
                        print("Error checking file: $e");
                      }
                      return const Icon(Icons.image_not_supported, size: 100, color: Colors.grey);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            // Only show status if the item is NOT an accessory
            if (!isAccessory)
              Text(
                item.inLaundry ? "Status: In Laundry" : "Status: Clean",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _selectedColors.map((colorInt) {
                return Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(colorInt),
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(40),
                  ),
                );
              }).toList(),
            ),

            // Only show laundry buttons if the item is NOT an accessory
            if (!isAccessory) ...[
              Expanded(child: Container()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 42.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _moveToLaundry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("IN LAUNDRY"),
                    ),
                    ElevatedButton(
                      onPressed: _markAsClean,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("MARK AS CLEAN"),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}