import 'package:flutter/material.dart';
import 'mini_app_models.dart';

const miniAppCategories = <MiniAppCategoryInfo>[
  MiniAppCategoryInfo(
    category: MiniAppCategory.entertainment,
    label: 'Giải trí',
    icon: Icons.sports_esports_outlined,
  ),
  MiniAppCategoryInfo(
    category: MiniAppCategory.food,
    label: 'Đồ ăn & Thức uống',
    icon: Icons.restaurant_outlined,
  ),
  MiniAppCategoryInfo(
    category: MiniAppCategory.fitness,
    label: 'Sức khỏe',
    icon: Icons.fitness_center_outlined,
  ),
  MiniAppCategoryInfo(
    category: MiniAppCategory.services,
    label: 'Dịch vụ',
    icon: Icons.miscellaneous_services_outlined,
  ),
];

const dummyMiniApps = <MiniApp>[
  // ── Real mini apps (WebView) ───────────────────────
  MiniApp(
    id: 'mini-game-reflex',
    name: 'Sport Reflex',
    description: 'Tap nhanh, ghi điểm, chờ sân không chán',
    icon: Icons.flash_on_outlined,
    color: Color(0xFFE74C3C),
    category: MiniAppCategory.entertainment,
    userCount: 2100,
    rating: 4.7,
    assetPath: 'assets/mini_apps/mini_game.html',
  ),
  MiniApp(
    id: 'fnb-partner',
    name: 'Đồ uống & Ăn vặt',
    description: 'Đặt tại sân, giao tận bàn',
    icon: Icons.local_cafe_outlined,
    color: Color(0xFF6D4C41),
    category: MiniAppCategory.food,
    userCount: 1800,
    rating: 4.4,
    assetPath: 'assets/mini_apps/fnb_partner.html',
  ),
  MiniApp(
    id: 'coach-booking',
    name: 'Thuê HLV cá nhân',
    description: 'Đặt huấn luyện viên theo giờ',
    icon: Icons.person_search_outlined,
    color: Color(0xFF0097A7),
    category: MiniAppCategory.fitness,
    userCount: 520,
    rating: 4.8,
    assetPath: 'assets/mini_apps/coach_booking.html',
  ),

  // ── Placeholder mini apps (coming soon) ────────────
  MiniApp(
    id: 'mini-game-quiz',
    name: 'Sport Quiz',
    description: 'Đố vui kiến thức thể thao',
    icon: Icons.quiz_outlined,
    color: Color(0xFF00B894),
    category: MiniAppCategory.entertainment,
    userCount: 890,
    rating: 4.2,
    status: MiniAppStatus.comingSoon,
  ),
  MiniApp(
    id: 'fnb-the-pizza',
    name: 'The Pizza Company',
    description: 'Pizza & pasta giao tại sân',
    icon: Icons.local_pizza_outlined,
    color: Color(0xFFEF6C00),
    category: MiniAppCategory.food,
    userCount: 430,
    rating: 4.1,
    status: MiniAppStatus.comingSoon,
  ),
  MiniApp(
    id: 'fitness-yoga',
    name: 'Yoga & Stretching',
    description: 'Bài tập giãn cơ trước khi chơi',
    icon: Icons.self_improvement_outlined,
    color: Color(0xFF7B1FA2),
    category: MiniAppCategory.fitness,
    userCount: 210,
    rating: 4.8,
    status: MiniAppStatus.comingSoon,
  ),
  MiniApp(
    id: 'service-tournament',
    name: 'Giải đấu nội bộ',
    description: 'Đăng ký & theo dõi giải đấu',
    icon: Icons.emoji_events_outlined,
    color: Color(0xFFFF8F00),
    category: MiniAppCategory.services,
    userCount: 950,
    rating: 4.6,
    status: MiniAppStatus.comingSoon,
  ),
  MiniApp(
    id: 'service-find-partner',
    name: 'Tìm đối tập',
    description: 'Tìm người chơi cùng trình độ',
    icon: Icons.group_add_outlined,
    color: Color(0xFF5E35B1),
    category: MiniAppCategory.services,
    userCount: 410,
    rating: 4.3,
    status: MiniAppStatus.comingSoon,
  ),
];
