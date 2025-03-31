import 'package:flutter/material.dart';
import 'package:drobe/auth/authService.dart';
import 'package:drobe/auth/login.dart';
import 'package:drobe/main.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('AuthWrapper: Checking auth status...');

      // Ensure AuthService is initialized
      final initSuccess = await _authService.ensureInitialized();

      if (!initSuccess) {
        debugPrint('AuthWrapper: Failed to initialize AuthService');
        // Handle initialization failure - maybe show an error screen
        // For now, we'll just set not logged in
        setState(() {
          _isLoading = false;
          _isLoggedIn = false;
        });
        return;
      }

      // Check if user is logged in
      final isLoggedIn = _authService.isLoggedIn;
      debugPrint('AuthWrapper: Auth service initialized. User is logged in: $isLoggedIn');

      setState(() {
        _isLoading = false;
        _isLoggedIn = isLoggedIn;
      });

      if (isLoggedIn) {
        final userData = await _authService.getCurrentUser();
        debugPrint('AuthWrapper: Logged in user: ${userData['name']} (${userData['email']})');
      }
    } catch (e) {
      debugPrint('AuthWrapper: Error checking auth status: $e');
      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If not logged in, show login page
    if (!_isLoggedIn) {
      return const LoginPage();
    }

    // If logged in, show the home page
    return const Homepage();
  }
}

