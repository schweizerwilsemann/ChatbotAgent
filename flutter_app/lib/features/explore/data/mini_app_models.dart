import 'package:flutter/material.dart';

enum MiniAppStatus { active, comingSoon, maintenance }

enum MiniAppCategory {
  entertainment,
  food,
  fitness,
  shopping,
  services,
}

class MiniApp {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final MiniAppCategory category;
  final MiniAppStatus status;
  final int userCount;
  final double? rating;
  final String? route;
  final String? assetPath;

  const MiniApp({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.imageUrl,
    required this.category,
    this.status = MiniAppStatus.active,
    this.userCount = 0,
    this.rating,
    this.route,
    this.assetPath,
  });

  bool get isActive => status == MiniAppStatus.active;
  bool get isComingSoon => status == MiniAppStatus.comingSoon;
  bool get hasWebView => assetPath != null && assetPath!.isNotEmpty;
}

class MiniAppCategoryInfo {
  final MiniAppCategory category;
  final String label;
  final IconData icon;

  const MiniAppCategoryInfo({
    required this.category,
    required this.label,
    required this.icon,
  });
}
