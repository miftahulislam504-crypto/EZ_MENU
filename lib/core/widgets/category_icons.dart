import 'package:flutter/material.dart';

/// Icons a category can use. The key is what is stored in
/// `menu_categories.icon`; the dashboard picker and the customer menu both
/// read this one table, so a picked icon always shows up.
const Map<String, IconData> categoryIcons = {
  'restaurant': Icons.restaurant_rounded,
  'menu': Icons.restaurant_menu_rounded,
  'burger': Icons.lunch_dining_rounded,
  'pizza': Icons.local_pizza_rounded,
  'noodles': Icons.ramen_dining_rounded,
  'seafood': Icons.set_meal_rounded,
  'rice': Icons.rice_bowl_rounded,
  'bento': Icons.bento_rounded,
  'bakery': Icons.bakery_dining_rounded,
  'cake': Icons.cake_rounded,
  'cookie': Icons.cookie_rounded,
  'ice_cream': Icons.icecream_rounded,
  'coffee': Icons.coffee_rounded,
  'cafe': Icons.local_cafe_rounded,
  'tea': Icons.emoji_food_beverage_rounded,
  'drink': Icons.local_drink_rounded,
  'juice': Icons.blender_rounded,
  'bar': Icons.local_bar_rounded,
  'breakfast': Icons.breakfast_dining_rounded,
  'brunch': Icons.brunch_dining_rounded,
  'dinner': Icons.dinner_dining_rounded,
  'kebab': Icons.kebab_dining_rounded,
  'grill': Icons.outdoor_grill_rounded,
  'egg': Icons.egg_alt_rounded,
  'fast_food': Icons.fastfood_rounded,
  'soup': Icons.soup_kitchen_rounded,
  'starter': Icons.tapas_rounded,
  'takeaway': Icons.takeout_dining_rounded,
  'healthy': Icons.eco_rounded,
  'spicy': Icons.local_fire_department_rounded,
  'special': Icons.star_rounded,
};

/// The icon for a stored key, or null when none is set or the key is unknown.
IconData? categoryIconFor(String? key) {
  if (key == null) return null;
  return categoryIcons[key];
}
