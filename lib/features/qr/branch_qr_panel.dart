import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/session/models.dart';
import '../../core/supabase/error_text.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/utils/public_links.dart';
import '../../core/widgets/widgets.dart';

/// The token of the active menu QR code of a branch. A database trigger
/// creates it when the branch is created. Null when none is active.
final branchQrTokenProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, branchId) async {
      final rows = await ref
          .watch(supabaseClientProvider)
          .from('qr_codes')
          .select('token')
          .eq('branch_id', branchId)
          .eq('kind', 'branch')
          .eq('is_active', true)
          .limit(1);
      if (rows.isEmpty) return null;
      return rows.first['token'] as String?;
    });

/// A scannable QR code for a branch menu with copy and share actions.
class BranchQrPanel extends ConsumerWidget {
  const BranchQrPanel({super.key, required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(branchQrTokenProvider(branch.id));
    return token.when(
      skipLoadingOnReload: true,
      loading: () =>
          const Padding(padding: EdgeInsets.all(Sp.xl), child: LoadingView()),
      error: (error, _) => ErrorState(
        message: friendlyError(error),
        onRetry: () => ref.invalidate(branchQrTokenProvider(branch.id)),
      ),
      data: (value) {
        if (value == null) {
          return const EmptyState(
            icon: Icons.qr_code_2_rounded,
            title: 'No active QR code',
            message:
                'This branch has no active QR code. You can create one from '
                'the QR and tables tab.',
          );
        }
        final link = PublicLinks.qr(value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(Sp.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Rad.panel),
                  border: Border.all(color: context.palette.line),
                ),
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            SelectableText(
              link,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: Sp.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Copy link',
                    icon: Icons.copy_rounded,
                    kind: AppButtonKind.secondary,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) showToast(context, 'Link copied');
                    },
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: AppButton(
                    label: 'Share',
                    icon: Icons.ios_share_rounded,
                    kind: AppButtonKind.secondary,
                    onPressed: () =>
                        Share.share(link, subject: '${branch.name} menu'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
