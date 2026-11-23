import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/models.dart';
import '../../../core/supabase/error_text.dart';
import '../../../core/widgets/widgets.dart';
import '../menu_models.dart';
import '../menu_repository.dart';

/// Which branches show one category. Each switch saves at once.
Future<void> showCategoryBranchSheet(
  BuildContext context, {
  required MenuCategory category,
  required List<Branch> branches,
}) {
  return showAppSheet<void>(
    context,
    title: 'Branch availability',
    builder: (_) => _BranchSheetBody(category: category, branches: branches),
  );
}

class _BranchSheetBody extends ConsumerStatefulWidget {
  const _BranchSheetBody({required this.category, required this.branches});

  final MenuCategory category;
  final List<Branch> branches;

  @override
  ConsumerState<_BranchSheetBody> createState() => _BranchSheetBodyState();
}

class _BranchSheetBodyState extends ConsumerState<_BranchSheetBody> {
  Map<String, bool>? _values;
  Object? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final map = await ref
          .read(menuRepositoryProvider)
          .categorySettingsForCategory(widget.category.id);
      if (mounted) setState(() => _values = map);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggle(Branch branch, bool active) async {
    final previous = _values?[branch.id] ?? true;
    setState(() {
      _values = {...?_values, branch.id: active};
      _saving.add(branch.id);
    });
    try {
      await ref.read(menuRepositoryProvider).setCategoryActiveAtBranch(
        branchId: branch.id,
        categoryId: widget.category.id,
        active: active,
      );
      ref.refreshMenu();
    } catch (error) {
      if (!mounted) return;
      setState(() => _values = {...?_values, branch.id: previous});
      showToast(context, friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _saving.remove(branch.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: ErrorState(message: friendlyError(_error), onRetry: () {
          setState(() => _error = null);
          _load();
        }),
      );
    }
    if (_values == null) {
      return const Padding(padding: EdgeInsets.all(Sp.xxl), child: LoadingView());
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choose where "${widget.category.displayName}" appears on the customer menu.',
              style: context.textStyles.bodyMedium?.copyWith(color: context.palette.muted),
            ),
          ),
        ),
        for (final branch in widget.branches)
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Sp.xl),
            title: Text(branch.name),
            subtitle: Text((_values![branch.id] ?? true) ? 'Shown' : 'Hidden at this branch'),
            value: _values![branch.id] ?? true,
            onChanged: _saving.contains(branch.id) ? null : (v) => _toggle(branch, v),
          ),
        const SizedBox(height: Sp.lg),
      ],
    );
  }
}
