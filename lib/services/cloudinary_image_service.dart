import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Upload helper for both images and raw/media files using Cloudinary unsigned uploads.
class CloudinaryImageService {
  /// Cloud name from your Cloudinary account.
  final String cloudName;

  /// Unsigned upload preset name.
  final String uploadPreset;

  /// Example: `https://api.cloudinary.com/v1_1/<cloud_name>/image/upload`
  String get _imageUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Example: `https://api.cloudinary.com/v1_1/<cloud_name>/raw/upload`
  String get _rawUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/raw/upload';

  const CloudinaryImageService({
    required this.cloudName,
    required this.uploadPreset,
  });

  /// Uploads an image to Cloudinary.
  ///
  /// Returns `secure_url` from Cloudinary response.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    Duration? timeout,
  }) async {
    return _upload(
      bytes: bytes,
      fileName: fileName,
      uploadUrl: _imageUploadUrl,
      timeout: timeout,
    );
  }

  /// Uploads non-image files (PDFs, documents, etc.) to Cloudinary as `raw`.
  ///
  /// Returns `secure_url` from Cloudinary response.
  Future<String> uploadRawFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return _upload(bytes: bytes, fileName: fileName, uploadUrl: _rawUploadUrl);
  }

  Future<String> _upload({
    required Uint8List bytes,
    required String fileName,
    required String uploadUrl,
    Duration? timeout,
  }) async {
    final client = http.Client();
    try {
      final operation = _sendUpload(
        client: client, bytes: bytes, fileName: fileName, uploadUrl: uploadUrl,
      );
      return await (timeout == null ? operation : operation.timeout(timeout));
    } finally {
      client.close();
    }
  }

  Future<String> _sendUpload({
    required http.Client client,
    required Uint8List bytes,
    required String fileName,
    required String uploadUrl,
  }) async {
    final uri = Uri.parse(uploadUrl);

    // Cloudinary expects multipart/form-data.
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;

    // Helps Cloudinary store/display properly.
    request.fields['public_id'] = _safePublicId(fileName);

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamedResponse = await client.send(request);
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      throw Exception(
        'Cloudinary upload failed (${streamedResponse.statusCode}): $responseBody',
      );
    }

    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final secureUrl = decoded['secure_url'];
    if (secureUrl is String && secureUrl.isNotEmpty) {
      return secureUrl;
    }

    final url = decoded['url'];
    if (url is String && url.isNotEmpty) {
      // Fallback if secure_url is not present.
      return url;
    }

    throw Exception(
      'Cloudinary upload succeeded but no URL was returned: $decoded',
    );
  }

  String _safePublicId(String input) {
    // Remove extension and keep it simple.
    final noExt = input.replaceAll(RegExp(r'\.[^\.]+$'), '');
    // Replace unsupported chars.
    return noExt.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}
