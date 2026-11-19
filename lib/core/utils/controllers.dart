import 'package:flutter/widgets.dart';

import 'json_utils.dart';

/// A set of text controllers addressed by name, so a long form does not need
/// thirty fields declared, initialised and disposed by hand.
///
///   final c = ControllerBag();
///   c.fill({'name': business.name});
///   AppTextField(label: 'Name', controller: c['name']);
///   c.nullable('name');        // trimmed text, or null when empty
///   c.dispose();               // in State.dispose
class ControllerBag {
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController operator [](String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  /// Sets the text of several controllers at once.
  void fill(Map<String, String?> values) {
    values.forEach((key, value) => this[key].text = value ?? '');
  }

  /// Trimmed text, empty string when unset.
  String text(String key) => _controllers[key]?.text.trim() ?? '';

  /// Trimmed text, or null when empty (what the database should store).
  String? nullable(String key) => emptyToNull(_controllers[key]?.text);

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
