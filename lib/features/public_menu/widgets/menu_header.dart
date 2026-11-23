import 'package:flutter/material.dart';

import '../../../core/widgets/images.dart';
import '../public_menu_logic.dart';
import '../public_menu_models.dart';
import 'menu_scope.dart';

/// "EN | বাংলা" switch. Both labels are always shown in their own script.
class MenuLanguageToggle extends StatelessWidget {
  const MenuLanguageToggle({super.key, required this.bangla, required this.onChanged});

  final bool bangla;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    Widget segment(String label, bool selected, bool value) {
      return Semantics(
        button: true,
        selected: selected,
        label: value ? 'Bangla' : 'English',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? menu.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: menu.text(
                12.5,
                weight: FontWeight.w700,
                color: selected ? menu.onBrand : menu.palette.muted,
                height: 1.1,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: menu.palette.paper.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: menu.palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [segment('EN', !bangla, false), segment('বাংলা', bangla, true)],
      ),
    );
  }
}

/// A round button on the cover (info, back).
class MenuRoundButton extends StatelessWidget {
  const MenuRoundButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: menu.palette.paper.withValues(alpha: 0.94),
        shape: CircleBorder(side: BorderSide(color: menu.palette.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20, color: menu.palette.ink)),
        ),
      ),
    );
  }
}

/// Cover, logo, name, branch, opening status and welcome note.
class MenuHeader extends StatelessWidget {
  const MenuHeader({
    super.key,
    required this.data,
    required this.onLanguage,
    required this.onInfo,
    this.onBranches,
  });

  final PublicMenuData data;
  final ValueChanged<bool> onLanguage;
  final VoidCallback onInfo;

  /// Opens the branch list. Null hides the "Change branch" button.
  final VoidCallback? onBranches;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final bangla = menu.bangla;
    final business = data.business;
    final name = businessDisplayName(business, bangla: bangla);
    final branchName = branchDisplayName(data.branch, bangla: bangla);
    final area = data.branch.area?.trim();
    final place = [
      if (branchName.isNotEmpty) branchName,
      if (area != null && area.isNotEmpty && area != branchName) area,
    ].join(', ');
    final welcome = welcomeText(business, bangla: bangla);
    final tableLabel = contextLabel(data.context, bangla: bangla);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Cover(url: business.coverUrl),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MenuLanguageToggle(bangla: bangla, onChanged: onLanguage),
                  const SizedBox(width: 8),
                  MenuRoundButton(
                    icon: Icons.info_outline_rounded,
                    label: bangla ? 'তথ্য' : 'Information',
                    onTap: onInfo,
                  ),
                ],
              ),
            ),
            Positioned(left: 16, bottom: -34, child: _Logo(url: business.logoUrl, name: name)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 44, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: menu.text(24, weight: FontWeight.w800, height: 1.2)),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 15, color: menu.palette.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: menu.text(13, color: menu.palette.muted),
                      ),
                    ),
                    if (onBranches != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onBranches,
                        child: Text(
                          bangla ? 'শাখা বদলান' : 'Change',
                          style: menu.text(13, weight: FontWeight.w700, color: menu.accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(data: data),
                  if (tableLabel != null) _ContextChip(label: tableLabel, takeaway: data.context.isTakeaway),
                ],
              ),
              if (welcome != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: menu.palette.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(welcome, style: menu.text(13.5, height: 1.45)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    const height = 150.0;
    if (url != null && url!.trim().isNotEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: NetworkImageBox(url: url, height: height, radius: 0, cacheWidth: 720),
      );
    }
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [menu.brand, Color.lerp(menu.brand, menu.palette.ink, 0.4)!],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    const size = 68.0;
    final hasLogo = url != null && url!.trim().isNotEmpty;
    final letter = name.trim().isEmpty ? '?' : String.fromCharCode(name.trim().runes.first);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: menu.brand,
        border: Border.all(color: menu.palette.paper, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasLogo
          ? NetworkImageBox(url: url, width: size, height: size, radius: size, cacheWidth: 140)
          : Text(letter, style: menu.text(28, weight: FontWeight.w800, color: menu.onBrand, height: 1)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.data});

  final PublicMenuData data;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    final status = data.status;
    final Color tone = status.isOpen
        ? menu.palette.open
        : (status.isTemporarilyClosed ? menu.palette.caution : menu.palette.closed);
    final headline = statusHeadline(status, bangla: menu.bangla);
    final detail = statusDetail(data, bangla: menu.bangla);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: headline, style: menu.text(12.5, weight: FontWeight.w700, color: tone, height: 1.2)),
                  if (detail != null)
                    TextSpan(
                      text: '  $detail',
                      style: menu.text(12.5, color: menu.palette.muted, height: 1.2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.takeaway});

  final String label;
  final bool takeaway;

  @override
  Widget build(BuildContext context) {
    final menu = context.menu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: menu.brand, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            takeaway ? Icons.shopping_bag_outlined : Icons.table_restaurant_outlined,
            size: 15,
            color: menu.onBrand,
          ),
          const SizedBox(width: 6),
          Text(label, style: menu.text(12.5, weight: FontWeight.w700, color: menu.onBrand, height: 1.2)),
        ],
      ),
    );
  }
}
