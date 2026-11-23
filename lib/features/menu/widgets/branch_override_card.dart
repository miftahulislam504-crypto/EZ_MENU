import 'package:flutter/material.dart';

import '../../../core/logic/money.dart';
import '../../../core/logic/sold_out.dart';
import '../../../core/session/models.dart';
import '../../../core/widgets/widgets.dart';
import '../branch_override_logic.dart';
import '../item_form_logic.dart';
import '../menu_models.dart';
import 'editor_common.dart';

/// What one branch does differently for a dish. Collapsed it shows a summary;
/// expanded it edits "offered here", the branch price and sold out here.
class BranchOverrideCard extends StatefulWidget {
  const BranchOverrideCard({
    super.key,
    required this.branch,
    required this.setting,
    required this.itemId,
    required this.basePrice,
    required this.baseDiscountPrice,
    required this.currency,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
    required this.onReset,
  });

  final Branch branch;

  /// Null when the branch has no override.
  final BranchItemSetting? setting;
  final String itemId;
  final double basePrice;
  final double? baseDiscountPrice;
  final String currency;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<BranchItemSetting> onChanged;
  final VoidCallback onReset;

  @override
  State<BranchOverrideCard> createState() => _BranchOverrideCardState();
}

class _BranchOverrideCardState extends State<BranchOverrideCard> {
  final TextEditingController _price = TextEditingController();
  final TextEditingController _discount = TextEditingController();

  BranchItemSetting get _setting =>
      widget.setting ?? blankSetting(widget.branch.id, widget.itemId);

  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BranchOverrideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing a field's text notifies the surrounding Form, which must not
    // happen while building, so the sync runs after the frame.
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _sync();
    });
  }

  @override
  void dispose() {
    _price.dispose();
    _discount.dispose();
    super.dispose();
  }

  void _sync() {
    final s = _setting;
    if (parseMoneyText(_price.text) != s.price) {
      setTextIfChanged(_price, plainNumber(s.price));
    }
    if (parseMoneyText(_discount.text) != s.discountPrice) {
      setTextIfChanged(_discount, plainNumber(s.discountPrice));
    }
  }

  void _emit(BranchItemSetting next) => widget.onChanged(next);

  Future<void> _pickBackAt() async {
    final now = DateTime.now();
    final current = _setting.soldOutUntil?.toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay.fromDateTime(current)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!picked.isAfter(now)) {
      showToast(context, 'Pick a time in the future.', isError: true);
      return;
    }
    _emit(_setting.copyWith(soldOutUntil: picked));
  }

  List<Widget> _summaryPills() {
    final s = widget.setting;
    if (s == null || !hasOverride(s)) {
      return const [StatusPill('Same as all branches')];
    }
    return [
      if (!s.isOffered) const StatusPill('Hidden here', tone: PillTone.danger),
      if (s.price != null)
        StatusPill(
          'Price ${formatMoney(s.price!, currency: widget.currency)}',
          tone: PillTone.info,
        ),
      if (s.isSoldOut) const StatusPill('Sold out here', tone: PillTone.warning),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = _setting;
    final overridden = widget.setting != null && hasOverride(widget.setting!);
    final view = branchPriceView(
      basePrice: widget.basePrice,
      baseDiscountPrice: widget.baseDiscountPrice,
      setting: widget.setting,
    );
    final problems = validateBranchSettings(
      [s],
      basePrice: widget.basePrice,
      branchNames: {widget.branch.id: widget.branch.name},
    );
    final symbol = currencySymbol(widget.currency);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(Rad.panel),
        border: Border.all(
          color: overridden ? context.colors.primary.withValues(alpha: 0.45) : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Rad.panel),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.md, Sp.md),
              child: Row(
                children: [
                  const IconBadge(Icons.storefront_outlined, size: 38),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.branch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: _summaryPills()),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: palette.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: widget.expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: Sp.lg, color: palette.line),
                        SwitchRow(
                          title: 'Offered at this branch',
                          subtitle: s.isOffered
                              ? 'Customers of this branch can see the dish.'
                              : 'The dish is hidden from this branch only.',
                          value: s.isOffered,
                          onChanged: (value) => _emit(s.copyWith(isOffered: value)),
                        ),
                        const SizedBox(height: Sp.md),
                        Text('Branch price', style: context.textStyles.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Replaces both the regular and the discount price at this branch. '
                          'Dish price: ${formatMoney(widget.basePrice, currency: widget.currency)}'
                          '${widget.baseDiscountPrice != null ? ' (discount ${formatMoney(widget.baseDiscountPrice!, currency: widget.currency)})' : ''}.',
                          style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
                        ),
                        const SizedBox(height: Sp.sm),
                        Wrap(
                          spacing: Sp.md,
                          runSpacing: Sp.sm,
                          children: [
                            SizedBox(
                              width: 160,
                              child: AppTextField(
                                label: 'Price here',
                                optional: true,
                                controller: _price,
                                prefixText: '$symbol ',
                                hint: 'Same as dish',
                                keyboardType: moneyKeyboard,
                                inputFormatters: moneyInputFormatters,
                                onChanged: (text) {
                                  final value = parseMoneyText(text);
                                  _emit(
                                    value == null
                                        ? s.copyWith(clearPrice: true)
                                        : s.copyWith(price: value),
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: 190,
                              child: AppTextField(
                                label: 'Discount price here',
                                optional: true,
                                controller: _discount,
                                prefixText: '$symbol ',
                                enabled: s.price != null,
                                keyboardType: moneyKeyboard,
                                inputFormatters: moneyInputFormatters,
                                onChanged: (text) {
                                  final value = parseMoneyText(text);
                                  _emit(
                                    value == null
                                        ? s.copyWith(clearDiscount: true)
                                        : s.copyWith(discountPrice: value),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Sp.sm),
                        _EffectivePrice(view: view, currency: widget.currency),
                        const SizedBox(height: Sp.md),
                        SwitchRow(
                          title: 'Sold out at this branch',
                          subtitle: s.isSoldOut
                              ? null
                              : 'Mark it sold out here without touching other branches.',
                          value: s.isSoldOut,
                          onChanged: (value) => _emit(
                            value
                                ? s.copyWith(isSoldOut: true)
                                : s.copyWith(isSoldOut: false, clearSoldOutUntil: true),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: s.isSoldOut
                              ? Padding(
                                  padding: const EdgeInsets.only(top: Sp.sm),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _pickBackAt,
                                          icon: const Icon(Icons.event_available_rounded, size: 18),
                                          label: Text(
                                            s.soldOutUntil == null
                                                ? 'Until I turn it back on'
                                                : backAtText(s.soldOutUntil!, DateTime.now()),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (s.soldOutUntil != null)
                                        IconButton(
                                          tooltip: 'Clear return time',
                                          onPressed: () => _emit(s.copyWith(clearSoldOutUntil: true)),
                                          icon: Icon(Icons.close_rounded, color: palette.muted),
                                        ),
                                    ],
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                        if (problems.isNotEmpty) ...[
                          const SizedBox(height: Sp.md),
                          EditorProblems(problems),
                        ],
                        if (overridden) ...[
                          const SizedBox(height: Sp.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: AppButton(
                              label: 'Reset to default',
                              icon: Icons.restart_alt_rounded,
                              kind: AppButtonKind.secondary,
                              onPressed: widget.onReset,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _EffectivePrice extends StatelessWidget {
  const _EffectivePrice({required this.view, required this.currency});

  final BranchPriceView view;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(Rad.control),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              view.isOverride ? 'Customers here pay' : 'Customers here pay (same as other branches)',
              style: context.textStyles.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
          if (view.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                formatMoney(view.price, currency: currency),
                style: context.textStyles.bodySmall?.copyWith(
                  color: palette.muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          Text(
            formatMoney(view.payable, currency: currency),
            style: context.textStyles.titleSmall,
          ),
        ],
      ),
    );
  }
}
