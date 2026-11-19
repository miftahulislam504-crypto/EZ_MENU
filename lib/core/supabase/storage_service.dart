import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'error_text.dart';
import 'supabase_providers.dart';

/// Storage buckets created by the migrations. Both are public-read.
enum AppBucket {
  brand('brand-assets'),
  menu('menu-images');

  const AppBucket(this.id);
  final String id;
}

/// An image problem with a message already written for people.
class ImageUploadException extends AppException {
  const ImageUploadException(super.message);
}

/// Picks an image, shrinks it, uploads it to Storage and returns its public
/// address.
///
/// Files go to `<business_id>/<folder>/<uuid>.<ext>`; the storage policies only
/// allow members to write inside their own business folder.
class ImageUploadService {
  ImageUploadService(this._client, [ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final SupabaseClient _client;
  final ImagePicker _picker;

  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> _allowed = {'jpg', 'jpeg', 'png', 'webp'};

  /// Returns the public URL, or null when the person cancelled.
  Future<String?> pickAndUpload({
    required String businessId,
    required AppBucket bucket,
    required String folder,
    ImageSource source = ImageSource.gallery,
    double maxDimension = 1600,
    int quality = 82,
  }) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
    );
    if (file == null) return null;

    final extension = _extensionOf(file);
    if (!_allowed.contains(extension)) {
      throw const ImageUploadException('Use a JPG, PNG or WebP image.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const ImageUploadException(
        'That image is too large. Use one under 5 MB.',
      );
    }

    final path = '$businessId/$folder/${const Uuid().v4()}.$extension';
    await _client.storage
        .from(bucket.id)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeFor(extension),
            cacheControl: '31536000',
            upsert: false,
          ),
        );
    return _client.storage.from(bucket.id).getPublicUrl(path);
  }

  /// Removes an uploaded file given its public URL. Never throws: a leftover
  /// file is harmless, a failed delete must not block the person.
  Future<void> deleteByUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    for (final bucket in AppBucket.values) {
      final marker = '/object/public/${bucket.id}/';
      final index = url.indexOf(marker);
      if (index < 0) continue;
      final path = Uri.decodeComponent(
        url.substring(index + marker.length).split('?').first,
      );
      try {
        await _client.storage.from(bucket.id).remove([path]);
      } catch (_) {
        // Ignore: see above.
      }
      return;
    }
  }

  static String _extensionOf(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    final mime = file.mimeType ?? '';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    return 'jpg';
  }

  static String _mimeFor(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>(
  (ref) => ImageUploadService(ref.watch(supabaseClientProvider)),
);
