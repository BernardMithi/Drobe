import 'package:flutter/material.dart';
import 'itemSelection.dart';
import 'createOutfit.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/models/outfit.dart';



class ProductDetailsPage extends StatelessWidget {
  final String imageUrl;
  final String productName;
  final String productDescription;
  final String? slot; // Which clothing slot (e.g., "Shirt", "Layer") is being updated
  final bool fromCreateOutfit; // true for create outfit flow; false for edit mode
  // These parameters can be passed so that the caller can rebuild its UI, if needed.
  final List<Color>? palette; // Provided when fromCreateOutfit is true.
  final List<Outfit>? savedOutfits; // Provided when fromCreateOutfit is true.

  const ProductDetailsPage({
    super.key,
    required this.imageUrl,
    required this.productName,
    required this.productDescription,
    this.slot,
    required this.fromCreateOutfit,
    this.palette,
    this.savedOutfits,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("ProductDetailsPage: fromCreateOutfit = $fromCreateOutfit");

    return Scaffold(
      appBar: AppBar(
        title: const Text('PRODUCT DETAILS', style: TextStyle(fontFamily: 'Avenir')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.account_circle, size: 40),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: MediaQuery.of(context).size.width,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                )
                    : const Icon(Icons.image, size: 100, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                productName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Avenir',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Worn twice this month',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontFamily: 'Avenir',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                productDescription,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontFamily: 'Avenir',
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create the selected product.
          final selectedItem = Item(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            imageUrl: imageUrl,
            name: productName,
            description: productDescription,
            category: 'Shirt',
            wearCount: 2,
            inLaundry: false,
          );

          // Pop with the result (convert Item to a Map before returning)
          Navigator.pop(context, {
            'item': {
              'id': selectedItem.id,
              'imageUrl': selectedItem.imageUrl,
              'name': selectedItem.name,
              'description': selectedItem.description,
              'category': selectedItem.category,
              'wearCount': selectedItem.wearCount,
              'inLaundry': selectedItem.inLaundry,
            },
            'slot': slot,
          });
        },
        backgroundColor: Colors.black26,
        shape: const CircleBorder(),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}