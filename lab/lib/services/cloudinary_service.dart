import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class CloudinaryService {
  static const String _cloudName = 'dj10hjric';
  static const String _apiKey = '663561673367414';
  static const String _apiSecret = '-A2PfkpPFPi7sNcAxcqpsaNWG5I';

  // ==================== UPLOAD GAMBAR ====================
  Future<Map<String, String>?> uploadImage({
    required File file,
    required String folder,
    String? publicId,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload"),
      );

      request.fields['upload_preset'] = 'inventory_upload';
      request.fields['folder'] = folder;
      if (publicId != null && publicId.isNotEmpty) {
        request.fields['public_id'] = publicId;
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        final urlMatch = RegExp(r'"secure_url":"([^"]+)"').firstMatch(responseString);
        final publicIdMatch = RegExp(r'"public_id":"([^"]+)"').firstMatch(responseString);

        final String? secureUrl = urlMatch?.group(1);
        final String? returnedPublicId = publicIdMatch?.group(1);

        if (secureUrl != null) {
          return {
            'url': secureUrl,
            'publicId': returnedPublicId ?? publicId ?? '',
          };
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Cloudinary upload error: $e');
      }
      return null;
    }
  }

  // ==================== HAPUS GAMBAR ====================
  Future<bool> deleteImage(String publicId) async {
    if (publicId.isEmpty) return false;

    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final String toSign = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
      final signature = sha1.convert(utf8.encode(toSign)).toString();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/destroy"),
      );

      request.fields['public_id'] = publicId;
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;

      final response = await request.send();
      final responseString = String.fromCharCodes(await response.stream.toBytes());

      return response.statusCode == 200 && responseString.contains('"result":"ok"');
    } catch (e) {
      if (kDebugMode) {
        print('Cloudinary delete error: $e');
      }
      return false;
    }
  }

  // ==================== HELPER BARU: UPLOAD + HAPUS GAMBAR LAMA OTOMATIS ====================
  /// Method ini sangat berguna untuk mengurangi duplikasi kode di ProfileScreen & TambahKategoriScreen
  Future<Map<String, String>?> uploadAndReplaceImage({
    required File file,
    required String folder,
    required String publicId,           // publicId baru
    String? oldPublicId,                // publicId lama (opsional)
  }) async {
    try {
      // 1. Hapus gambar lama jika ada
      if (oldPublicId != null && oldPublicId.isNotEmpty) {
        await deleteImage(oldPublicId);
      }

      // 2. Upload gambar baru
      return await uploadImage(
        file: file,
        folder: folder,
        publicId: publicId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Cloudinary uploadAndReplaceImage error: $e');
      }
      return null;
    }
  }
}