import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Constants
  static const String USERS_BOX_NAME = 'users';
  static const String CURRENT_USER_ID_KEY = 'currentUserId';

  // State
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isLoading = false;
  String? _currentUserId;
  Map<String, dynamic>? _currentUserData;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  // Initialize the service
  Future<bool> initialize() async {
    try {
      if (_isInitialized) {
        return true;
      }

      // Initialize Hive
      await Hive.initFlutter();

      // Open the users box
      final box = await Hive.openBox(USERS_BOX_NAME);

      // Migrate users from old AUTH_BOX if needed
      await _migrateUsersFromAuthBox();

      // Check if there's a saved user ID
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(CURRENT_USER_ID_KEY);

      if (savedUserId != null) {
        // Get the user data
        final userData = box.get(savedUserId);

        if (userData != null) {
          // Set the current user
          _currentUserId = savedUserId;
          _userId = savedUserId;
          _currentUserData = Map<String, dynamic>.from(userData);
          _isLoggedIn = true;

          // Set user email and name
          _userEmail = _currentUserData!['email'];
          _userName = _currentUserData!['name'];

          debugPrint('Restored login session for user ID: $savedUserId, Email: $_userEmail, Name: $_userName');
        } else {
          // User data not found, clear the saved ID
          await prefs.remove(CURRENT_USER_ID_KEY);
          _isLoggedIn = false;
          _userId = null;
          _userEmail = null;
          _userName = null;
          _currentUserId = null;
          _currentUserData = null;
          debugPrint('Saved user ID not found in database, clearing session');
        }
      } else {
        _isLoggedIn = false;
        _userId = null;
        _userEmail = null;
        _userName = null;
        _currentUserId = null;
        _currentUserData = null;
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing AuthService: $e');
      _isInitialized = false;
      return false;
    }
  }

  // Migrate users from old AUTH_BOX to users box
  Future<void> _migrateUsersFromAuthBox() async {
    try {
      // Check if the old AUTH_BOX exists
      if (await Hive.boxExists('authBox')) {
        debugPrint('Found old authBox, migrating users...');

        final authBox = await Hive.openBox('authBox');
        final usersMap = authBox.get('users');

        if (usersMap != null) {
          final users = Map<String, dynamic>.from(usersMap);
          final usersBox = await Hive.openBox(USERS_BOX_NAME);

          // Migrate each user
          int migratedCount = 0;
          users.forEach((userId, userData) {
            // Only migrate if user doesn't already exist in users box
            if (!usersBox.containsKey(userId)) {
              usersBox.put(userId, userData);
              migratedCount++;
            }
          });

          debugPrint('Migrated $migratedCount users from authBox to users box');
        }
      }
    } catch (e) {
      debugPrint('Error migrating users from authBox: $e');
    }
  }

  // Add a safe method to check initialization status
  Future<bool> ensureInitialized() async {
    if (!_isInitialized) {
      return await initialize();
    }
    return true;
  }

  // Login user
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Debug: List all users before attempting login
      await listAllUsers();

      // Get the users box
      final box = await Hive.openBox(USERS_BOX_NAME);

      // Find the user with matching email
      Map<String, dynamic>? userData;
      String? userId;

      for (var key in box.keys) {
        final user = box.get(key);
        if (user != null && user['email'].toString().toLowerCase() == email.toLowerCase()) {
          userData = Map<String, dynamic>.from(user);
          userId = key.toString();
          break;
        }
      }

      // Check if user exists
      if (userData == null) {
        debugPrint('Login failed: User not found with email $email');
        return {
          'success': false,
          'message': 'Invalid email or password',
        };
      }

      // Validate password
      if (userData['password'] != password) {
        debugPrint('Login failed: Incorrect password for $email');
        return {
          'success': false,
          'message': 'Invalid email or password',
        };
      }

      // Set the logged-in user
      _currentUserId = userId;
      _userId = userId;
      _currentUserData = userData;
      _userEmail = userData['email'];
      _userName = userData['name'];
      _isLoggedIn = true;

      // Save the current user ID to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CURRENT_USER_ID_KEY, userId!);

      debugPrint('Login successful for user: $email, ID: $userId, Name: $_userName');

      // Notify listeners that auth state has changed
      notifyListeners();

      return {
        'success': true,
        'userId': userId,
        'userData': userData,
      };
    } catch (e) {
      debugPrint('Error during login: $e');
      return {
        'success': false,
        'message': 'An error occurred during login: $e',
      };
    }
  }

  // Register user
  Future<bool> signup(String name, String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Signup attempt with email: $email, name: $name');

      if (email.isEmpty || password.isEmpty) {
        debugPrint('AuthService: Registration failed: Empty credentials');
        return false;
      }

      // Debug: List all users before attempting signup
      await listAllUsers();

      // Check if email exists
      final emailExists = await checkEmailExists(email);

      if (emailExists) {
        debugPrint('AuthService: Registration failed: Email already exists');
        return false;
      }

      // Create new user
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final userName = name.isNotEmpty ? name : email.split('@').first;

      // Create user data
      final userData = {
        'email': email.toLowerCase(),
        'name': userName,
        'password': password,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      // Add user to users box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);
      await usersBox.put(userId, userData);
      debugPrint('User added to users box with ID: $userId');

      // Set as current user
      _isLoggedIn = true;
      _userId = userId;
      _currentUserId = userId;
      _userEmail = email.toLowerCase();
      _userName = userName;
      _currentUserData = userData;

      // Save current user ID to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CURRENT_USER_ID_KEY, userId);

      debugPrint('AuthService: User registered successfully: $email, name: $_userName, ID: $_userId');

      // Notify listeners that auth state has changed
      notifyListeners();

      // Debug: List all users after signup
      await listAllUsers();

      return true;
    } catch (e) {
      debugPrint('AuthService: Error during registration: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Diagnostic function to list all users
  Future<void> listAllUsers() async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      debugPrint('======= LISTING ALL USERS =======');

      // Check users in the 'users' box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);
      debugPrint('Users in "$USERS_BOX_NAME" box: ${usersBox.keys.length}');

      for (var key in usersBox.keys) {
        final userData = usersBox.get(key);
        if (userData != null) {
          debugPrint('User ID: $key, Email: ${userData['email']}, Name: ${userData['name']}');
        }
      }

      debugPrint('======= END USER LISTING =======');
    } catch (e) {
      debugPrint('Error listing users: $e');
    }
  }

  // Check if email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      // Check in users box
      final box = await Hive.openBox(USERS_BOX_NAME);

      for (var key in box.keys) {
        final user = box.get(key);
        if (user != null && user['email'].toString().toLowerCase() == email.toLowerCase()) {
          return true; // Email exists
        }
      }

      return false; // Email not found
    } catch (e) {
      debugPrint('Error checking if email exists: $e');
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(String email, String newPassword) async {
    try {
      if (!isInitialized) {
        await initialize();
      }

      debugPrint('Attempting to reset password for email: $email');

      // Find user in users box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);
      String? userId;
      Map<String, dynamic>? userData;

      for (var key in usersBox.keys) {
        final user = usersBox.get(key);
        if (user != null && user['email'].toString().toLowerCase() == email.toLowerCase()) {
          userId = key.toString();
          userData = Map<String, dynamic>.from(user);
          break;
        }
      }

      // Check if user was found
      if (userId == null || userData == null) {
        debugPrint('Password reset failed: User not found with email $email');
        return false;
      }

      // Update password
      userData['password'] = newPassword;
      await usersBox.put(userId, userData);
      debugPrint('Password updated for user: $email');

      debugPrint('Password reset successful for user: $email');
      return true;
    } catch (e) {
      debugPrint('Error during password reset: $e');
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Password change attempt');

      if (!_isLoggedIn || _userId == null) {
        debugPrint('AuthService: Cannot change password: User not logged in');
        return false;
      }

      // Get the users box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);

      // Get current user data
      if (!usersBox.containsKey(_userId)) {
        debugPrint('AuthService: Cannot change password: User not found');
        return false;
      }

      final userData = Map<String, dynamic>.from(usersBox.get(_userId!) ?? {});

      // Verify current password
      if (userData['password'] != currentPassword) {
        debugPrint('AuthService: Password change failed: Current password is incorrect');
        return false;
      }

      // Update password
      userData['password'] = newPassword;
      await usersBox.put(_userId!, userData);

      debugPrint('AuthService: Password changed successfully');
      return true;
    } catch (e) {
      debugPrint('AuthService: Error changing password: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout user
  Future<bool> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Logout attempt');

      // Clear current user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CURRENT_USER_ID_KEY);

      // Update state
      _isLoggedIn = false;
      _currentUserId = null;
      _currentUserData = null;
      _userId = null;
      _userEmail = null;
      _userName = null;

      debugPrint('AuthService: User logged out successfully');

      // Notify listeners that auth state has changed
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('AuthService: Error during logout: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Send password reset email (in a real app, this would send a reset email)
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Password reset attempt for email: $email');

      if (email.isEmpty) {
        debugPrint('AuthService: Password reset failed: Empty email');
        return false;
      }

      // Check if email exists
      final emailExists = await checkEmailExists(email);

      if (!emailExists) {
        debugPrint('AuthService: Password reset failed: Email not found');
        // Still return true for security reasons (don't reveal if email exists)
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
        return true;
      }

      // In a real app, you would send a reset email
      // For now, we'll just simulate success
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

      debugPrint('AuthService: Password reset email sent to: $email');
      return true;
    } catch (e) {
      debugPrint('AuthService: Error during password reset: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<bool> updateProfile(String name, String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Profile update attempt - name: $name, email: $email');

      if (!_isLoggedIn || _userId == null) {
        debugPrint('AuthService: Cannot update profile: User not logged in');
        return false;
      }

      // Get the users box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);

      // Get current user data
      if (!usersBox.containsKey(_userId)) {
        debugPrint('AuthService: Cannot update profile: User not found');
        return false;
      }

      final userData = Map<String, dynamic>.from(usersBox.get(_userId!) ?? {});

      // Check if email is being changed and if it already exists
      if (email.isNotEmpty && email.toLowerCase() != userData['email'].toString().toLowerCase()) {
        bool emailExists = await checkEmailExists(email);

        if (emailExists) {
          debugPrint('AuthService: Profile update failed: Email already exists');
          return false;
        }

        // Update email
        userData['email'] = email.toLowerCase();
        _userEmail = email.toLowerCase();
        debugPrint('AuthService: Updated user email to: $email');
      }

      // Update name if provided
      if (name.isNotEmpty) {
        userData['name'] = name;
        _userName = name;
        debugPrint('AuthService: Updated user name to: $name');
      }

      // Save updated user data
      await usersBox.put(_userId!, userData);

      // Update current user data
      _currentUserData = userData;

      debugPrint('AuthService: User profile updated successfully');

      // Notify listeners that user data has changed
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('AuthService: Error updating profile: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a safer getCurrentUser method that checks initialization
  Future<Map<String, String>> getCurrentUser() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Warning: Failed to initialize AuthService in getCurrentUser');
        return {
          'id': '',
          'email': '',
          'name': '',
        };
      }
    }

    // If user is not logged in, return empty values
    if (!_isLoggedIn || _userId == null || _userId!.isEmpty) {
      debugPrint('Warning: User is not logged in or has no ID');
      return {
        'id': '',
        'email': '',
        'name': '',
      };
    };

    debugPrint('getCurrentUser returning: ID: $_userId, Email: $_userEmail, Name: $_userName');

    return {
      'id': _userId ?? '',
      'email': _userEmail ?? '',
      'name': _userName ?? '',
    };
  }

  // Get profile image path for the current user
  Future<String?> getProfileImagePath() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isLoggedIn || _userId == null) {
      return null;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final profileImagePath = path.join(directory.path, 'profile_$_userId.jpg');
      final file = File(profileImagePath);

      if (await file.exists()) {
        return profileImagePath;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting profile image path: $e');
      return null;
    }
  }

  // Save profile image for the current user
  Future<bool> saveProfileImage(File imageFile) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isLoggedIn || _userId == null) {
      return false;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final profileImagePath = path.join(directory.path, 'profile_$_userId.jpg');

      // Copy the image file to the profile image path
      await imageFile.copy(profileImagePath);

      return true;
    } catch (e) {
      debugPrint('Error saving profile image: $e');
      return false;
    }
  }

  // Clear all auth data (useful for testing or account deletion)
  Future<void> clearAuthData() async {
    try {
      debugPrint('AuthService: Clearing all auth data');

      // Clear the users box
      final usersBox = await Hive.openBox(USERS_BOX_NAME);
      await usersBox.clear();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CURRENT_USER_ID_KEY);

      // Reset state
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userName = null;
      _currentUserId = null;
      _currentUserData = null;

      debugPrint('AuthService: Auth data cleared successfully');

      // Notify listeners that auth state has changed
      notifyListeners();
    } catch (e) {
      debugPrint('AuthService: Error clearing auth data: $e');
    } finally {
      notifyListeners();
    }
  }
}

extension AuthServiceExtension on AuthService {
  Future<String> createUserDirectly(String name, String email, String password) async {
    try {
      // Open the users box
      final usersBox = await Hive.openBox(AuthService.USERS_BOX_NAME);

      // Check if a user with this email already exists
      bool userExists = await checkEmailExists(email);

      if (userExists) {
        debugPrint('User with email $email already exists');
        // Return the existing user's ID or throw an exception
        throw Exception('User with email $email already exists');
      }

      // Create a new user ID
      final userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create the user data
      final userData = {
        'id': userId,
        'name': name,
        'email': email.toLowerCase(),
        'password': password, // In a real app, this should be hashed
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Save the user data in users box
      await usersBox.put(userId, userData);

      // Set the user as logged in
      _currentUserId = userId;
      _userId = userId;
      _currentUserData = Map<String, dynamic>.from(userData);
      _userEmail = email.toLowerCase();
      _userName = name;
      _isLoggedIn = true;

      // Save the current user ID to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthService.CURRENT_USER_ID_KEY, userId);

      debugPrint('Created and logged in user: $name ($email)');

      // Notify listeners that auth state has changed
      notifyListeners();

      return userId;
    } catch (e) {
      debugPrint('Error creating user directly: $e');
      throw e;
    }
  }
}

