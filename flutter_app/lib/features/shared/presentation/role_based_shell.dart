import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/admin_shell.dart';
import 'package:sports_venue_chatbot/features/auth/presentation/auth_provider.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_shell.dart';

/// Unified shell that renders AdminShell or StaffShell based on user role.
class RoleBasedShell extends ConsumerWidget {
  final Widget child;

  const RoleBasedShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final role = user?.role.toUpperCase();

    if (role == 'ADMIN') {
      return AdminShell(child: child);
    } else if (role == 'STAFF') {
      return StaffShell(child: child);
    }

    // Fallback - should not happen due to router redirect
    return AdminShell(child: child);
  }
}
