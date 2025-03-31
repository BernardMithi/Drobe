import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:drobe/models/item.dart';
import 'package:drobe/services/removeBackground.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:drobe/utils/image_utils.dart';

class EditItemPage extends StatefulWidget {
  final int itemIndex;

  const EditItemPage({super.key, required this.itemIndex});

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;
  late Item item;

  late Box itemsBox;
  List<int> _selectedColors = []; // Stores selected colors (Max 5)

  @override
  void initState() {
    super.initState();
    itemsBox = Hive.box('itemsBox');
    _loadItem();
  }

  void _loadItem() {
    item = itemsBox.values.toList()[widget.itemIndex];

    _nameController.text = item.name;
    _descriptionController.text = item.description;
    _selectedColors = List<int>.from(item.colors ?? []);

    if (item.imageUrl.startsWith('http')) {
      _imageUrl = item.imageUrl;
    } else if (item.imageUrl.isNotEmpty) {
      // Handle local file paths stored as relative paths
      getApplicationDocumentsDirectory().then((dir) {
        setState(() {
          final path = '${dir.path}/${item.imageUrl}';
          if (File(path).existsSync()) {
            _selectedImage = File(path);
          }
        });
      });
    }
  }

  /// Delete the item and return to previous screen
  /// Delete the item and return to wardrobeCategory
  /// Delete the item and pop multiple screens to reach wardrobeCategory
  void _deleteItem() {
    // Show confirmation dialog before deletion
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure you want to delete this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog
              Navigator.pop(context);

              // Delete the item from Hive
              final index = itemsBox.values.toList().indexWhere(
                      (itemInList) => itemInList.id == item.id);
              if (index != -1) {
                await itemsBox.deleteAt(index);
              }

              // Pop twice to return to wardrobeCategory
              // (Once for this EditItemPage and once for the ProductDetails page)
              if (mounted) {
                Navigator.pop(context); // Pop EditItemPage
                Navigator.pop(context); // Pop ProductDetails page to return to wardrobeCategory
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
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
  /// Pick Image from Camera or Gallery and remove background
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      final imageFile = File(pickedFile.path);

      // Show background removal in progress
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Removing background..."))
      );

      // Remove background from the image
      final processedFile = await removeBackground(imageFile);

      // If background removal failed, use the original image
      final fileToUse = processedFile ?? imageFile;

      setState(() {
        _selectedImage = fileToUse;
        _imageUrl = null;
      });

      // Extract colors from the processed image
      await _extractColorsFromImage(fileToUse);

      // Show success message
      final successMessage = processedFile != null
          ? "Background removed successfully"
          : "Image added (background removal failed)";

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage))
      );
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
  /// Download image from URL, remove background, and update state.
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

        // Save the processed image permanently
        final savedPath = await saveImagePermanently(fileToSave);
        final appDir = await getApplicationDocumentsDirectory();
        final savedFile = File('${appDir.path}/$savedPath');

        // Update state only if still mounted
        if (!mounted) return;

        setState(() {
          _selectedImage = savedFile;
          _imageUrl = null;
        });

        // Extract colors from the processed image
        await _extractColorsFromImage(savedFile);

        // Show success message
        final successMessage = processedFile != null
            ? "Image processed with background removed"
            : "Image downloaded (background removal failed)";

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage))
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to download image: HTTP ${response.statusCode}"))
          );
        }
        setState(() => _imageUrl = url); // Fallback to URL
      }
    } catch (e) {
      print("Error processing URL image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error processing image: ${e.toString()}"))
        );
      }
      setState(() => _imageUrl = url); // Fallback to URL
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

  /// Update existing item in Hive and return to details page
  Future<void> _updateItem() async {
    String imageUrl = item.imageUrl; // Default to existing image URL

    if (_selectedImage != null) {
      // Convert File to String path (store as relative path)
      imageUrl = await saveImagePermanently(_selectedImage!);
    } else if (_imageUrl != null && _imageUrl!.startsWith('http')) {
      imageUrl = _imageUrl!;
    }

    final updatedItem = Item(
      id: item.id,
      imageUrl: imageUrl,
      name: _nameController.text,
      description: _descriptionController.text,
      colors: _selectedColors,
      category: item.category, // Use the item's existing category
      inLaundry: item.inLaundry, // Preserve laundry status
    );

    final index = itemsBox.values.toList().indexWhere((itemInList) => itemInList.id == item.id);
    if (index != -1) {
      await itemsBox.putAt(index, updatedItem);
    }

    if (mounted) {
      // Return the updated item to the product details page
      Navigator.pop(context, updatedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EDIT ITEM"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.black, size: 28),
              onPressed: _deleteItem,
            ),
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
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
            ],
          ],
        ),
      ),

      // Floating Save Button
      floatingActionButton: SizedBox(
        height: 50, // Smaller height
        width: 50, // Smaller width
        child: FloatingActionButton(
          onPressed: _updateItem,
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

Future<String> saveImagePermanently(File imageFile) async {
  // Get application documents directory
  final appDir = await getApplicationDocumentsDirectory();

  // Create a dedicated folder for images
  final imagesDir = Directory('${appDir.path}/wardrobe_images');
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }

  // Generate unique filename
  final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.${imageFile.path.split('.').last}';

  // Full destination path
  final destPath = '${imagesDir.path}/$fileName';

  // Copy file to permanent location
  await imageFile.copy(destPath);

  // Return only the RELATIVE path (important!)
  return 'wardrobe_images/$fileName';
}

Future<Directory> getImageDirectory() async {
  // Get application documents directory
  final appDir = await getApplicationDocumentsDirectory();

  // Create a specific directory for images
  final imagesDir = Directory('${appDir.path}/wardrobe_images');

  // Create the directory if it doesn't exist
  if (!await imagesDir.exists()) {
    await imagesDir.create(recursive: true);
  }

  return imagesDir;
}