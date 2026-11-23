import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';
import '../qr_logic.dart';
import '../qr_models.dart';

/// Three small numbers at the top of the QR and tables screen.
class QrSummaryRow extends StatelessWidget {
  const QrSummaryRow({
    super.key,
    required this.activeCodes,
    required this.totalScans,
    required this.tableCount,
  });

  final int activeCodes;
  final int totalScans;
  final int tableCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Tile(icon: Icons.qr_code_2_rounded, value: '$activeCodes', label: 'Active codes')),
        const SizedBox(width: Sp.md),
        Expanded(child: _Tile(icon: Icons.qr_code_scanner_rounded, value: '$totalScans', label: 'Scans')),
        const SizedBox(width: Sp.md),
        Expanded(child: _Tile(icon: Icons.table_restaurant_outlined, value: '$tableCount', label: 'Tables')),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(height: Sp.sm),
          Text(value, style: withTabularFigures(context.textStyles.titleLarge!)),
          Text(label, style: context.textStyles.bodySmall?.copyWith(color: palette.muted)),
        ],
      ),
    );
  }
}

/// A branch or takeaway code in the "Menu codes" group. Without a code the
/// row offers to create one.
class QrCodeRow extends StatelessWidget {
  const QrCodeRow({
    super.key,
    required this.icon,
    required this.title,
    required this.emptyHint,
    required this.code,
    required this.now,
    required this.creating,
    required this.onOpen,
    required this.onCreate,
  });

  final IconData icon;
  final String title;
  final String emptyHint;
  final QrCode? code;
  final DateTime now;
  final bool creating;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final current = code;
    if (current == null) {
      return ListRow(
        leading: IconBadge(
          icon,
          color: context.palette.muted,
          background: context.colors.surfaceContainerHigh,
        ),
        title: title,
        subtitle: emptyHint,
        trailing: AppButton(
          label: 'Create',
          kind: AppButtonKind.tonal,
          loading: creating,
          onPressed: onCreate,
        ),
      );
    }
    return ListRow(
      leading: IconBadge(icon),
      title: title,
      subtitle: scanSummary(current.scanCount, current.lastScannedAt, now),
      trailing: const StatusPill('Active', tone: PillTone.success),
      onTap: onOpen,
    );
  }
}

enum TableAction { viewCode, createCode, edit, toggle, delete }

/// One table in the list: name, seats and scans, with a menu of actions.
class TableRowTile extends StatelessWidget {
  const TableRowTile({
    super.key,
    required this.table,
    required this.code,
    required this.now,
    required this.onOpen,
    required this.onAction,
  });

  final RestaurantTable table;
  final QrCode? code;
  final DateTime now;
  final VoidCallback onOpen;
  final ValueChanged<TableAction> onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = <String>[
      if (table.capacity != null) '${table.capacity} ${table.capacity == 1 ? 'seat' : 'seats'}',
      if (code != null) scanSummary(code!.scanCount, code!.lastScannedAt, now) else 'No active code',
    ];
    return ListRow(
      leading: IconBadge(
        Icons.table_restaurant_outlined,
        color: table.isActive ? null : palette.muted,
        background: table.isActive ? null : context.colors.surfaceContainerHigh,
      ),
      title: table.name,
      subtitle: parts.join(', '),
      titleColor: table.isActive ? null : palette.muted,
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!table.isActive) const StatusPill('Off'),
          PopupMenuButton<TableAction>(
            tooltip: 'Table actions',
            icon: Icon(Icons.more_vert_rounded, color: palette.muted),
            onSelected: onAction,
            itemBuilder: (context) => [
              if (code != null)
                const PopupMenuItem(value: TableAction.viewCode, child: Text('View QR code'))
              else
                const PopupMenuItem(value: TableAction.createCode, child: Text('Create QR code')),
              const PopupMenuItem(value: TableAction.edit, child: Text('Edit table')),
              PopupMenuItem(
                value: TableAction.toggle,
                child: Text(table.isActive ? 'Turn off' : 'Turn on'),
              ),
              PopupMenuItem(
                value: TableAction.delete,
                child: Text('Delete', style: TextStyle(color: palette.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warns when the web address of the menu site is not known, because every
/// code points at it.
class QrLinkWarning extends StatelessWidget {
  const QrLinkWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.lg),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: palette.warningSoft,
        borderRadius: BorderRadius.circular(Rad.panel),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.warning, size: 20),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              'The web address of your menu site is not set, so QR codes made '
              'here may point to an incomplete link. Set PUBLIC_BASE_URL when '
              'building the app.',
              style: context.textStyles.bodySmall?.copyWith(color: palette.warning),
            ),
          ),
        ],
      ),
    );
  }
}
