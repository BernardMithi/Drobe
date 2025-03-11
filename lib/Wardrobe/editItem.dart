import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';

class EditItemPage extends StatefulWidget {
  final int itemIndex;

  const EditItemPage({Key? key, required this.itemIndex}) : super(key: key);

  @override
  _EditItemPageState createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late Box itemsBox;
  late TextEditingController nameController;
  late TextEditingController hexController;
  String imagePath = '';
  List<int> _currentColorValues = []; // working list of color ints (palette + manual)
  List<int> _manualColorValues = [];  // track manually added colors in this session

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox');
    // Load existing item data
    final item = itemsBox.getAt(widget.itemIndex);
    nameController = TextEditingController(text: item.name);
    hexController = TextEditingController();
    imagePath = item.imagePath;
    _currentColorValues = List<int>.from(item.colors); // copy initial colors
    // Optionally, automatically extract palette from existing image to update colors in real-time
    if (imagePath.isNotEmpty) {
      _extractColorsFromImage(File(imagePath));
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    hexController.dispose();
    super.dispose();
  }

  // Launch image picker to select a new image
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imagePath = pickedFile.path;
      });
      // Automatically extract colors from the newly picked image
      _extractColorsFromImage(File(imagePath));
    }
  }

  // Use palette_generator to extract dominant colors from an image file
  Future<void> _extractColorsFromImage(File imageFile) async {
    // Show a loading indicator (optional) while palette is generating
    setState(() {
      _currentColorValues.clear();
    });
    try {
      final PaletteGenerator paletteGen = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        size: const Size(200, 200), // reduce size for faster processing if needed
        maximumColorCount: 10,      // limit number of colors to extract
      );
      // Convert Colors to their int values for storage/display
      final extractedColors = paletteGen.colors.map((Color c) => c.value).toList();
      setState(() {
        _currentColorValues = extractedColors;
        // Re-add any manual colors that were added this session (so they persist after a new image choice)
        if (_manualColorValues.isNotEmpty) {
          _currentColorValues.addAll(_manualColorValues);
        }
      });
    } catch (e) {
      // Handle errors (e.g., if image cannot be decoded)
      debugPrint('Error extracting palette: $e');
    }
  }

  // Add a new color from hex input to the palette list
  void _addHexColor() {
    String hexInput = hexController.text.trim();
    if (hexInput.isEmpty) return;
    // Allow formats like "FFAABB" or "#FFAABB"
    if (hexInput.startsWith('#')) {
      hexInput = hexInput.substring(1);
    }
    // Only proceed if valid 6-digit hex
    if (hexInput.length == 6 && int.tryParse(hexInput, radix: 16) != null) {
      final colorInt = int.parse('0xFF$hexInput'); // prepend FF for full opacity
      setState(() {
        _currentColorValues.add(colorInt);
        _manualColorValues.add(colorInt);
      });
      hexController.clear();
    } else {
      // Invalid hex string; show a snackbar or error message
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid hex code. Please enter 6 hexadecimal digits.'))
      );
    }
  }

  // Save changes to Hive and pop the page
  void _saveChanges() {
    // Update the item in Hive with new values
    final item = itemsBox.getAt(widget.itemIndex);
    item.name = nameController.text;
    item.imagePath = imagePath;
    item.colors = List<int>.from(_currentColorValues); // store colors as list of int [oai_citation_attribution:6‡stackoverflow.com](https://stackoverflow.com/questions/71559032/flutter-hive-store-color#:~:text=I%20think%20the%20easiest%20thing,value%20of%20the%20color)
    itemsBox.putAt(widget.itemIndex, item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Convert current color ints to Color objects for display
    List<Color> currentColors = _currentColorValues.map((val) => Color(val)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Item'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // If back button is pressed without saving, just pop (discard changes)
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveChanges, // Save and close
            tooltip: 'Save',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name field
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Product Name'),
            ),
            SizedBox(height: 16),
            // Display current image and a button to pick a new one
            if (imagePath.isNotEmpty)
              Image.file(File(imagePath), height: 150, width: double.infinity, fit: BoxFit.cover),
            TextButton.icon(
              icon: Icon(Icons.image),
              label: Text('Change Image'),
              onPressed: _pickImage,
            ),
            SizedBox(height: 16),
            // Color palette section
            Text('Colors:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: currentColors.map((color) {
                return Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            // Manual hex input field and add button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hexController,
                    decoration: InputDecoration(
                      labelText: 'Add Color (Hex)',
                      hintText: '#RRGGBB',
                    ),
                    maxLength: 7, // include '#' if present
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle),
                  onPressed: _addHexColor,
                  tooltip: 'Add Color',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}