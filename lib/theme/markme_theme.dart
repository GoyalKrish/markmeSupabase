import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MarkMeTheme {
  // Brand Colors
  static const primaryYellow = Color(0xFFFFB800);
  static const primaryWhite = Color(0xFFFFFFFF);
  static const darkBackground = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  
  // Gradients
  static const buttonGradient = LinearGradient(
    colors: [
      Color(0xFFFFB800),
      Color(0xFFFFA000),
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF121212),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Text Styles
  static TextStyle get headingStyle => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: primaryWhite,
    letterSpacing: 0.5,
  );
  
  static TextStyle get subheadingStyle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: primaryWhite.withOpacity(0.7),
    letterSpacing: 0.3,
  );
  
  static TextStyle get labelStyle => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: primaryWhite.withOpacity(0.8),
  );
  
  static TextStyle get buttonTextStyle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: darkBackground,
    letterSpacing: 0.5,
  );
  
  // Input Decoration
  static InputDecoration getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: primaryWhite.withOpacity(0.4),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: primaryYellow.withOpacity(0.7),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: surfaceDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: primaryYellow.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
    );
  }
} 