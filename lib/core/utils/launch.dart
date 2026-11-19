import 'package:url_launcher/url_launcher.dart';

/// Opens a web address, phone number or map link. Returns false on failure.
Future<bool> openUrl(String? url, {bool external = true}) async {
  if (url == null || url.trim().isEmpty) return false;
  var text = url.trim();
  if (!text.contains('://') &&
      !text.startsWith('tel:') &&
      !text.startsWith('mailto:')) {
    text = 'https://$text';
  }
  final uri = Uri.tryParse(text);
  if (uri == null) return false;
  try {
    return await launchUrl(
      uri,
      mode: external
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
  } catch (_) {
    return false;
  }
}

Future<bool> callPhone(String? phone) async {
  if (phone == null || phone.trim().isEmpty) return false;
  return openUrl('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
}
