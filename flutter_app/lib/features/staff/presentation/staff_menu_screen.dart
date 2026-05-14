import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/menu_management_screen.dart';

/// Staff-specific wrapper for MenuManagementScreen
/// This avoids GoRouter key conflicts with AdminShell routes
class StaffMenuScreen extends StatelessWidget {
  const StaffMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => const MenuManagementScreen();
}
