import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WardrobeTheme {
  static const Color pageBackground = Colors.white;
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF1E8DD);
  static const Color inputFill = Color(0xFFF5F2EE);
  static const Color ink = Color(0xFF1F1A17);
  static const Color mutedInk = Color(0xFF7A6F66);
  static const Color line = Color(0xFFEAE6E0);
  static const Color accent = Color(0xFF8B6C52);
  static const Color success = Color(0xFF6B7C5C);
  static const Color warning = Color(0xFFA86C3F);

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(18, 8, 18, 28);
  static const EdgeInsets roomyPagePadding = EdgeInsets.fromLTRB(22, 10, 22, 28);
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(24));
  static const BorderRadius mediaRadius = BorderRadius.all(Radius.circular(22));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(18));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(999));

  static const TextStyle eyebrow = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.8,
    color: mutedInk,
  );

  static const TextStyle appBarTitle = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 22,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.8,
    color: ink,
    height: 1,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.8,
    color: mutedInk,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 24,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.5,
    color: ink,
    height: 1,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 34,
    fontWeight: FontWeight.w300,
    height: 0.95,
    letterSpacing: 0.3,
    color: ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.5,
    color: mutedInk,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13.5,
    height: 1.4,
    color: mutedInk,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.6,
    color: mutedInk,
  );

  static BoxDecoration panelDecoration({bool withShadow = false}) {
    return BoxDecoration(
      color: surface,
      borderRadius: panelRadius,
      border: Border.all(color: line),
      boxShadow: withShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static InputDecoration inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: mutedInk),
      filled: true,
      fillColor: pageBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: buttonRadius,
        borderSide: const BorderSide(color: accent),
      ),
    );
  }

  static Widget buildHeaderTitle(String eyebrowText, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(eyebrowText, style: eyebrow),
        const SizedBox(height: 2),
        Text(title, style: appBarTitle),
      ],
    );
  }

  static Widget buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 1,
          color: accent,
        ),
        const SizedBox(width: 10),
        Text(title, style: sectionLabel),
      ],
    );
  }

  static Widget buildSectionShell({
    required String title,
    required Widget child,
    bool withShadow = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: panelDecoration(withShadow: withShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionHeader(title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  static Widget buildSheetOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: pageBackground,
      borderRadius: buttonRadius,
      child: InkWell(
        borderRadius: buttonRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: ink, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.4,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: bodySmall),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_up_right,
                size: 16,
                color: mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
