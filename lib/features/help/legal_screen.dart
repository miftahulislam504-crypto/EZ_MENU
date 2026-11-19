import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Terms and privacy summary. The text is a plain-language starting point and
/// should be replaced with the reviewed legal copy before public launch.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const List<(String, String)> _sections = [
    (
      'Your account',
      'You are responsible for the accuracy of your restaurant details and for '
          'keeping your sign-in private. Only people you give access to can '
          'change your menu.',
    ),
    (
      'Your menu content',
      'The names, prices, photos and descriptions you publish belong to you. '
          'You confirm that you have the right to use the images you upload. '
          'Allergen and dietary information you enter is shown to customers, so '
          'keep it accurate.',
    ),
    (
      'What we store',
      'We store your account email, restaurant and branch details, menu, '
          'images and QR codes so the service can run. QR codes count scans so '
          'you can see how often a code is used. Customers browsing your menu '
          'do not need an account and we do not collect their personal details '
          'in this release.',
    ),
    (
      'Your control',
      'You can edit or remove your menu content at any time. Deleted items '
          'stay in Trash until you remove them for good. Contact support to '
          'export or delete your account data.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Terms and privacy',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final section in _sections)
            FormSection(
              title: section.$1,
              children: [
                Text(section.$2, style: context.textStyles.bodyMedium),
              ],
            ),
        ],
      ),
    );
  }
}
