import 'package:flutter/material.dart';
import 'package:sports_venue_chatbot/features/admin/presentation/booking_management_screen.dart';

/// Staff-specific wrapper for BookingManagementScreen
/// This avoids GoRouter key conflicts with AdminShell routes
class StaffBookingScreen extends StatelessWidget {
  const StaffBookingScreen({super.key});

  @override
  Widget build(BuildContext context) => const BookingManagementScreen();
}
