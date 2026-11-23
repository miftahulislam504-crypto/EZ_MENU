import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes.dart';
import '../../core/supabase/error_text.dart';
import '../../core/theme/menu_palette.dart';
import '../../core/widgets/widgets.dart';
import 'public_menu_logic.dart';
import 'public_menu_models.dart';
import 'public_menu_repository.dart';
import 'widgets/menu_states.dart';
import 'widgets/public_menu_view.dart';

/// The customer menu, opened from a QR code (`/q/<token>`) or a link
/// (`/m/<business>` and `/m/<business>/<branch>`). No sign in is needed.
class PublicMenuScreen extends ConsumerStatefulWidget {
  const PublicMenuScreen({
    super.key,
    this.businessSlug,
    this.branchSlug,
    this.qrToken,
  });

  final String? businessSlug;
  final String? branchSlug;
  final String? qrToken;

  @override
  ConsumerState<PublicMenuScreen> createState() => _PublicMenuScreenState();
}

class _PublicMenuScreenState extends ConsumerState<PublicMenuScreen> {
  static const String _languageKey = 'public_menu_language';

  bool? _savedBangla;
  bool _languageReady = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_languageKey);
      _savedBangla = saved == 'bn' ? true : (saved == 'en' ? false : null);
    } catch (_) {
      // Storage can be unavailable (private browsing): use the restaurant's language.
    }
    if (mounted) setState(() => _languageReady = true);
  }

  Future<void> _saveLanguage(bool bangla) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, bangla ? 'bn' : 'en');
    } catch (_) {
      // The choice still applies until the page is closed.
    }
  }

  PublicMenuRequest get _request => PublicMenuRequest(
    businessSlug: widget.businessSlug,
    branchSlug: widget.branchSlug,
    qrToken: widget.qrToken,
  );

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(publicMenuProvider(_request));
    final data = menu.valueOrNull?.data;
    final palette = data == null ? null : MenuPalette.of(data.business.menuTheme);

    Widget body;
    if (menu.hasError && !menu.isLoading) {
      body = ErrorState(
        title: 'Could not open the menu',
        message: friendlyError(menu.error),
        onRetry: () => ref.invalidate(publicMenuProvider(_request)),
      );
    } else if (!menu.hasValue || !_languageReady) {
      body = const MenuLoadingView();
    } else {
      final result = menu.requireValue;
      final loaded = result.data;
      if (loaded == null) {
        body = MenuProblemView(
          problem: result.problem ?? PublicMenuProblem.unknown,
          onRetry: () => ref.invalidate(publicMenuProvider(_request)),
        );
      } else {
        body = PublicMenuView(
          data: loaded,
          initialBangla: _savedBangla,
          onLanguageChanged: _saveLanguage,
          onSelectBranch: (branch) => context.go(AppRoutes.publicMenu(loaded.business.slug, branch.slug)),
        );
      }
    }

    final title = data == null ? 'Menu' : businessDisplayName(data.business, bangla: data.business.startsInBangla);
    return Title(
      title: title,
      color: palette?.ink ?? Colors.black,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (palette?.isDark ?? false) ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: palette?.paper,
          body: SafeArea(bottom: false, child: body),
        ),
      ),
    );
  }
}
