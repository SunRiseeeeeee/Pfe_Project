import 'package:dio/dio.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.188.159:3000/auth/secretary/login';
  final Dio _dio = Dio();

  Future<bool> login(String username, String password, String email) async {
    try {
      Map<String, dynamic> data = {
        'username': username,
        'password': password,
        'email': email,
      };

      Response response = await _dio.post(
        baseUrl,
        data: data,
      );

      if (response.statusCode == 200) {
        print('Login Successful: ${response.data}');
        return true;
      } else {
        print('Login Failed: ${response.statusCode} - ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
  }
}