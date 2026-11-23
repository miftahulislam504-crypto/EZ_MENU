import 'dart:typed_data';

import 'qr_logic.dart';
import 'qr_pdf.dart';
import 'qr_render.dart';

/// Draws every card and lays them out as one A4 PDF, [perPage] to a page.
/// [onProgress] is told how many cards are done so the screen can show it.
Future<Uint8List> buildPrintPdf({
  required List<QrCardSpec> cards,
  required int perPage,
  String title = 'QR codes',
  void Function(int done, int total)? onProgress,
}) async {
  final grid = printGridFor(perPage);
  final aspect = printCardAspect(grid);
  final width = printCardPixelWidth(grid);
  final pictures = <Uint8List>[];
  for (var i = 0; i < cards.length; i++) {
    pictures.add(await renderQrCard(cards[i], aspect: aspect, pixelWidth: width));
    onProgress?.call(i + 1, cards.length);
    // Give the screen a turn between cards so it stays responsive.
    await Future<void>.delayed(Duration.zero);
  }
  return buildQrPdf(cards: pictures, grid: grid, title: title);
}
