// api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrl = 'https://doswing.in/cloudstorage';
  static final String _apiKey =
      '281af63ca719ddcb1870c5bf8c79063c70fc3821e88d2bdb2ca0d76e8d346192';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {'X-API-Key': _apiKey},
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      responseType: ResponseType.json,
    ),
  );

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) return jsonDecode(data) as Map<String, dynamic>;
    throw Exception('Invalid server response');
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      path,
      data: payload,
      options: Options(contentType: Headers.jsonContentType),
    );
    return _asMap(response.data);
  }

  static Future<Map<String, dynamic>> uploadFile(
      File file, String folderPath) async {
    try {
      final formData = FormData.fromMap({
        'folder_path': folderPath,
        'file': await MultipartFile.fromFile(file.path),
      });
      final response = await _dio.post(
        '/upload.php',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return _asMap(response.data);
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Upload failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Upload failed: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> uploadFiles(
    List<PlatformFile> files,
    String folderPath,
  ) async {
    if (files.isEmpty) return [];
    final results = <Map<String, dynamic>>[];

    for (final file in files) {
      try {
        MultipartFile multipart;
        if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
          multipart = await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
          );
        } else if (file.bytes != null) {
          multipart = MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
          );
        } else {
          throw Exception('Could not read file: ${file.name}');
        }

        final formData = FormData.fromMap({
          'folder_path': folderPath,
          'file': multipart,
        });
        final response = await _dio.post(
          '/upload.php',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        results.add(_asMap(response.data));
      } on DioException catch (e) {
        final body = _asMap(e.response?.data ?? '{}');
        throw Exception(
            'Upload failed for ${file.name}: ${body['error'] ?? 'Upload failed'}');
      }
    }
    return results;
  }

  static Future<List<Map<String, dynamic>>> listFiles(
      String folderPath) async {
    try {
      final response = await _dio.get(
        '/list_files.php',
        queryParameters: {'path': folderPath},
      );
      final body = _asMap(response.data);
      return List<Map<String, dynamic>>.from(body['data']);
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Failed to list files');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to list files: $e');
    }
  }

  static Future<Map<String, dynamic>> createFolder(
      String folderName, String parentPath) async {
    try {
      return _postJson('/create_folder.php', {
        'folder_name': folderName,
        'parent_path': parentPath,
      });
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Failed to create folder');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to create folder: $e');
    }
  }

  static Future<Map<String, dynamic>> renameItem(
      String oldPath, String newName) async {
    try {
      return _postJson('/rename.php', {
        'old_path': oldPath,
        'new_name': newName,
      });
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Rename failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Rename failed: $e');
    }
  }

  static Future<Map<String, dynamic>> moveItem(
      String sourcePath, String destinationPath) async {
    try {
      return _postJson('/move.php', {
        'source_path': sourcePath,
        'destination_path': destinationPath,
      });
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Move failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Move failed: $e');
    }
  }

  static Future<File> downloadFile(String fileUrl, String savePath) async {
    try {
      await _dio.download(
        '/download.php',
        savePath,
        queryParameters: {'file': fileUrl},
      );
      final file = File(savePath);
      return file;
    } on DioException catch (_) {
      throw Exception('Download failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Download failed: $e');
    }
  }

  static Future<Uint8List> downloadBytes(String filePath) async {
    try {
      final response = await _dio.get<List<int>>(
        '/download.php',
        queryParameters: {'file': filePath},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? <int>[]);
    } on DioException catch (_) {
      throw Exception('Download failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Download failed: $e');
    }
  }

  static Future<Map<String, dynamic>> setFolderPassword(
      String folderPath, String password) async {
    try {
      debugPrint(
          '[ApiService] setFolderPassword -> /set_password.php folder=$folderPath');
      final body = await _postJson('/set_password.php', {
        'folder_path': folderPath,
        'password': password,
      });
      debugPrint('[ApiService] setFolderPassword body=$body');
      return body;
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Failed to set password');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to set password: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyFolderPassword(
      String folderPath, String password) async {
    try {
      debugPrint(
          '[ApiService] verifyFolderPassword -> /verify_password.php folder=$folderPath');
      final body = await _postJson('/verify_password.php', {
        'folder_path': folderPath,
        'password': password,
      });
      debugPrint('[ApiService] verifyFolderPassword body=$body');
      return body;
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Verification failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Verification failed: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteItem(String path) async {
    try {
      return _postJson('/delete.php', {'path': path});
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Delete failed');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Delete failed: $e');
    }
  }

  static Future<bool> hasFolderPassword(String folderPath) async {
    try {
      debugPrint('[ApiService] hasFolderPassword -> /has_password.php');
      final response = await _dio.get(
        '/has_password.php',
        queryParameters: {'folder_path': folderPath},
      );
      final body = _asMap(response.data);
      debugPrint('[ApiService] hasFolderPassword body=$body');
      return body['has_password'] == true;
    } on DioException catch (e) {
      final body = _asMap(e.response?.data ?? '{}');
      throw Exception(body['error'] ?? 'Failed to check password');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to check password: $e');
    }
  }
}
