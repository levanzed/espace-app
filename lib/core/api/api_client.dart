import 'package:dio/dio.dart';

class ApiClient {
  // Local development backend
  // static const String baseUrl = "http://127.0.0.1:8000";

  // Production / Oracle backend
  static const String baseUrl = "https://api.espace.levanzed.fyi";

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
      ),
    );
  }
}