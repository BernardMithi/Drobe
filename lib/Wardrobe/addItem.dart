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
  final TextEditingController _imageUrlController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;

  late Box itemsBox;
  List<int> _selectedColors = []; // Stores selected colors (Max 3)

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox'); // Ensure Hive is initialized
  }

  /// Show Bottom Sheet to Choose Image Source
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      // Rounded corners at the top
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      // Optional: you can also specify backgroundColor if desired
      builder: (context) {
        return SafeArea(
          // Use a Column with a small drag handle at the top
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle for a more polished look
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // The original list of options
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Enter URL'),
                onTap: () {
                  Navigator.pop(context);
                  _showEnterUrlDialog();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Pick Image from Camera or Gallery
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      setState(() {
        _selectedImage = imageFile;
        _imageUrl = null; // Clear any previously entered URL
      });

      // Extract colors from image
      await _extractColorsFromImage(imageFile);
    }
  }

  /// Show Dialog to Enter Image URL
  Future<void> _showEnterUrlDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Image URL"),
          content: TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(hintText: "https://example.com/image.jpg"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _imageUrl = _imageUrlController.text.trim();
                  _selectedImage = null; // Clear any previously selected file
                });
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  /// Extract 3 Main Colors from Image
  Future<void> _extractColorsFromImage(File imageFile) async {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      FileImage(imageFile),
      size: const Size(200, 200),
      maximumColorCount: 3, // Limit to 3 main colors
    );

    setState(() {
      _selectedColors = paletteGenerator.paletteColors
          .take(3)
          .map((color) => color.color.value)
          .toList();
    });
  }

  /// Open Color Picker
  Future<void> _openColorPicker() async {
    if (_selectedColors.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only select up to 5 colors.")),
      );
      return;
    }

    Color selectedColor = Colors.black;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Pick a Color"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorPicker(
                pickerColor: selectedColor,
                enableAlpha: false,
                showLabel: false,
                onColorChanged: (color) {
                  selectedColor = color;
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
              onPressed: () {
                if (!_selectedColors.contains(selectedColor.value)) {
                  setState(() {
                    _selectedColors.add(selectedColor.value);
                    if (_selectedColors.length > 5) {
                      _selectedColors = _selectedColors.take(5).toList();
                    }
                  });
                }
                Navigator.pop(context);
              },
              child: const Text("Select"),
            ),
          ],
        );
      },
    );
  }

  /// Save New Item to Hive
  void _saveItem() {
    if (_nameController.text.isEmpty || (_selectedImage == null && (_imageUrl == null || _imageUrl!.isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a name and image.")),
      );
      return;
    }

    final newItem = Item(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imageUrl: _selectedImage != null ? _selectedImage!.path : _imageUrl!,
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
            // Image Picker (Tap to Choose)
            GestureDetector(
              onTap: _showImageSourceOptions,
              child: Container(
                height: 400,
                width: 400,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                )
                    : _imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(_imageUrl!, fit: BoxFit.cover),
                )
                    : const Icon(Icons.image, size: 100, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 20),

            // Name Input Field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "NAME",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input Field
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "DESCRIPTION",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            // Color Picker Buttons
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

            // Display Selected Colors
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

      // Floating Save Button
      floatingActionButton: FloatingActionButton(
        onPressed: _saveItem,
        backgroundColor: Colors.grey[600],
        child: const Icon(Icons.check, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}