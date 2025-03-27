import 'package:flutter/material.dart';
import 'wardrobeCategory.dart';

class WardrobePage extends StatelessWidget {
  const WardrobePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YOUR WARDROBE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.account_circle, size: 40),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildCategoryButton(context, 'LAYERS'),
            _buildCategoryButton(context, 'SHIRTS'),
            _buildCategoryButton(context, 'BOTTOMS'),
            _buildCategoryButton(context, 'SHOES'),
            _buildCategoryButton(context, 'ACCESSORIES'),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(BuildContext context, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: OutlinedButton(
        onPressed: () {
          // Navigate to WardrobeCategoryPage with category name
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WardrobeCategoryPage(category: category),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(120),
          side: const BorderSide(color: Colors.grey),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        child: Text(
          category,
          style: const TextStyle(
            fontFamily: 'Avenir',
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}