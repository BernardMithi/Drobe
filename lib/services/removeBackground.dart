import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


Future<File?> removeBackground(File imageFile) async {
  const apiKey = 'f5o5CAacHStduzxPJzh9VeSr'; // Replace with your remove.bg API key
  final url = Uri.parse('https://api.remove.bg/v1.0/removebg');

  try {
    // Create a multipart request
    final request = http.MultipartRequest('POST', url)
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'; // optional field

    // Attach the image file
    request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

    // Send the request
    final response = await request.send();

    if (response.statusCode == 200) {
      // Read the response bytes
      final bytes = await response.stream.toBytes();

      // Get the temporary directory to store the processed image
      final tempDir = await getTemporaryDirectory();
      final newFilePath = path.join(tempDir.path, 'no_bg_${path.basename(imageFile.path)}');

      // Write the processed image bytes to a new file
      final newFile = File(newFilePath);
      await newFile.writeAsBytes(bytes);
      return newFile;
    } else {
      // Log error details
      final errorResponse = await response.stream.bytesToString();
      print('remove.bg API Error: ${response.statusCode} - $errorResponse');
      return null;
    }
  } catch (e) {
    print('Exception in removeBackground: $e');
    return null;
  }
}