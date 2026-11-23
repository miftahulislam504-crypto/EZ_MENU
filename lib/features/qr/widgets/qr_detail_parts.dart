import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/widgets.dart';
import '../qr_logic.dart';
import '../qr_models.dart';

/// Which export is running, so its row can show a spinner.
enum QrBusy { png, plain, pdf, print, share, manage }

/// A row in the "Download and print" group. Shows a spinner while [busy].
class QrActionRow extends StatelessWidget {
  const QrActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: ListRow(
        leading: IconBadge(icon),
        title: title,
        subtitle: subtitle,
        onTap: enabled && !busy ? onTap : null,
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : (enabled ? null : const SizedBox.shrink()),
      ),
    );
  }
}

/// The facts about a code: kind, status, scans and dates.
class QrFacts extends StatelessWidget {
  const QrFacts({super.key, required this.detail, required this.branchName, required this.now});

  final QrDetail detail;
  final String branchName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final code = detail.code;
    final table = detail.table;
    final dateFormat = DateFormat('d MMM yyyy');
    final rows = <(String, String)>[
      ('Type', qrKindLabel(code.kind)),
      ('Branch', branchName),
      if (table != null) ('Table', table.name),
      if (table?.zone != null && table!.zone!.trim().isNotEmpty) ('Zone', table.zone!.trim()),
      ('Scans', '${code.scanCount}'),
      (
        'Last scanned',
        code.lastScannedAt == null ? 'Never' : relativeTime(code.lastScannedAt!, now),
      ),
      if (code.createdAt != null) ('Created', dateFormat.format(code.createdAt!.toLocal())),
      if (code.deactivatedAt != null)
        ('Switched off', dateFormat.format(code.deactivatedAt!.toLocal())),
    ];
    return ListGroup(
      title: 'Details',
      children: [
        for (final row in rows)
          ListRow(
            dense: true,
            title: row.$1,
            trailing: Text(
              row.$2,
              style: withTabularFigures(context.textStyles.bodyMedium!).copyWith(
                color: context.palette.muted,
              ),
            ),
          ),
      ],
    );
  }
}
