import 'dart:io';
import 'package:path_provider/path_provider.dart';

// Save image to permanent location and return a relative path
Future<String> saveImagePermanently(File imageFile) async {
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

  // Return only the RELATIVE path
  return 'wardrobe_images/$fileName';
}

// Convert relative path to absolute
Future<String> getAbsoluteImagePath(String relativePath) async {
  if (relativePath.startsWith('/')) {
    // Already an absolute path, return as is
    return relativePath;
  }

  final directory = await getApplicationDocumentsDirectory();
  return '${directory.path}/$relativePath'.replaceAll('//', '/'); // Ensure no double slashes
}


