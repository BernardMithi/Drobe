import 'package:drobe/models/outfit.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:drobe/auth/authService.dart';
import 'package:uuid/uuid.dart';

class OutfitStorageService {
  static const String _boxName = 'outfitsBox';
  static Box? _box;

  // Initialize the service
  static Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return;
    }

    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      debugPrint('OutfitStorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing OutfitStorageService: $e');
      // Try to recover by deleting and recreating the box
      try {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox(_boxName);
        debugPrint('OutfitStorageService recovered successfully');
      } catch (e) {
        debugPrint('Failed to recover OutfitStorageService: $e');
        rethrow;
      }
    }
  }

  // Get the current user ID
  static Future<String?> _getCurrentUserId() async {
    try {
      final authService = AuthService();
      final userData = await authService.getCurrentUser();
      return userData['id'];
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }

  // Save an outfit
  static Future<Outfit> saveOutfit(Outfit outfit) async {
    await init();

    try {
      // Get the current user ID
      final userId = await _getCurrentUserId();

      // Generate a new ID if not provided
      if (outfit.id == null || outfit.id!.isEmpty) {
        outfit.id = const Uuid().v4();
      }

      // Set the user ID
      final outfitWithUserId = outfit.copyWith(userId: userId);

      // Save to Hive
      await _box!.put(outfitWithUserId.id, outfitWithUserId);

      debugPrint('Saved outfit with ID: ${outfitWithUserId.id}, User ID: $userId');
      return outfitWithUserId;
    } catch (e) {
      debugPrint('Error saving outfit: $e');
      rethrow;
    }
  }

  // Update an existing outfit
  static Future<void> updateOutfit(Outfit outfit) async {
    await init();

    try {
      if (outfit.id == null || outfit.id!.isEmpty) {
        throw Exception('Cannot update outfit without ID');
      }

      // Get the current user ID
      final userId = await _getCurrentUserId();

      // Verify the outfit belongs to the current user
      final existingOutfit = await getOutfit(outfit.id!);
      if (existingOutfit != null && existingOutfit.userId != null &&
          existingOutfit.userId != userId) {
        throw Exception('Cannot update outfit: It belongs to another user');
      }

      // Set the user ID
      final outfitWithUserId = outfit.copyWith(userId: userId);

      // Update in Hive
      await _box!.put(outfitWithUserId.id, outfitWithUserId);

      debugPrint('Updated outfit with ID: ${outfitWithUserId.id}');
    } catch (e) {
      debugPrint('Error updating outfit: $e');
      rethrow;
    }
  }

  // Get a specific outfit by ID
  static Future<Outfit?> getOutfit(String id) async {
    await init();

    try {
      final outfit = _box!.get(id);
      if (outfit == null) {
        return null;
      }

      // Get the current user ID
      final userId = await _getCurrentUserId();

      // Only return the outfit if it belongs to the current user or has no user ID
      if (outfit.userId == null || outfit.userId == userId) {
        return outfit;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting outfit: $e');
      return null;
    }
  }

  // Get all outfits for the current user
  static Future<List<Outfit>> getAllOutfits() async {
    await init();

    try {
      // Get the current user ID
      final userId = await _getCurrentUserId();

      if (userId == null) {
        debugPrint('Warning: No current user ID available, returning empty outfit list');
        return [];
      }

      // Get all outfits
      final allOutfits = _box!.values.whereType<Outfit>().toList();

      // Filter by user ID - ONLY include outfits that explicitly match the current user ID
      // or have no user ID (for backward compatibility)
      final userOutfits = allOutfits.where((outfit) =>
      outfit.userId == userId || outfit.userId == null
      ).toList();

      debugPrint('Found ${userOutfits.length} outfits for user $userId');
      return userOutfits;
    } catch (e) {
      debugPrint('Error getting all outfits: $e');
      return [];
    }
  }

  // Delete an outfit
  static Future<void> deleteOutfit(String id) async {
    await init();

    try {
      // Get the current user ID
      final userId = await _getCurrentUserId();

      // Verify the outfit belongs to the current user
      final existingOutfit = await getOutfit(id);
      if (existingOutfit != null && existingOutfit.userId != null &&
          existingOutfit.userId != userId) {
        throw Exception('Cannot delete outfit: It belongs to another user');
      }

      await _box!.delete(id);
      debugPrint('Deleted outfit with ID: $id');
    } catch (e) {
      debugPrint('Error deleting outfit: $e');
      rethrow;
    }
  }

  // Close the box
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}

