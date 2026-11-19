import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/config/env.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/widgets.dart';

/// Short answers to the questions new restaurants ask first.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(String, String)> _answers = [
    (
      'How do customers open my menu?',
      'Print a QR code from QR & Tables and place it on tables, at the '
          'counter or on your door. Customers scan it with their phone camera. '
          'No app is needed. You can also share your menu link in a message or '
          'on social media.',
    ),
    (
      'I changed a price. When does it show?',
      'Right away. The customer menu always loads the latest version, so a new '
          'price or a sold-out item shows the next time someone opens or '
          'refreshes the menu.',
    ),
    (
      'An item ran out. What should I do?',
      'Open Menu, then Availability, and switch the item to sold out. You can '
          'choose a time for it to come back automatically, or sold out only '
          'for one branch.',
    ),
    (
      'Can each branch have its own prices?',
      'Yes. Open an item, go to the Branches section and set a price or '
          'availability for one branch. Other branches keep the main price.',
    ),
    (
      'I deleted something by mistake.',
      'Open Menu, then Trash. Deleted items and categories stay there until '
          'you remove them for good, and you can restore them.',
    ),
    (
      'A QR code was misused or printed wrongly.',
      'Open the code in QR & Tables and choose Regenerate. The old code stops '
          'working at once and a new one is created. You can also deactivate a '
          'code without replacing it.',
    ),
    (
      'My menu shows Bangla and English. Can I choose?',
      'Each food and category has a Bangla and an English name. Customers pick '
          'their language on the menu. Your default language is set in '
          'Restaurant profile.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Help & support',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListGroup(
            title: 'Common questions',
            children: [
              for (final entry in _answers)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      Sp.lg,
                      0,
                      Sp.lg,
                      Sp.lg,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    title: Text(entry.$1, style: context.textStyles.titleSmall),
                    children: [
                      Text(
                        entry.$2,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          ListGroup(
            title: 'More',
            children: [
              ListRow(
                leading: const IconBadge(Icons.description_outlined),
                title: 'Terms and privacy',
                subtitle: 'How EZ Menu handles your data',
                onTap: () => context.go(AppRoutes.legal),
              ),
              if (Env.supportEmail.isNotEmpty)
                ListRow(
                  leading: const IconBadge(Icons.mail_outline_rounded),
                  title: 'Email support',
                  subtitle: Env.supportEmail,
                  onTap: () => openUrl('mailto:${Env.supportEmail}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
