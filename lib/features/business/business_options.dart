import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';

/// Business types allowed by the database, with the words shown to people.
const List<SelectOption<String>> businessTypeOptions = [
  SelectOption(value: 'restaurant', label: 'Restaurant'),
  SelectOption(value: 'cafe', label: 'Cafe'),
  SelectOption(value: 'fast_food', label: 'Fast food'),
  SelectOption(value: 'bakery', label: 'Bakery'),
  SelectOption(value: 'sweets_shop', label: 'Sweets shop'),
  SelectOption(value: 'food_court', label: 'Food court'),
  SelectOption(value: 'cloud_kitchen', label: 'Cloud kitchen'),
  SelectOption(value: 'other', label: 'Other food business'),
];

const List<SelectOption<String>> currencyOptions = [
  SelectOption(value: 'BDT', label: 'Bangladeshi taka (BDT)'),
  SelectOption(value: 'USD', label: 'US dollar (USD)'),
  SelectOption(value: 'INR', label: 'Indian rupee (INR)'),
];

const List<SelectOption<String>> languageOptions = [
  SelectOption(value: 'bn', label: 'Bangla'),
  SelectOption(value: 'en', label: 'English'),
];

const List<SelectOption<String>> timezoneOptions = [
  SelectOption(value: 'Asia/Dhaka', label: 'Bangladesh (Asia/Dhaka)'),
  SelectOption(value: 'Asia/Kolkata', label: 'India (Asia/Kolkata)'),
  SelectOption(value: 'Asia/Dubai', label: 'United Arab Emirates (Asia/Dubai)'),
  SelectOption(value: 'Asia/Singapore', label: 'Singapore (Asia/Singapore)'),
  SelectOption(value: 'Europe/London', label: 'United Kingdom (Europe/London)'),
  SelectOption(
    value: 'America/New_York',
    label: 'US Eastern (America/New_York)',
  ),
];

String businessTypeLabel(String value) {
  for (final option in businessTypeOptions) {
    if (option.value == value) return option.label;
  }
  return 'Restaurant';
}

/// Brand colour swatches that look good on food: leaf, chili, turmeric and
/// friends. Any colour can still be typed in.
const List<Color> brandSwatches = [
  Color(0xFF166A4C),
  Color(0xFF0E7C86),
  Color(0xFF1F5FA8),
  Color(0xFF5B3FA0),
  Color(0xFFB5306B),
  Color(0xFFC62F2F),
  Color(0xFFD9611E),
  Color(0xFFB8860B),
  Color(0xFF5C4033),
  Color(0xFF2B2B2B),
];
