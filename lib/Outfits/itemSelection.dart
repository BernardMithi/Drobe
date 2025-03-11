import 'package:flutter/material.dart';
import 'productDetails.dart';

class ItemSelectionPage extends StatefulWidget {
  final String? slot; // Indicates which clothing slot this selection is for
  final bool fromCreateOutfit; // true for create outfit flow; false for edit mode

  const ItemSelectionPage({
    Key? key,
    this.slot,
    this.fromCreateOutfit = false,
  }) : super(key: key);

  @override
  State<ItemSelectionPage> createState() => _ItemSelectionPageState();
}

class _ItemSelectionPageState extends State<ItemSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  final List<Item> allItems = [
    Item(
      imageUrl: 'https://www.charitycomms.org.uk/wp-content/uploads/2019/02/placeholder-image-square.jpg',
      name: 'LEVI COAT',
      wearStatus: 'Worn twice this month',
      description: 'This Levi coat is made from premium materials, perfect for winter.',
    ),
    Item(
      imageUrl: 'https://www.charitycomms.org.uk/wp-content/uploads/2019/02/placeholder-image-square.jpg',
      name: 'LOUIS VUITTON COAT',
      wearStatus: 'Not worn this month',
      description: 'Elegant Louis Vuitton coat, ideal for formal occasions.',
    ),
    Item(
      imageUrl: 'https://www.charitycomms.org.uk/wp-content/uploads/2019/02/placeholder-image-square.jpg',
      name: 'ZARA JACKET',
      wearStatus: 'Worn once this month',
      description: 'A stylish Zara jacket, lightweight and fashionable.',
    ),
    Item(
      imageUrl: 'https://www.charitycomms.org.uk/wp-content/uploads/2019/02/placeholder-image-square.jpg',
      name: 'UNIQLO SWEATER',
      wearStatus: 'Worn 3 times this month',
      description: 'A cozy Uniqlo sweater for casual days.',
    ),
  ];

  List<Item> get filteredItems {
    if (_searchText.isEmpty) return allItems;
    final lower = _searchText.toLowerCase();
    return allItems.where((item) {
      return item.name.toLowerCase().contains(lower) ||
          item.wearStatus.toLowerCase().contains(lower);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
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

  Future<void> _selectItem(Item item) async {
    // Navigate to ProductDetailsPage and await the result.
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          imageUrl: item.imageUrl,
          productName: item.name,
          productDescription: item.description,
          slot: widget.slot,
          fromCreateOutfit: widget.fromCreateOutfit,
        ),
      ),
    );
    if (result != null) {
      // Pop with the result to return to the previous page.
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SELECT ITEM', style: TextStyle(fontFamily: 'Avenir')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 40),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'SEARCH',
                hintStyle: TextStyle(fontFamily: 'Avenir', fontSize: 15, color: Colors.grey),
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
            ),
          ),
          // Items Grid.
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
                  onTap: () => _selectItem(item),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontFamily: 'Avenir', fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.wearStatus,
                                style: const TextStyle(fontFamily: 'Avenir', fontSize: 12, color: Colors.grey),
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

class Item {
  final String imageUrl;
  final String name;
  final String wearStatus;
  final String description;

  Item({
    required this.imageUrl,
    required this.name,
    required this.wearStatus,
    required this.description,
  });
}