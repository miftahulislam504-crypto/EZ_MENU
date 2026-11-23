import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/widgets/widgets.dart';
import '../qr_render.dart';

/// Shows the printable card exactly as it will be saved or printed, by
/// drawing it with the same code. While it is drawn a quiet placeholder
/// holds the space; if drawing fails the plain code is shown instead.
class QrCardPreview extends StatefulWidget {
  const QrCardPreview({
    super.key,
    required this.spec,
    this.aspect = 0.7,
    this.maxWidth = 300,
  });

  final QrCardSpec spec;

  /// Width over height of the card.
  final double aspect;
  final double maxWidth;

  @override
  State<QrCardPreview> createState() => _QrCardPreviewState();
}

class _QrCardPreviewState extends State<QrCardPreview> {
  Uint8List? _bytes;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(QrCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final a = oldWidget.spec;
    final b = widget.spec;
    final changed =
        a.link != b.link ||
        a.title != b.title ||
        a.subtitle != b.subtitle ||
        a.businessName != b.businessName ||
        a.accent != b.accent ||
        !identical(a.logo, b.logo) ||
        oldWidget.aspect != widget.aspect;
    if (changed) _render();
  }

  Future<void> _render() async {
    final generation = ++_generation;
    try {
      // About 2x the on-screen width keeps the preview sharp on phones.
      final bytes = await renderQrCard(
        widget.spec,
        aspect: widget.aspect,
        pixelWidth: (widget.maxWidth * 3).round(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Widget child;
    if (_failed) {
      child = Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Rad.panel),
          border: Border.all(color: palette.line),
        ),
        child: QrImageView(data: widget.spec.link, backgroundColor: Colors.white),
      );
    } else if (_bytes == null) {
      child = AspectRatio(
        aspectRatio: widget.aspect,
        child: SkeletonBox(radius: Rad.panel),
      );
    } else {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.panel),
          boxShadow: [
            BoxShadow(
              color: palette.line,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: child,
      ),
    );
  }
}
