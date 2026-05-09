import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary — Deep Red Accent ──────────────────────────────────────
  static const Color primary = Color(0xFFC0392B); // kAccent
  static const Color primaryLight = Color(0xFFE74C3C); // kAccentHover
  static const Color primaryDark = Color(0xFF96281B);
  static const Color primarySurface = Color(0xFFFDE8E6); // light red tint

  // ── Secondary — Warm Tan ───────────────────────────────────────────
  static const Color secondary = Color(0xFFD4A574);
  static const Color secondaryLight = Color(0xFFE8C9A0);
  static const Color secondaryDark = Color(0xFFB8864F);

  // ── Surface & Background ───────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF); // kBgCard
  static const Color surfaceVariant = Color(0xFFF9F5F0); // kInputBg
  static const Color background = Color(0xFFF5F0EB); // kBgPage
  static const Color scaffoldBackground = Color(0xFFF5F0EB); // kBgPage
  static const Color cardBackground = Color(0xFFFFFFFF); // kBgCard

  // ── Text Colors ────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF2C2C2C); // kTextPrimary
  static const Color textSecondary = Color(0xFF888880); // kTextSecondary
  static const Color textHint = Color(0xFFB5B0A8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status Colors ──────────────────────────────────────────────────
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);

  // ── Chat Bubble Colors ─────────────────────────────────────────────
  static const Color userBubble = Color(0xFFC0392B); // kAccent
  static const Color userBubbleText = Color(0xFFFFFFFF);
  static const Color botBubble = Color(0xFFFFFFFF); // kBgCard
  static const Color botBubbleText = Color(0xFF2C2C2C); // kTextPrimary
  static const Color botBubbleBorder = Color(0xFFE8E0D8); // kBorder

  // ── Tool Badge Colors ──────────────────────────────────────────────
  static const Color toolBadgeBackground = Color(0xFFFDE8E6);
  static const Color toolBadgeText = Color(0xFFC0392B);
  static const Color toolBadgeBooking = Color(0xFFE8F5E9);
  static const Color toolBadgeMenu = Color(0xFFFFF3E0);
  static const Color toolBadgeOrder = Color(0xFFFCE4EC);

  // ── Border, Divider & Shadow ───────────────────────────────────────
  static const Color border = Color(0xFFE8E0D8); // kBorder
  static const Color divider = Color(0xFFE8E0D8); // kBorder
  static const Color shadow = Color(0x14000000);
  static const Color overlay = Color(0x52000000);

  // ── Banner ─────────────────────────────────────────────────────────
  static const Color bannerBg = Color(0xFFFFF9E6); // kBannerBg

  // ── Input ──────────────────────────────────────────────────────────
  static const Color inputBg = Color(0xFFF9F5F0); // kInputBg

  // ── Court Type Colors (functional — sport identification) ──────────
  static const Color billiardsColor = Color(0xFF2E7D32);
  static const Color pickleballColor = Color(0xFF1565C0);
  static const Color badmintonColor = Color(0xFFF57C00);
}
