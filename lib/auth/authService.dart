import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:drobe/services/hiveServiceManager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AuthService with ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Constants
  static const String AUTH_BOX_NAME = 'authBox';
  static const String USER_ID_KEY = 'userId';
  static const String USER_EMAIL_KEY = 'userEmail';
  static const String USER_NAME_KEY = 'userName';
  static const String IS_LOGGED_IN_KEY = 'isLoggedIn';
  static const String USER_PASSWORD_KEY = 'userPassword'; // For demo purposes only

  // State
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isLoading = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('AuthService already initialized');
      return true;
    }

    try {
      debugPrint('Initializing AuthService...');
      _isLoading = true;
      notifyListeners();

      // Get the auth box using the improved HiveManager
      final box = await HiveManager().getBox(AUTH_BOX_NAME);

      // Load user data from the box
      _isLoggedIn = box.get(IS_LOGGED_IN_KEY, defaultValue: false);
      _userId = box.get(USER_ID_KEY);
      _userEmail = box.get(USER_EMAIL_KEY);
      _userName = box.get(USER_NAME_KEY);

      // Only set default name if userName is completely missing (null), not if it's just empty
      if (_isLoggedIn && _userName == null && _userEmail != null) {
        _userName = _userEmail!.split('@').first;
        await box.put(USER_NAME_KEY, _userName);
        debugPrint('Set default name from email: $_userName');
      }

      _isInitialized = true;
      debugPrint('AuthService initialized successfully');
      debugPrint('User login status: $_isLoggedIn');

      if (_isLoggedIn) {
        debugPrint('User is logged in: $_userEmail, name: $_userName');
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing AuthService: $e');
      // Set default values in case of error
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userName = null;
      _isInitialized = false; // Make sure to set this to false on error
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
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
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Login attempt with email: $email');

      // In a real app, you would validate credentials against a backend
      // For now, we'll simulate a successful login for any non-empty credentials
      if (email.isNotEmpty && password.isNotEmpty) {
        // Get the auth box
        final box = await HiveManager().getBox(AUTH_BOX_NAME);

        // Check if user already exists with this email
        final existingName = box.get(USER_NAME_KEY);
        final existingEmail = box.get(USER_EMAIL_KEY);

        // Store user data
        await box.put(IS_LOGGED_IN_KEY, true);
        await box.put(USER_EMAIL_KEY, email);
        await box.put(USER_ID_KEY, 'user_${DateTime.now().millisecondsSinceEpoch}');

        // Store password for demo purposes (in a real app, never store plain text passwords)
        await box.put(USER_PASSWORD_KEY, password);

        // Only use email prefix as name if no name exists at all
        if (existingName == null || existingName.isEmpty) {
          final userName = email.split('@').first;
          await box.put(USER_NAME_KEY, userName);
          debugPrint('AuthService: Set user name to: $userName');
        }

        // Update state
        _isLoggedIn = true;
        _userEmail = email;
        _userId = box.get(USER_ID_KEY);
        _userName = box.get(USER_NAME_KEY);

        debugPrint('AuthService: User logged in successfully: $email, name: $_userName');
        return true;
      } else {
        debugPrint('AuthService: Login failed: Empty credentials');
        return false;
      }
    } catch (e) {
      debugPrint('AuthService: Error during login: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register user
  Future<bool> signup(String name, String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Signup attempt with email: $email, name: $name');

      // In a real app, you would register the user with a backend
      // For now, we'll simulate a successful registration
      if (email.isNotEmpty && password.isNotEmpty) {
        // Get the auth box
        final box = await HiveManager().getBox(AUTH_BOX_NAME);

        // Store user data
        final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
        await box.put(IS_LOGGED_IN_KEY, true);
        await box.put(USER_EMAIL_KEY, email);
        await box.put(USER_ID_KEY, userId);

        // Store password for demo purposes (in a real app, never store plain text passwords)
        await box.put(USER_PASSWORD_KEY, password);

        // Use provided name or email prefix
        final userName = name.isNotEmpty ? name : email.split('@').first;
        await box.put(USER_NAME_KEY, userName);

        // Update state
        _isLoggedIn = true;
        _userEmail = email;
        _userId = userId;
        _userName = userName;

        debugPrint('AuthService: User registered successfully: $email, name: $_userName');
        return true;
      } else {
        debugPrint('AuthService: Registration failed: Empty credentials');
        return false;
      }
    } catch (e) {
      debugPrint('AuthService: Error during registration: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Change password
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('AuthService: Password change attempt');

      if (!_isLoggedIn) {
        debugPrint('AuthService: Cannot change password: User not logged in');
        return false;
      }

      // Get the auth box
      final box = await HiveManager().getBox(AUTH_BOX_NAME);

      // Verify current password (in a real app, this would be done securely)
      final storedPassword = box.get(USER_PASSWORD_KEY);

      if (storedPassword != currentPassword) {
        debugPrint('AuthService: Password change failed: Current password is incorrect');
        return false;
      }

      // Update password
      await box.put(USER_PASSWORD_KEY, newPassword);

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

      // Get the auth box
      final box = await HiveManager().getBox(AUTH_BOX_NAME);

      // Clear login status but keep user info for convenience
      await box.put(IS_LOGGED_IN_KEY, false);

      // Update state
      _isLoggedIn = false;

      debugPrint('AuthService: User logged out successfully');
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

      // Simulate password reset
      if (email.isNotEmpty) {
        // In a real app, you would send a reset email
        // For now, we'll just simulate success
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

        debugPrint('AuthService: Password reset email sent to: $email');
        return true;
      } else {
        debugPrint('AuthService: Password reset failed: Empty email');
        return false;
      }
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

      if (!_isLoggedIn) {
        debugPrint('AuthService: Cannot update profile: User not logged in');
        return false;
      }

      // Get the auth box
      final box = await HiveManager().getBox(AUTH_BOX_NAME);

      // Update name if provided
      if (name.isNotEmpty) {
        await box.put(USER_NAME_KEY, name);
        _userName = name;
        debugPrint('AuthService: Updated user name to: $name');
      }

      // Update email if provided
      if (email.isNotEmpty) {
        await box.put(USER_EMAIL_KEY, email);
        _userEmail = email;
        debugPrint('AuthService: Updated user email to: $email');
      }

      debugPrint('AuthService: User profile updated successfully');
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

      // Get the auth box
      final box = await HiveManager().getBox(AUTH_BOX_NAME);

      // Clear the box
      await box.clear();

      // Reset state
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userName = null;

      debugPrint('AuthService: Auth data cleared successfully');
    } catch (e) {
      debugPrint('AuthService: Error clearing auth data: $e');
    } finally {
      notifyListeners();
    }
  }
}

