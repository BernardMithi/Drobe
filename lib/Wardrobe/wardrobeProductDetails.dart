import 'package:flutter/material.dart';
import 'editItem.dart';
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:drobe/models/item.dart';
import 'package:drobe/Wardrobe/editItem.dart';

class ProductDetailsPage extends StatefulWidget {
  final int itemIndex; // Index to retrieve the item from Hive
  const ProductDetailsPage({Key? key, required this.itemIndex}) : super(key: key);

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late Box itemsBox;
  late Item item;

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox'); // Ensure this box is opened elsewhere
    _loadItem();
  }

  void _loadItem() {
    item = itemsBox.getAt(widget.itemIndex) as Item;
  }

  void _markAsWorn() {
    setState(() {
      item.markAsWorn();
    });
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

  // Refresh the item after editing
  void _reloadItemFromHive() {
    setState(() {
      _loadItem();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Color> colorPalette = item.colors?.map((val) => Color(val)).toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditItemPage(itemIndex: widget.itemIndex),
                ),
              );
              _reloadItemFromHive();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display product image or a placeholder
            if (item.imageUrl.isNotEmpty && File(item.imageUrl).existsSync())
              Image.file(File(item.imageUrl), height: 200, width: double.infinity, fit: BoxFit.cover)
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              ),
            const SizedBox(height: 16),

            // Item Name
            Text(
              item.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),
            // Wear Status Display
            Text(
              "Status: ${item.wearStatus}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),
            // Description
            Text(item.description),

            const SizedBox(height: 16),
            // Color Palette Display
            const Text('Color Palette:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: colorPalette.map((color) {
                return Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            // "Mark as Worn" Button
            ElevatedButton.icon(
              onPressed: _markAsWorn,
              icon: const Icon(Icons.check),
              label: const Text("Mark as Worn"),
            ),

            const SizedBox(height: 8),
            // "Move to Laundry" Button
            ElevatedButton.icon(
              onPressed: _moveToLaundry,
              icon: const Icon(Icons.local_laundry_service),
              label: const Text("Move to Laundry"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            ),

            const SizedBox(height: 8),
            // "Mark as Clean" Button
            ElevatedButton.icon(
              onPressed: _markAsClean,
              icon: const Icon(Icons.cleaning_services),
              label: const Text("Mark as Clean"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            ),
          ],
        ),
      ),
    );
  }
}