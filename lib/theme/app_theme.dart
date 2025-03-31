import 'package:flutter/material.dart';

class AppTheme {
  // App Colors
  static const Color primaryColor = Color(0xFF424242); // Blue
  static const Color secondaryColor = Color(0xFF757575); // Light Blue
  static const Color accentColor = Color(0xFFFF9800); // Orange
  static const Color errorColor = Color(0xFFE53935); // Red
  static const Color backgroundColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF212121); // Dark Grey
  static const Color textSecondaryColor = Color(0xFF757575); // Medium Grey
  static const Color dividerColor = Color(0xFFBDBDBD); // Light Grey

  // Text Styles
  static const String fontFamily = 'Avenir'; // Or 'Nunito' if using alternative

  static TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimaryColor,
    ),
    displayMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: textPrimaryColor,
    ),
    displaySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textPrimaryColor,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
    titleLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: textPrimaryColor,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.normal,
      color: textPrimaryColor,
    ),
    bodySmall: TextStyle(
      fontFamily: fontFamily,
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: textSecondaryColor,
    ),
    labelLarge: TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: primaryColor,
    ),
  );

  // Input Decoration Theme
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    // Border when not focused
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: dividerColor),
      borderRadius: BorderRadius.circular(8),
    ),
    // Border when focused
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: primaryColor, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    // Border when there's an error
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: errorColor),
      borderRadius: BorderRadius.circular(8),
    ),
    // Border when focused and has an error
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: errorColor, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    // Label style
    labelStyle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      color: textSecondaryColor,
    ),
    // Hint style
    hintStyle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      color: textSecondaryColor.withOpacity(0.6),
    ),
    // Error style
    errorStyle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 12,
      color: errorColor,
    ),
    // Add some padding inside the text field
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    // Make the filled background subtle
    filled: true,
    fillColor: Colors.grey.shade50,
  );

  // Button Theme
  static ElevatedButtonThemeData elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primaryColor,
      textStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 2,
    ),
  );

  static OutlinedButtonThemeData outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      textStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      side: BorderSide(color: secondaryColor, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  static TextButtonThemeData textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryColor,
      textStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
  );

  // App Bar Theme
  static AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: backgroundColor,
    foregroundColor: textPrimaryColor,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: fontFamily,
      fontSize: 18, // Slightly smaller to accommodate uppercase
      fontWeight: FontWeight.w600,
      color: textPrimaryColor,
      letterSpacing: 1.0, // Add slight letter spacing for better uppercase readability
    ),
    iconTheme: IconThemeData(
      color: textPrimaryColor,
    ),
  );

  // Card Theme
  static CardTheme cardTheme = CardTheme(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Create the complete theme
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: backgroundColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: fontFamily,
    textTheme: textTheme,
    inputDecorationTheme: inputDecorationTheme,
    elevatedButtonTheme: elevatedButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    appBarTheme: appBarTheme,
    cardTheme: cardTheme,
    dividerTheme: DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return primaryColor;
        }
        return Colors.transparent;
      }),
      side: BorderSide(color: dividerColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return primaryColor;
        }
        return Colors.grey.shade400;
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return primaryColor.withOpacity(0.5);
        }
        return Colors.grey.shade300;
      }),
    ),
    // Add more theme customizations as needed
  );

  // You can also create a dark theme if needed
  static ThemeData darkTheme = ThemeData(
    // Dark theme configuration
    // ...
  );
}

