import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' show min;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/removeBackground.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:drobe/utils/image_utils.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle for a polished look
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
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
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageUrl = null;
      });
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
              onPressed: () async {
                final url = _imageUrlController.text.trim();
                Navigator.pop(context);
                await _processImageFromUrl(url);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  /// Download image from URL, remove background, and update state.
  /// Process image from URL with proper error handling and directory creation
  Future<void> _processImageFromUrl(String url) async {
    if (!mounted) return;

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading image..."))
    );

    try {
      // Download the image
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // First save to a temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_download.png');
        await tempFile.writeAsBytes(response.bodyBytes);

        // Show background removal in progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Removing background..."))
          );
        }

        // Remove background from the image
        final processedFile = await removeBackground(tempFile);

        // If background removal failed, use the original image
        final fileToSave = processedFile ?? tempFile;

        // Ensure the wardrobe_images directory exists
        final appDir = await getApplicationDocumentsDirectory();
        final wardrobeDir = Directory('${appDir.path}/wardrobe_images');
        if (!await wardrobeDir.exists()) {
          await wardrobeDir.create(recursive: true);
        }

        // Generate a unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'img_$timestamp.png';
        final savedFile = File('${wardrobeDir.path}/$fileName');

        // Copy the processed file to the final location
        await fileToSave.copy(savedFile.path);

        // Update state only if still mounted
        if (!mounted) return;

        setState(() {
          _selectedImage = savedFile;
          _imageUrl = savedFile.path; // Store the local path instead of URL
        });

        // Show success message with appropriate text based on background removal success
        if (mounted) {
          final successMessage = processedFile != null
              ? "Image downloaded and background removed successfully"
              : "Image downloaded successfully (background removal failed)";

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage))
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to download image: HTTP ${response.statusCode}"))
          );
        }
      }
    } catch (e) {
      print("Error processing URL image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error processing image: ${e.toString().substring(0, min(50, e.toString().length))}..."))
        );
      }
    }
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
// When creating a new item
  /// Save New Item to Hive
  Future<void> _saveItem() async {
    // Check if required fields are filled
    if (_selectedImage == null && (_imageUrl == null || _imageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add an image for your item")),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name for your item")),
      );
      return;
    }

    // Optional: Check if colors are selected
    if (_selectedColors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one color for your item")),
      );
      return;
    }

    String imageUrl = '';

    if (_selectedImage != null) {
      // Convert File to String path
      imageUrl = await saveImagePermanently(_selectedImage!);
    } else if (_imageUrl != null && _imageUrl!.startsWith('http')) {
      imageUrl = _imageUrl!;
    }

    final newItem = Item(
      id: DateTime.now().toString(),
      imageUrl: imageUrl,
      name: _nameController.text,
      description: _descriptionController.text,
      colors: _selectedColors,
      category: widget.category,
    );

    await itemsBox.add(newItem);
    if (mounted) {
      Navigator.pop(context, true);
    }
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.file(
                    // If the file path starts with "file://", remove it.
                    File(_selectedImage!.path.startsWith("file://")
                        ? _selectedImage!.path.replaceFirst(RegExp(r'^file://'), '')
                        : _selectedImage!.path),
                    fit: BoxFit.cover,
                  ),
                )
                    : _imageUrl != null
                    ? (_imageUrl!.startsWith("http")
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Image.network(_imageUrl!, fit: BoxFit.cover),
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: _selectedImage != null && File(_selectedImage!.path).existsSync()
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                  )
                      : (_imageUrl != null && _imageUrl!.startsWith("http")
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Image.network(_imageUrl!, fit: BoxFit.cover),
                  )
                      : const Icon(Icons.image, size: 100, color: Colors.grey)),
                ))
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
              maxLength: 100,

            ),
            const SizedBox(height: 5),
            // Color Picker Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _openColorPicker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300], // 🔹 Light Grey Background
                    foregroundColor: Colors.black, // 🔹 Black Text
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("SELECT COLOURS"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _selectedImage != null ? () => _extractColorsFromImage(_selectedImage!) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300], // 🔹 Light Grey Background
                    foregroundColor: Colors.black, // 🔹 Black Text
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("GENERATE COLOURS"),
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
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColors.remove(colorInt); // ✅ Remove color on tap
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(colorInt),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 1),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white), // ✅ X to remove
                    ),
                  );
                }).toList(),
              ),
            ],          ],
        ),
      ),

      // Floating Save Button
      floatingActionButton: SizedBox(
        height: 50, // Smaller height
        width: 50, // Smaller width
        child: FloatingActionButton(
          onPressed: _saveItem,
          backgroundColor: Colors.grey[300], // Light Grey
          foregroundColor: Colors.black, // Black Icon
          shape: const CircleBorder(), // Ensures a perfect circle
          child: const Icon(Icons.check, color: Colors.black, size: 30), // Smaller icon
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

