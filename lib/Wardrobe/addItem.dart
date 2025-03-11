import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:drobe/models/item.dart';

class AddItemPage extends StatefulWidget {
  final String category;

  const AddItemPage({super.key, required this.category});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  File? _selectedImage;
  late Box itemsBox;
  List<int> _selectedColors = []; // Stores selected colors (Max 3)

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox'); // Ensure Hive is initialized
  }

  /// **Pick an Image & Extract Colors**
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      setState(() {
        _selectedImage = imageFile;
      });

      // Extract dominant colors from the image (Limit 3)
      await _extractColorsFromImage(imageFile);
    }
  }

  /// **Extract 3 Main Colors from Image**
  Future<void> _extractColorsFromImage(File imageFile) async {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      FileImage(imageFile),
      size: const Size(200, 200),
      maximumColorCount: 3, // ✅ Limit to 3 main colors
    );

    setState(() {
      _selectedColors = paletteGenerator.paletteColors
          .take(3) // ✅ Keep only the first 3 colors
          .map((color) => color.color.value)
          .toList();
    });
  }

  /// **Open macOS-style Color Picker**
  Future<void> _openColorPicker() async {
    if (_selectedColors.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only select up to 3 colors.")),
      );
      return;
    }

    Color? selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) => _MacOSColorPickerDialog(),
    );

    if (selectedColor != null && !_selectedColors.contains(selectedColor.value)) {
      setState(() {
        _selectedColors.add(selectedColor.value);
        if (_selectedColors.length > 3) {
          _selectedColors = _selectedColors.take(3).toList();
        }
      });
    }
  }

  /// **Save New Item to Hive**
  void _saveItem() {
    if (_nameController.text.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a name and image.")),
      );
      return;
    }

    final newItem = Item(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imageUrl: _selectedImage!.path, // Save image path
      name: _nameController.text,
      description: _descriptionController.text,
      category: widget.category,
      colors: _selectedColors, // Store up to 3 selected colors
      wearCount: 0, // Default wear count (Not Worn)
      inLaundry: false, // Default status
    );

    itemsBox.add(newItem); // Save to Hive
    Navigator.pop(context, newItem); // Return item to WardrobeCategoryPage
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Item"),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.account_circle, size: 40),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // **Image Picker (Square)**
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: 200, // **Make it a Square**
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage == null
                    ? const Icon(Icons.image, size: 80, color: Colors.grey)
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // **Name Input Field**
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "NAME",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // **Description Input Field**
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "DESCRIPTION",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // **Color Picker Buttons**
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _openColorPicker,
                  child: const Text("Select Colors"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _selectedImage != null ? () => _extractColorsFromImage(_selectedImage!) : null,
                  child: const Text("Generate Colors"),
                ),
              ],
            ),

            // **Display Selected Colors**
            if (_selectedColors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedColors.map((colorInt) {
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(colorInt),
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),

      // **Floating Save Button (Grey)**
      floatingActionButton: FloatingActionButton(
        onPressed: _saveItem,
        backgroundColor: Colors.grey[600], // **Grey color**
        child: const Icon(Icons.check, color: Colors.white), // **Check icon for save**
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // **Bottom right**
    );
  }
}

/// **MacOS-Inspired Color Picker Dialog**
class _MacOSColorPickerDialog extends StatefulWidget {
  @override
  State<_MacOSColorPickerDialog> createState() => _MacOSColorPickerDialogState();
}

class _MacOSColorPickerDialogState extends State<_MacOSColorPickerDialog> {
  Color selectedColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pick a Color"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // **Custom Color Picker**
          ColorPicker(
            pickerColor: selectedColor,
            enableAlpha: false,
            showLabel: false,
            onColorChanged: (color) {
              setState(() {
                selectedColor = color;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, selectedColor),
          child: const Text("Select"),
        ),
      ],
    );
  }
}