import 'package:flutter/material.dart';

import '../../../core/utils/launch.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'menu_scope.dart';
import 'menu_sheet.dart';

IconData _contactIcon(ContactKind kind) {
  switch (kind) {
    case ContactKind.call:
      return Icons.call_outlined;
    case ContactKind.whatsapp:
      return Icons.chat_outlined;
    case ContactKind.email:
      return Icons.mail_outline_rounded;
    case ContactKind.map:
      return Icons.map_outlined;
    case ContactKind.website:
      return Icons.language_rounded;
    case ContactKind.facebook:
    case ContactKind.instagram:
    case ContactKind.tiktok:
    case ContactKind.youtube:
      return Icons.public_rounded;
  }
}

/// Opening hours, how to reach the restaurant, and its notes and policies.
class InfoSheet extends StatelessWidget {
  const InfoSheet({super.key, required this.data, required this.onClose});

  final PublicMenuData data;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final today = todayWeekdayFor(data.business.timezone, DateTime.now());
    final weekly = weeklyHoursLines(data, bangla: bangla, todayWeekday: today);
    final special = specialHoursLines(data, bangla: bangla);
    final contacts = contactActions(data, bangla: bangla);
    final address = displayAddress(data);
    final blocks = infoBlocks(data.business, bangla: bangla);
    final headline = statusHeadline(data.status, bangla: bangla);
    final detail = statusDetail(data, bangla: bangla);

    final sections = <Widget>[
      _Section(
        title: bangla ? 'এখনকার অবস্থা' : 'Right now',
        child: Text(
          detail == null ? headline : '$headline. $detail',
          style: menu.text(14.5, weight: FontWeight.w600, height: 1.45),
        ),
      ),
      if (weekly.isNotEmpty)
        _Section(
          title: bangla ? 'খোলার সময়' : 'Opening hours',
          child: Column(children: [for (final line in weekly) _HoursRow(line: line)]),
        ),
      if (special.isNotEmpty)
        _Section(
          title: bangla ? 'বিশেষ দিন' : 'Special days',
          child: Column(children: [for (final line in special) _HoursRow(line: line)]),
        ),
      if (address != null || contacts.isNotEmpty)
        _Section(
          title: bangla ? 'যোগাযোগ' : 'Contact',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (address != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.place_outlined, size: 18, color: menu.palette.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(address, style: menu.text(14, height: 1.45))),
                    ],
                  ),
                ),
              for (final action in contacts) _ContactRow(action: action),
            ],
          ),
        ),
      for (final block in blocks)
        _Section(
          title: block.title,
          child: Text(block.body, style: menu.text(13.5, color: menu.palette.ink, height: 1.55)),
        ),
    ];

    return MenuSheetFrame(
      title: bangla ? 'রেস্টুরেন্টের তথ্য' : 'Restaurant information',
      onClose: onClose,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 22),
              sections[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: menu.text(13, weight: FontWeight.w800, color: menu.palette.muted)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({required this.line});

  final HoursLine line;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final weight = line.isToday ? FontWeight.w800 : FontWeight.w500;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: line.isToday ? menu.palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(line.days, style: menu.text(14, weight: weight))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              line.times,
              textAlign: TextAlign.end,
              style: menu.text(14, weight: weight, color: line.closed ? menu.palette.closed : menu.palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.action});

  final ContactAction action;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Semantics(
      button: true,
      label: '${action.label}, ${action.value}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openUrl(action.url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: menu.palette.surface, shape: BoxShape.circle),
                child: Icon(_contactIcon(action.kind), size: 19, color: menu.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(action.label, style: menu.text(14, weight: FontWeight.w700)),
                    if (action.value.isNotEmpty)
                      Text(
                        action.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: menu.text(12.5, color: menu.palette.muted),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: menu.palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists the branches so a customer can open another one.
class BranchSheet extends StatelessWidget {
  const BranchSheet({super.key, required this.data, required this.onSelect, required this.onClose});

  final PublicMenuData data;
  final ValueChanged<PublicBranchLink> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    return MenuSheetFrame(
      title: bangla ? 'শাখা বেছে নিন' : 'Choose a branch',
      onClose: onClose,
      body: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (final branch in data.branches)
            _BranchRow(
              branch: branch,
              current: branch.slug == data.branch.slug,
              onTap: () => onSelect(branch),
            ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.branch, required this.current, required this.onTap});

  final PublicBranchLink branch;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final area = branch.area?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: current ? menu.palette.surface : menu.palette.paper,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: current ? menu.brand : menu.palette.line, width: current ? 1.5 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, color: menu.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branchLinkName(branch, bangla: bangla), style: menu.text(15, weight: FontWeight.w700)),
                      if (area != null && area.isNotEmpty)
                        Text(area, style: menu.text(12.5, color: menu.palette.muted)),
                    ],
                  ),
                ),
                if (current) Icon(Icons.check_circle_rounded, color: menu.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
