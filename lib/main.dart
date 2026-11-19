import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/setup_error_app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean web addresses (/m/my-cafe instead of /#/m/my-cafe). A no-op on
  // Android and iOS.
  usePathUrlStrategy();

  if (!Env.isConfigured) {
    runApp(const SetupErrorApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } catch (error) {
    runApp(SetupErrorApp(details: error.toString()));
    return;
  }

  runApp(const ProviderScope(child: EzMenuApp()));
}
