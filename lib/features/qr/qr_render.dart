import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/menu_palette.dart';
import 'qr_logic.dart';

/// Draws QR codes and printable cards to PNG with `dart:ui`.
///
/// Text is drawn by the Flutter engine, which shapes Bangla correctly. (The
/// PDF library cannot, so the PDF only places these images.)

/// What one printable card shows.
class QrCardSpec {
  const QrCardSpec({
    required this.link,
    required this.title,
    required this.businessName,
    required this.accent,
    this.subtitle,
    this.logo,
  });

  /// Address the QR code opens.
  final String link;

  /// Big text: "Table 5", "Takeaway counter" or the branch name.
  final String title;
  final String? subtitle;
  final String businessName;

  /// Brand colour of the top band.
  final Color accent;

  /// Restaurant logo, shown in the band and in the middle of the code.
  final ui.Image? logo;
}

// ---- logo ------------------------------------------------------------------------

/// Downloads and decodes the logo. Returns null when it is missing, too slow
/// or not a picture Flutter can decode (for example an SVG), so the card is
/// still produced without it.
Future<ui.Image?> loadLogoImage(String? url) async {
  final address = url?.trim();
  if (address == null || address.isEmpty) return null;
  final uri = Uri.tryParse(address);
  if (uri == null) return null;
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
    final codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: 256);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

// ---- fonts -----------------------------------------------------------------------------

const String _fontFamily = 'Anek Bangla';

TextStyle _style(double size, FontWeight weight, Color color, {double height = 1.3}) {
  return GoogleFonts.getFont(
    _fontFamily,
    textStyle: TextStyle(fontSize: size, fontWeight: weight, color: color, height: height),
  );
}

// ---- drawing helpers ----------------------------------------------------------------

/// Paints [text] and returns its height. Text is clipped to [maxLines].
double _paintText(
  ui.Canvas canvas,
  String text,
  TextStyle style, {
  required double x,
  required double y,
  required double width,
  TextAlign align = TextAlign.center,
  int maxLines = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: '...',
  )..layout(minWidth: width, maxWidth: width);
  painter.paint(canvas, Offset(x, y));
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Width the text really needs, capped at [maxWidth].
double _measure(String text, TextStyle style, double maxWidth) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  final width = painter.width;
  painter.dispose();
  return width;
}

void _paintLogo(ui.Canvas canvas, ui.Image logo, Rect rect, {required double radius}) {
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  paintImage(canvas: canvas, rect: rect, image: logo, fit: BoxFit.cover, filterQuality: FilterQuality.high);
  canvas.restore();
}

/// Draws the QR modules for [data] into [rect]. With a [logo] a white plate and
/// the logo are drawn over the middle; the code then uses the highest error
/// correction so it still scans.
void _paintQr(ui.Canvas canvas, String data, Rect rect, {ui.Image? logo}) {
  final ink = MenuPalette.light.ink;
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: logo == null ? QrErrorCorrectLevel.M : QrErrorCorrectLevel.H,
    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
    dataModuleStyle: QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: ink,
    ),
  );
  canvas.save();
  canvas.translate(rect.left, rect.top);
  painter.paint(canvas, rect.size);
  canvas.restore();

  if (logo != null) {
    final plateSide = rect.width * 0.24;
    final logoSide = plateSide * 0.8;
    final center = rect.center;
    final plate = Rect.fromCenter(center: center, width: plateSide, height: plateSide);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(plateSide * 0.22)),
      Paint()..color = MenuPalette.light.paper,
    );
    _paintLogo(
      canvas,
      logo,
      Rect.fromCenter(center: center, width: logoSide, height: logoSide),
      radius: logoSide * 0.2,
    );
  }
}

Future<Uint8List> _finish(ui.PictureRecorder recorder, int width, int height) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('The picture could not be encoded.');
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

// ---- plain code --------------------------------------------------------------------

/// A square PNG of just the code on white with a quiet zone, ready to place
/// in a design tool or print shop file.
Future<Uint8List> renderQrPng(String data, {int size = 1024, ui.Image? logo}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final side = size.toDouble();
  canvas.drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = MenuPalette.light.paper);
  final margin = side * 0.07;
  _paintQr(canvas, data, Rect.fromLTWH(margin, margin, side - margin * 2, side - margin * 2), logo: logo);
  return _finish(recorder, size, size);
}

// ---- printable card -------------------------------------------------------------------

/// Pixel size of a card rendered for [aspect] (width over height) at [width].
({int width, int height}) cardPixelSize(double aspect, int width) {
  final safe = aspect <= 0 ? 0.7 : aspect;
  return (width: width, height: (width / safe).round());
}

/// A card with the restaurant band, title, code and instructions in English
/// and Bangla. [aspect] is width over height of the printed area, so the card
/// fills its cell on the page. [pixelWidth] sets the sharpness.
Future<Uint8List> renderQrCard(QrCardSpec spec, {double aspect = 0.7, int pixelWidth = 1080}) async {
  final landscape = aspect >= 1.25;
  final logicalWidth = landscape ? 560.0 : 360.0;
  final logicalHeight = logicalWidth / (aspect <= 0 ? 0.7 : aspect);
  final size = cardPixelSize(aspect, pixelWidth);

  final fonts = _CardFonts();
  // Fonts download on first use; wait so the first card is not drawn with a
  // fallback face.
  try {
    await GoogleFonts.pendingFonts();
  } catch (_) {}

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(size.width / logicalWidth, size.height / logicalHeight);
  _paintCard(canvas, spec, fonts, Size(logicalWidth, logicalHeight), landscape: landscape);
  return _finish(recorder, size.width, size.height);
}

class _CardFonts {
  _CardFonts()
    : business = _style(17, FontWeight.w700, MenuPalette.light.ink),
      title = _style(30, FontWeight.w800, MenuPalette.light.ink, height: 1.2),
      titleSmall = _style(25, FontWeight.w800, MenuPalette.light.ink, height: 1.2),
      subtitle = _style(13, FontWeight.w500, MenuPalette.light.muted),
      instructionEn = _style(15, FontWeight.w700, MenuPalette.light.ink),
      instructionBn = _style(13, FontWeight.w500, MenuPalette.light.muted),
      footer = _style(11, FontWeight.w500, MenuPalette.light.muted);

  final TextStyle business;
  final TextStyle title;
  final TextStyle titleSmall;
  final TextStyle subtitle;
  final TextStyle instructionEn;
  final TextStyle instructionBn;
  final TextStyle footer;
}

void _paintCard(
  ui.Canvas canvas,
  QrCardSpec spec,
  _CardFonts fonts,
  Size size, {
  required bool landscape,
}) {
  final palette = MenuPalette.light;
  final width = size.width;
  final height = size.height;
  final compact = !landscape && height < 440;
  const radius = 20.0;
  final cardRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, height), const Radius.circular(radius));

  // Card body.
  canvas.drawRRect(cardRect, Paint()..color = palette.paper);
  canvas.save();
  canvas.clipRRect(cardRect);

  // Band with the restaurant name.
  final bandHeight = compact || landscape ? 60.0 : 78.0;
  canvas.drawRect(Rect.fromLTWH(0, 0, width, bandHeight), Paint()..color = spec.accent);
  final onAccent = onColor(spec.accent);
  final bandText = fonts.business.copyWith(color: onAccent);
  final logoSide = bandHeight - 24;
  const bandGap = 10.0;
  final textRoom = width - 48 - (spec.logo == null ? 0 : logoSide + bandGap);
  final textWidth = _measure(spec.businessName, bandText, textRoom);
  final groupWidth = (spec.logo == null ? 0 : logoSide + bandGap) + textWidth;
  var cursor = (width - groupWidth) / 2;
  if (spec.logo != null) {
    _paintLogo(
      canvas,
      spec.logo!,
      Rect.fromLTWH(cursor, (bandHeight - logoSide) / 2, logoSide, logoSide),
      radius: logoSide / 2,
    );
    cursor += logoSide + bandGap;
  }
  _paintText(
    canvas,
    spec.businessName,
    bandText,
    x: cursor,
    y: (bandHeight - 17 * 1.3) / 2,
    width: math.max(textWidth, 1),
    align: TextAlign.start,
  );

  if (landscape) {
    _paintLandscapeBody(canvas, spec, fonts, size, bandHeight);
  } else {
    _paintPortraitBody(canvas, spec, fonts, size, bandHeight, compact: compact);
  }
  canvas.restore();

  // Hairline border drawn last so it sits over the band.
  canvas.drawRRect(
    cardRect.deflate(0.5),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = palette.line,
  );
}

/// White frame with an accent outline that holds the code.
Rect _paintQrFrame(ui.Canvas canvas, QrCardSpec spec, Rect outer) {
  final frame = RRect.fromRectAndRadius(outer, const Radius.circular(16));
  canvas.drawRRect(frame, Paint()..color = MenuPalette.light.paper);
  canvas.drawRRect(
    frame,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = spec.accent,
  );
  return outer.deflate(12);
}

void _paintPortraitBody(
  ui.Canvas canvas,
  QrCardSpec spec,
  _CardFonts fonts,
  Size size,
  double bandHeight, {
  required bool compact,
}) {
  final width = size.width;
  final height = size.height;
  const side = 24.0;
  final contentWidth = width - side * 2;
  var y = bandHeight + (compact ? 12 : 20);

  y += _paintText(
    canvas,
    spec.title,
    compact ? fonts.titleSmall : fonts.title,
    x: side,
    y: y,
    width: contentWidth,
  );
  final subtitle = spec.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) {
    y += 2 + _paintText(canvas, subtitle, fonts.subtitle, x: side, y: y + 2, width: contentWidth);
  }
  y += compact ? 8 : 14;

  // Space left for the code frame, the two instruction lines and the footer.
  final instructionsHeight = 15 * 1.3 + 4 + 13 * 1.3;
  final footerHeight = compact ? 0.0 : 11 * 1.3 + 8;
  final reserved = instructionsHeight + footerHeight + (compact ? 22 : 34);
  final frameSide = math.max(
    120.0,
    math.min(width - side * 2, height - y - reserved),
  );
  final frame = Rect.fromLTWH((width - frameSide) / 2, y, frameSide, frameSide);
  final qrRect = _paintQrFrame(canvas, spec, frame);
  _paintQr(canvas, spec.link, qrRect, logo: spec.logo);
  y = frame.bottom + (compact ? 10 : 16);

  y += _paintText(canvas, qrInstructionEnglish, fonts.instructionEn, x: side, y: y, width: contentWidth);
  y += 4;
  _paintText(canvas, qrInstructionBangla, fonts.instructionBn, x: side, y: y, width: contentWidth);

  if (!compact) {
    _paintText(
      canvas,
      _shortLink(spec.link),
      fonts.footer,
      x: side,
      y: height - 11 * 1.3 - 16,
      width: contentWidth,
    );
  }
}

void _paintLandscapeBody(
  ui.Canvas canvas,
  QrCardSpec spec,
  _CardFonts fonts,
  Size size,
  double bandHeight,
) {
  final width = size.width;
  final height = size.height;
  const pad = 28.0;
  final frameSide = math.max(120.0, height - bandHeight - pad * 2);
  final frame = Rect.fromLTWH(pad, bandHeight + pad, frameSide, frameSide);
  final qrRect = _paintQrFrame(canvas, spec, frame);
  _paintQr(canvas, spec.link, qrRect, logo: spec.logo);

  final textX = frame.right + pad;
  final textWidth = width - textX - pad;
  var y = bandHeight + pad + 4;
  y += _paintText(canvas, spec.title, fonts.title, x: textX, y: y, width: textWidth, align: TextAlign.start);
  final subtitle = spec.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) {
    y += 2 + _paintText(canvas, subtitle, fonts.subtitle, x: textX, y: y + 2, width: textWidth, align: TextAlign.start);
  }
  y += 22;
  y += _paintText(
    canvas,
    qrInstructionEnglish,
    fonts.instructionEn,
    x: textX,
    y: y,
    width: textWidth,
    align: TextAlign.start,
  );
  y += 4;
  _paintText(
    canvas,
    qrInstructionBangla,
    fonts.instructionBn,
    x: textX,
    y: y,
    width: textWidth,
    align: TextAlign.start,
  );
  _paintText(
    canvas,
    _shortLink(spec.link),
    fonts.footer,
    x: textX,
    y: height - 11 * 1.3 - pad,
    width: textWidth,
    align: TextAlign.start,
  );
}

/// The link without "https://" for the small line on the card.
String _shortLink(String link) {
  final uri = Uri.tryParse(link);
  if (uri == null || uri.host.isEmpty) return link;
  final path = uri.path == '/' ? '' : uri.path;
  return '${uri.host}$path';
}
