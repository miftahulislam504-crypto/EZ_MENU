import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/logic/slug.dart';
import '../../../core/widgets/widgets.dart';

enum SlugStatus { idle, checking, available, taken, invalid }

/// A link-name input that checks, as you type, whether the name is free.
///
/// [check] returns true when the slug can be used. The parent reads
/// [onStatusChanged] and should treat anything but [SlugStatus.available] as
/// not ready to save.
class SlugField extends StatefulWidget {
  const SlugField({
    super.key,
    required this.controller,
    required this.check,
    required this.onStatusChanged,
    this.label = 'Link name',
    this.linkPrefix,
    this.minLength = 3,
    this.helper,
  });

  final TextEditingController controller;
  final Future<bool> Function(String slug) check;
  final ValueChanged<SlugStatus> onStatusChanged;
  final String label;

  /// Shown above the field as the start of the full address, e.g.
  /// `menu.example.com/m/`.
  final String? linkPrefix;
  final int minLength;
  final String? helper;

  @override
  State<SlugField> createState() => _SlugFieldState();
}

class _SlugFieldState extends State<SlugField> {
  Timer? _debounce;
  SlugStatus _status = SlugStatus.idle;
  String _lastChecked = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onChanged();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _set(SlugStatus status) {
    if (_status == status) return;
    setState(() => _status = status);
    widget.onStatusChanged(status);
  }

  void _onChanged() {
    final slug = widget.controller.text.trim();
    _debounce?.cancel();
    if (slug.isEmpty) {
      _lastChecked = '';
      _set(SlugStatus.idle);
      return;
    }
    if (!isValidSlug(slug, minLength: widget.minLength)) {
      _lastChecked = '';
      _set(SlugStatus.invalid);
      return;
    }
    if (slug == _lastChecked && _status == SlugStatus.available) return;
    _set(SlugStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final free = await widget.check(slug);
        if (!mounted || widget.controller.text.trim() != slug) return;
        _lastChecked = slug;
        _set(free ? SlugStatus.available : SlugStatus.taken);
      } catch (_) {
        if (!mounted) return;
        // A failed check must not block saving; the database still enforces
        // uniqueness and the save reports a clash.
        _set(SlugStatus.available);
      }
    });
  }

  String? get _message {
    switch (_status) {
      case SlugStatus.checking:
        return 'Checking if this name is free';
      case SlugStatus.available:
        return 'This name is available';
      case SlugStatus.taken:
        return 'This name is already taken. Try another.';
      case SlugStatus.invalid:
        return 'Use lowercase letters, numbers and hyphens, '
            '${widget.minLength} to 60 characters.';
      case SlugStatus.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Color tone;
    IconData icon;
    switch (_status) {
      case SlugStatus.available:
        tone = palette.success;
        icon = Icons.check_circle_outline_rounded;
      case SlugStatus.taken:
      case SlugStatus.invalid:
        tone = palette.danger;
        icon = Icons.error_outline_rounded;
      case SlugStatus.checking:
      case SlugStatus.idle:
        tone = palette.muted;
        icon = Icons.link_rounded;
    }
    final message = _message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: widget.label,
          controller: widget.controller,
          prefixText: widget.linkPrefix,
          keyboardType: TextInputType.url,
          helper: widget.helper,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                if (_status == SlugStatus.checking)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, size: 16, color: tone),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message,
                    style: context.textStyles.bodySmall?.copyWith(color: tone),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
