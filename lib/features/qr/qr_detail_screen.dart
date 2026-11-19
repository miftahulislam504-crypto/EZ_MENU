import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Placeholder until this Phase 1 screen is built.
class QrDetailScreen extends StatelessWidget {
  const QrDetailScreen({super.key, required this.qrId});

  final String qrId;

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'QR code',
      icon: Icons.qr_code_2_rounded,
    );
  }
}
