import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'screens/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>(
          create: (_) => Dio(BaseOptions(baseUrl: 'http://192.168.1.18:3000/api')),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(prefs: prefs, isDarkMode: isDarkMode),
        ),
      ],
      child: AppWrapper(),
    ),
  );
}

class AppWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MyApp();
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode;
  final SharedPreferences prefs;

  ThemeProvider({required this.prefs, required bool isDarkMode})
      : _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> toggleTheme(bool isOn) async {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('isDarkMode', isOn);
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login App',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeProvider.themeMode,
      home: LoginPage(),
    );
  }

  ThemeData _buildLightTheme() {
    final Color primaryColor = Colors.deepPurple;
    final Color primaryVariant = Color(0xFF5E35B1); // A deeper purple
    final Color secondaryColor = Color(0xFF7C4DFF); // A vibrant purple
    final Color surfaceColor = Colors.white;
    final Color backgroundColor = Color(0xFFF5F5F5); // Slightly warmer than grey[50]
    final Color onSurfaceColor = Color(0xFF212121); // Darker than black87 for better readability
    final Color errorColor = Color(0xFFD32F2F); // Standard Material red

    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        primaryContainer: primaryVariant,
        secondary: secondaryColor,
        secondaryContainer: Colors.deepPurple[100]!,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
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
        titleTextStyle: TextStyle(
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
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
      textTheme: TextTheme(
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final Color primaryColor = Colors.deepPurple[300]!;
    final Color primaryVariant = Color(0xFF9575CD); // A softer purple
    final Color secondaryColor = Color(0xFFB388FF); // A light vibrant purple
    final Color surfaceColor = Color(0xFF1E1E1E);
    final Color backgroundColor = Color(0xFF121212);
    final Color onSurfaceColor = Colors.white.withOpacity(0.87);
    final Color errorColor = Color(0xFFCF6679); // Softer red for dark theme

    return ThemeData(
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        primaryContainer: primaryVariant,
        secondary: secondaryColor,
        secondaryContainer: Colors.deepPurple[700]!,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: onSurfaceColor,
        onBackground: onSurfaceColor,
        onError: Colors.black,
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
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: onSurfaceColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(color: primaryColor),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
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
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
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
      textTheme: TextTheme(
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}