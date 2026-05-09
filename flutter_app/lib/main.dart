import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/config/flavor_config.dart';
import 'package:sports_venue_chatbot/core/router/app_router.dart';
import 'package:sports_venue_chatbot/core/theme/app_theme.dart';

Future<void> main() async => _runApp(FlavorConfig.resolveFlavor(appFlavor));

Future<void> _runApp(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN');
  FlavorConfig.init(flavor);
  runApp(
    const ProviderScope(
      child: SportsVenueChatbotApp(),
    ),
  );
}

class SportsVenueChatbotApp extends ConsumerWidget {
  const SportsVenueChatbotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: FlavorConfig.appName,
      debugShowCheckedModeBanner: FlavorConfig.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
    );
  }
}
