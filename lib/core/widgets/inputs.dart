import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'feedback.dart';

/// Text input with its label above the field.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.optional = false,
    this.autofocus = false,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.inputFormatters,
    this.autofillHints,
    this.focusNode,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;

  /// Appends "(optional)" to the label.
  final bool optional;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, optional: optional),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          enabled: enabled,
          readOnly: readOnly,
          obscureText: obscureText,
          autofocus: autofocus,
          onChanged: onChanged,
          onTap: onTap,
          onFieldSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          focusNode: focusNode,
          textAlign: textAlign,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 3,
            counterText: maxLength == null ? null : '',
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            prefixText: prefixText,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// A form label with an optional "(optional)" note.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final style = context.textStyles.labelLarge;
    return Text.rich(
      TextSpan(
        text: text,
        style: style,
        children: [
          if (optional)
            TextSpan(
              text: '  optional',
              style: context.textStyles.bodySmall?.copyWith(
                color: context.palette.muted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Password input with a show / hide toggle.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      helper: widget.helper,
      validator: widget.validator,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      suffix: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

/// English and Bangla inputs for one piece of menu content.
///
/// With [requireOne] the form is valid as soon as either language is filled.
class BilingualFields extends StatelessWidget {
  const BilingualFields({
    super.key,
    required this.label,
    required this.englishController,
    required this.banglaController,
    this.requireOne = false,
    this.optional = false,
    this.maxLines = 1,
    this.maxLength,
    this.hintEnglish,
    this.hintBangla,
  });

  final String label;
  final TextEditingController englishController;
  final TextEditingController banglaController;
  final bool requireOne;
  final bool optional;
  final int maxLines;
  final int? maxLength;
  final String? hintEnglish;
  final String? hintBangla;

  String? _check(String? value) {
    if (!requireOne) return null;
    final hasEnglish = englishController.text.trim().isNotEmpty;
    final hasBangla = banglaController.text.trim().isNotEmpty;
    if (hasEnglish || hasBangla) return null;
    return 'Enter the ${label.toLowerCase()} in English or Bangla.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          label: '$label in English',
          controller: englishController,
          hint: hintEnglish,
          optional: optional,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: _check,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Sp.md),
        AppTextField(
          label: '$label in Bangla',
          controller: banglaController,
          hint: hintBangla,
          optional: optional,
          maxLines: maxLines,
          maxLength: maxLength,
        ),
      ],
    );
  }
}

class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// A dropdown that opens a bottom sheet, which is easier to use on a phone
/// than the system dropdown.
class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint = 'Select',
    this.optional = false,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String hint;
  final bool optional;
  final String? errorText;
  final bool enabled;

  SelectOption<T>? get _selected {
    for (final option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showAppSheet<_Picked<T>>(
      context,
      title: label,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            ListTile(
              leading: option.icon == null ? null : Icon(option.icon),
              title: Text(option.label),
              subtitle: option.subtitle == null ? null : Text(option.subtitle!),
              trailing: option.value == value
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              onTap: () =>
                  Navigator.of(sheetContext).pop(_Picked<T>(option.value)),
            ),
          if (optional && value != null)
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Clear selection'),
              onTap: () => Navigator.of(sheetContext).pop(_Picked<T>(null)),
            ),
          const SizedBox(height: Sp.sm),
        ],
      ),
    );
    if (picked != null) onChanged(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final palette = context.palette;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, optional: optional),
        const SizedBox(height: 6),
        Material(
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rad.control),
            side: BorderSide(
              color: hasError ? context.colors.error : palette.line,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.control),
            onTap: enabled ? () => _open(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  if (selected?.icon != null) ...[
                    Icon(selected!.icon, size: 20, color: palette.muted),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      selected?.label ?? hint,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: selected == null ? palette.muted : null,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: palette.muted),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              errorText!,
              style: context.textStyles.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Wraps a picked value so "clear" (null) can be told apart from "dismissed".
class _Picked<T> {
  const _Picked(this.value);
  final T? value;
}

/// A title and description with a switch.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onChanged != null;
    return InkWell(
      borderRadius: BorderRadius.circular(Rad.control),
      onTap: active ? () => onChanged!(!value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.textStyles.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.textStyles.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Sp.md),
            Switch(value: value, onChanged: active ? onChanged : null),
          ],
        ),
      ),
    );
  }
}

class ChoiceOption<T> {
  const ChoiceOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// A compact segmented control for 2-4 mutually exclusive choices.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final List<ChoiceOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[FieldLabel(label!), const SizedBox(height: 6)],
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(Rad.control),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              for (final option in options)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: option.value == value,
                    label: option.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(option.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: option.value == value
                              ? scheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(Rad.control - 3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (option.icon != null) ...[
                              Icon(
                                option.icon,
                                size: 18,
                                color: option.value == value
                                    ? scheme.onPrimaryContainer
                                    : palette.muted,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                option.label,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.labelLarge?.copyWith(
                                  color: option.value == value
                                      ? scheme.onPrimaryContainer
                                      : palette.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
