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
  bool _isLoading = true;
  bool _isLoggedIn = false;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authService.addListener(_onAuthStateChanged);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isLoggedIn;
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    await _authService.initialize();

    if (mounted) {
      setState(() {
        _isLoggedIn = _authService.isLoggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If not logged in, redirect to login page
    if (!_isLoggedIn) {
      return const LoginPage();
    }

    // If logged in, show the main app
    return const Homepage();
  }
}

