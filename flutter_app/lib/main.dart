import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sports_venue_chatbot/core/config/flavor_config.dart';
import 'package:sports_venue_chatbot/core/router/app_router.dart';
import 'package:sports_venue_chatbot/core/theme/app_scroll_behavior.dart';
import 'package:sports_venue_chatbot/core/theme/app_theme.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/customer_chat_notifications_provider.dart';

Future<void> main() async => _runApp(FlavorConfig.resolveFlavor(appFlavor));

Future<void> _runApp(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN');
  await FlavorConfig.init(flavor);
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
    ref.listen(authStateProvider, (_, next) {
      _syncRealtimeNotifications(ref, next.valueOrNull?.role);
    });
    final authState = ref.watch(authStateProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRealtimeNotifications(ref, authState.valueOrNull?.role);
    });

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: FlavorConfig.appName,
      debugShowCheckedModeBanner: FlavorConfig.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const AppScrollBehavior(),
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

void _syncRealtimeNotifications(WidgetRef ref, String? role) {
  _syncCustomerChatNotifications(ref, role);
  _syncStaffNotifications(ref, role);
}

void _syncCustomerChatNotifications(WidgetRef ref, String? role) {
  final customerNotifier = ref.read(customerChatNotificationsProvider.notifier);
  final normalizedRole = role?.toUpperCase();
  if (normalizedRole == null ||
      normalizedRole == 'STAFF' ||
      normalizedRole == 'ADMIN') {
    customerNotifier.stop();
    return;
  }
  customerNotifier.start();
}

void _syncStaffNotifications(WidgetRef ref, String? role) {
  final staffNotifier = ref.read(staffNotificationsProvider.notifier);
  final normalizedRole = role?.toUpperCase();
  if (normalizedRole == 'STAFF' || normalizedRole == 'ADMIN') {
    staffNotifier.start();
    return;
  }
  staffNotifier.stop();
}
