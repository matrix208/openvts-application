import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_avl/app.dart';
import 'package:smart_avl/bootstrap.dart';
import 'package:smart_avl/core/performance/open_vts_perf.dart';
import 'package:smart_avl/core/providers/shared_preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await OpenVtsPerf.traceAsync(
    'bootstrap.sharedPreferences',
    SharedPreferences.getInstance,
  );

  await bootstrap(() async {
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const App(),
      ),
    );
  });
}
