import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase/error_text.dart';
import '../../core/widgets/widgets.dart';
import 'qr_render.dart';

/// The restaurant logo decoded for the QR cards, by address. Null when the
/// restaurant has no logo or it cannot be used. Kept for the whole session so
/// each card does not download it again.
final qrLogoProvider = FutureProvider.family<ui.Image?, String?>((ref, url) {
  return loadLogoImage(url);
});

/// File formats the QR screens save.
enum QrFileKind {
  png('png', 'image/png'),
  pdf('pdf', 'application/pdf');

  const QrFileKind(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  MimeType get saverMime => this == QrFileKind.png ? MimeType.png : MimeType.pdf;
}

/// Saves [bytes] to the device (a download on the web) and says so.
Future<bool> saveQrFile(
  BuildContext context, {
  required String name,
  required Uint8List bytes,
  required QrFileKind kind,
  required String successMessage,
}) {
  return runWithToast(
    context,
    () async {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        ext: kind.extension,
        mimeType: kind.saverMime,
      );
    },
    onError: friendlyError,
    successMessage: successMessage,
  );
}

/// Opens the share sheet with [bytes] attached as a file.
Future<void> shareQrFile(
  BuildContext context, {
  required String name,
  required Uint8List bytes,
  required QrFileKind kind,
  String? subject,
}) async {
  try {
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: kind.mimeType, name: '$name.${kind.extension}')],
      subject: subject,
      fileNameOverrides: ['$name.${kind.extension}'],
    );
  } catch (_) {
    if (context.mounted) {
      showToast(context, 'Sharing is not available here. Use Download instead.', isError: true);
    }
  }
}
