import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:vetapp_v1/screens/landing_page.dart';
import 'models/token_storage.dart';
import 'screens/login.dart';
import 'theme.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  // Create Dio instance with token refresh interceptor
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.16:3000/api'));
  final authService = AuthService(); // Create AuthService instance for token refreshing

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await TokenStorage.getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      print("REQUEST[${options.method}] => PATH: ${options.path}, DATA: ${options.data}");
      return handler.next(options);
    },
    onResponse: (response, handler) {
      print("RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}, DATA: ${response.data}");
      return handler.next(response);
    },
    onError: (DioException e, handler) async {
      print("ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}, MESSAGE: ${e.response?.data['message'] ?? e.message}");
      if (e.response?.statusCode == 401) {
        // Attempt to refresh token
        final refreshResult = await authService.refreshToken();
        if (refreshResult["success"]) {
          // Retry the original request with the new token
          final options = e.requestOptions;
          final newToken = refreshResult["accessToken"];
          options.headers['Authorization'] = 'Bearer $newToken';
          try {
            final retryResponse = await dio.request(
              options.path,
              data: options.data,
              queryParameters: options.queryParameters,
              options: Options(
                method: options.method,
                headers: options.headers,
              ),
            );
            return handler.resolve(retryResponse);
          } catch (retryError) {
            return handler.next(retryError as DioException);
          }
        } else {
          // Refresh failed, handle logout or redirect to login
          return handler.next(e);
        }
      }
      return handler.next(e);
    },
  ));

  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>.value(value: dio),
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(prefs: prefs, isDarkMode: isDarkMode),
        ),
      ],
      child: const AppWrapper(),
    ),
  );
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyApp();
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
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: true);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login App',
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: themeProvider.themeMode,
      home: LandingPage(),
    );
  }
}