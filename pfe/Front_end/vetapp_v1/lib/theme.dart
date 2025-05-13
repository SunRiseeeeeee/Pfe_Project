import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData buildLightTheme() {
    final Color primaryColor = Colors.deepPurple;
    final Color primaryContainer = Color(0xFF5E35B1);
    final Color secondaryColor = Color(0xFF7C4DFF);
    final Color secondaryContainer = Colors.deepPurple[200]!;
    final Color surfaceColor = Colors.white;
    final Color backgroundColor = Color(0xFFF5F5F5);
    final Color onSurfaceColor = Color(0xFF212121);
    final Color errorColor = Color(0xFFD32F2F);

    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryContainer,
        secondary: secondaryColor,
        secondaryContainer: secondaryContainer,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurfaceColor,
        onBackground: onSurfaceColor,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[300],
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.grey[100],
        filled: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[400]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: onSurfaceColor.withOpacity(0.8)),
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey[300]!;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: Colors.grey[600]!, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onSurfaceColor),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurfaceColor),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurfaceColor),
        bodyLarge: TextStyle(fontSize: 16, color: onSurfaceColor),
        bodyMedium: TextStyle(fontSize: 14, color: onSurfaceColor),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: onSurfaceColor),
        bodySmall: TextStyle(fontSize: 12, color: onSurfaceColor.withOpacity(0.6)),
        labelSmall: TextStyle(fontSize: 10, color: onSurfaceColor.withOpacity(0.6)),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    final Color primaryColor = Colors.deepPurple;
    final Color primaryContainer = Colors.deepPurple[700]!;
    final Color secondaryColor = Color(0xFF7C4DFF);
    final Color secondaryContainer = Colors.deepPurple[500]!;
    final Color surfaceColor = Color(0xFF1E1E1E);
    final Color backgroundColor = Color(0xFF121212);
    final Color onSurfaceColor = Colors.white.withOpacity(0.87);
    final Color errorColor = Color(0xFFD32F2F);

    return ThemeData(
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryContainer,
        secondary: secondaryColor,
        secondaryContainer: secondaryContainer,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onSurfaceColor,
        onBackground: onSurfaceColor,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
          color: onSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey[700],
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Color(0xFF2D2D2D),
        filled: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: TextStyle(color: onSurfaceColor.withOpacity(0.8)),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey[500]!;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: Colors.grey[500]!, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurfaceColor),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onSurfaceColor),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurfaceColor),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: onSurfaceColor),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurfaceColor),
        bodyLarge: TextStyle(fontSize: 16, color: onSurfaceColor),
        bodyMedium: TextStyle(fontSize: 14, color: onSurfaceColor),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: onSurfaceColor),
        bodySmall: TextStyle(fontSize: 12, color: onSurfaceColor.withOpacity(0.6)),
        labelSmall: TextStyle(fontSize: 10, color: onSurfaceColor.withOpacity(0.6)),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}