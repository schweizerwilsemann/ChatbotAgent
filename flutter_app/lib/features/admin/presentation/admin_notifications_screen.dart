import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/features/staff/presentation/staff_notifications_screen.dart';

/// Admin-specific wrapper for StaffNotificationsScreen
/// This avoids GoRouter key conflicts with StaffShell routes
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const StaffNotificationsScreen();
}
