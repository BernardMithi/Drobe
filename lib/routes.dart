import 'package:flutter/material.dart';
import 'package:drobe/auth/authWrapper.dart';
import 'package:drobe/auth/login.dart';
import 'package:drobe/auth/signup.dart';
import 'package:drobe/auth/forgotPassword.dart';
import 'package:drobe/Wardrobe/wardrobe.dart';
import 'package:drobe/Outfits/outfits.dart';
import 'package:drobe/Lookbook/lookbook.dart';
import 'package:drobe/Laundry/laundry.dart';
import 'package:drobe/settings/settings.dart';
import 'package:drobe/settings/profile.dart';
import 'package:drobe/settings/passwordChange.dart';
import 'package:drobe/Fabrics/fabricTips.dart';

// Define app routes
final Map<String, WidgetBuilder> routes = {
  '/': (context) => const AuthWrapper(),
  '/login': (context) => const LoginPage(),
  '/signup': (context) => const SignupPage(),
  '/forgot-password': (context) => const ForgotPasswordPage(),
  '/wardrobe': (context) => const WardrobePage(),
  '/outfits': (context) => const OutfitsPage(),
  '/lookbook': (context) => const LookbookPage(),
  '/laundry': (context) => const LaundryPage(),
  '/fabricTips': (context) => const FabricTipsPage(),
  '/settings': (context) => const SettingsPage(),
  '/settings/profile': (context) => const ProfilePage(),
  '/settings/passwordChange': (context) => const PasswordChangePage(),
};

// Route generator for more complex routes with parameters
Route<dynamic>? generateRoute(RouteSettings settings) {
  // Extract route name
  final routeName = settings.name;
  final arguments = settings.arguments;

  // If no match is found, return null to let the routes table handle it
  return null;
}

