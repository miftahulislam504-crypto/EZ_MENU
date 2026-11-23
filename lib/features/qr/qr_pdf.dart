import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'qr_logic.dart';

/// Lays finished card pictures out on A4 pages for printing or saving as a
/// PDF. The cards are drawn by `qr_render.dart` (so Bangla text is correct);
/// this file only places them in a grid with a dashed cut line around each.

final PdfPageFormat _a4 = PdfPageFormat(a4Width, a4Height);

/// One PDF holding [cards] ([PNG] bytes), [grid.perPage] to a page.
Future<Uint8List> buildQrPdf({
  required List<Uint8List> cards,
  required PrintGrid grid,
  String title = 'QR codes',
}) async {
  final document = pw.Document(title: title, author: 'EZ Menu', creator: 'EZ Menu');
  final images = [for (final bytes in cards) pw.MemoryImage(bytes)];

  // A hair smaller than the printable area so rounding never overflows a page.
  final cellWidth = grid.cardWidth - 0.05;
  final cellHeight = grid.cardHeight - 0.05;

  for (final page in paginate(images, grid.perPage)) {
    final rows = <pw.Widget>[];
    for (var start = 0; start < page.length; start += grid.columns) {
      final end = start + grid.columns > page.length ? page.length : start + grid.columns;
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final image in page.sublist(start, end))
              pw.Container(
                width: cellWidth,
                height: cellHeight,
                padding: const pw.EdgeInsets.all(printCardInset),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey500,
                    width: 0.5,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
          ],
        ),
      );
    }
    document.addPage(
      pw.Page(
        pageFormat: _a4,
        margin: const pw.EdgeInsets.all(printMargin),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: rows,
        ),
      ),
    );
  }
  return document.save();
}

/// Opens the system print dialog (or the browser print preview on the web).
Future<void> printQrPdf(Uint8List pdf, {String name = 'QR codes'}) async {
  await Printing.layoutPdf(
    name: name,
    format: _a4,
    onLayout: (format) async => pdf,
  );
}

/// Opens the share sheet with the PDF attached.
Future<void> shareQrPdf(Uint8List pdf, String fileName) async {
  await Printing.sharePdf(bytes: pdf, filename: '$fileName.pdf');
}
