import 'package:flutter/material.dart';
import 'wardrobeProductDetails.dart';
import 'package:drobe/models/item.dart';
import 'package:hive/hive.dart';
import 'addItem.dart';  // ✅ Ensure this matches your actual file name

class WardrobeCategoryPage extends StatefulWidget {
  final String category;

  const WardrobeCategoryPage({super.key, required this.category});

  @override
  State<WardrobeCategoryPage> createState() => _WardrobeCategoryPageState();
}

class _WardrobeCategoryPageState extends State<WardrobeCategoryPage> {
  late Box itemsBox;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox'); // Ensure Hive box is initialized
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Item> get filteredItems {
    final List<Item> items = itemsBox.values.cast<Item>().where((item) {
      return item.category == widget.category;
    }).toList();

    if (_searchText.isEmpty) return items;
    final lower = _searchText.toLowerCase();

    return items.where((item) {
      return item.name.toLowerCase().contains(lower) ||
          item.wearStatus.toLowerCase().contains(lower);
    }).toList();
  }

  Future<void> _selectItem(int itemIndex) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(itemIndex: itemIndex),
      ),
    );

    if (result != null && result['item'] != null) {
      setState(() {
        itemsBox.putAt(itemIndex, result['item']); // Persist edits
      });
    }
  }

  /// **Navigate to AddItemPage to create a new clothing item**
  Future<void> _addNewItem() async {
    final newItem = await Navigator.push<Item>(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemPage(category: widget.category),
      ),
    );

    if (newItem != null) {
      setState(() {
        itemsBox.add(newItem); // ✅ Add item to Hive
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.toUpperCase(), style: const TextStyle(fontFamily: 'Avenir')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'SEARCH',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              itemCount: filteredItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return GestureDetector(
                  onTap: () => _selectItem(index),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.network(item.imageUrl, fit: BoxFit.cover, width: double.infinity),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(item.wearStatus, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        onPressed: _addNewItem, // ✅ Opens AddItemPage
        backgroundColor: Colors.black87,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }
}