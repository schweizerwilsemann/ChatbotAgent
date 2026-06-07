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
import 'package:sports_venue_chatbot/features/auth/data/auth_models.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/settings/presentation/app_settings_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_provider.dart';
import 'package:sports_venue_chatbot/features/staff_chat/presentation/customer_chat_notifications_provider.dart';

Future<void> main() async => _runApp(FlavorConfig.resolveFlavor(appFlavor));

Future<void> _runApp(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'vi_VN';
  await initializeDateFormatting('vi_VN');
  await initializeDateFormatting('en_US');
  await FlavorConfig.init(flavor);
  runApp(
    const ProviderScope(
      child: SportsVenueChatbotApp(),
    ),
  );
}

class SportsVenueChatbotApp extends ConsumerStatefulWidget {
  const SportsVenueChatbotApp({super.key});

  @override
  ConsumerState<SportsVenueChatbotApp> createState() =>
      _SportsVenueChatbotAppState();
}

class _SportsVenueChatbotAppState extends ConsumerState<SportsVenueChatbotApp> {
  bool _initialSyncDone = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
      debugPrint('[Main] authState changed: ${next.valueOrNull?.role}');
      _syncRealtimeNotifications(ref, next.valueOrNull?.role);
    });

    if (!_initialSyncDone) {
      final authState = ref.read(authStateProvider);
      final role = authState.valueOrNull?.role;
      if (authState.hasValue) {
        _initialSyncDone = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[Main] Initial sync with role: $role');
          _syncRealtimeNotifications(ref, role);
        });
      }
    }

    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    final selectedLocale = settings.language.locale ?? const Locale('vi', 'VN');
    Intl.defaultLocale = settings.language.intlLocaleName ?? 'vi_VN';

    return MaterialApp.router(
      title: FlavorConfig.appName,
      debugShowCheckedModeBanner: FlavorConfig.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      locale: selectedLocale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
      ],
    );
  }
}

void _syncRealtimeNotifications(WidgetRef ref, String? role) {
  debugPrint('[Main] _syncRealtimeNotifications called with role: $role');
  _syncCustomerChatNotifications(ref, role);
  _syncStaffNotifications(ref, role);
}

void _syncCustomerChatNotifications(WidgetRef ref, String? role) {
  final customerNotifier = ref.read(customerChatNotificationsProvider.notifier);
  final normalizedRole = role?.toUpperCase();
  debugPrint(
      '[Main] _syncCustomerChatNotifications: normalizedRole=$normalizedRole');
  if (normalizedRole == null ||
      normalizedRole == 'STAFF' ||
      normalizedRole == 'ADMIN') {
    debugPrint('[Main] Stopping customer chat notifications');
    customerNotifier.stop();
    return;
  }
  debugPrint('[Main] Starting customer chat notifications');
  customerNotifier.start();
}

void _syncStaffNotifications(WidgetRef ref, String? role) {
  final staffNotifier = ref.read(staffNotificationsProvider.notifier);
  final normalizedRole = role?.toUpperCase();
  debugPrint('[Main] _syncStaffNotifications: normalizedRole=$normalizedRole');
  if (normalizedRole == 'STAFF' || normalizedRole == 'ADMIN') {
    debugPrint('[Main] Starting staff notifications');
    staffNotifier.start();
    return;
  }
  debugPrint('[Main] Stopping staff notifications');
  staffNotifier.stop();
}
