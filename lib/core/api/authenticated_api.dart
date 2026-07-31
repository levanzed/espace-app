import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_client.dart';

/// Shared authenticated API access used by feature repositories.
class AuthenticatedApi {
  AuthenticatedApi({
    ApiClient? api,
    SecureStorage? storage,
  })  : _api = api ?? ApiClient(),
        _storage = storage ?? SecureStorage();

  final ApiClient _api;
  final SecureStorage _storage;

  Dio get dio => _api.dio;

  Future<Options> authOptions({Options? options}) async {
    final token = await _storage.getToken();
    final headers = <String, dynamic>{
      ...?options?.headers,
      'Authorization': 'Bearer $token',
    };
    return (options ?? Options()).copyWith(headers: headers);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: await authOptions(),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: await authOptions(),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
  }) async {
    return dio.patch<T>(
      path,
      data: data,
      options: await authOptions(),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
  }) async {
    return dio.delete<T>(
      path,
      data: data,
      options: await authOptions(),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
  }) async {
    return dio.put<T>(
      path,
      data: data,
      options: await authOptions(),
    );
  }
}
