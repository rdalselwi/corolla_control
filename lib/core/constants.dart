import 'package:flutter/material.dart';

class AppConstants {
  // 🌐 القيم الافتراضية الأولية (تُستخدم فقط كـ Fallback في حال لم توجد بيانات محفوظة)
  static const String defaultDirectIp = "192.168.4.1"; // اتصال مباشر مع الـ ESP32
  static const String defaultServerIp = "192.168.137.1:1880"; // سيرفر Node-RED واللابتوب
  static const String defaultPassword = "1234";

  // 📡 مسارات الـ API الموحدة لـ Node-RED
  static const String apiVehicleCommand = "/api/vehicle/command";
  static const String apiVehicleStatus  = "/api/vehicle/status";

  // 🎨 تدرجات ألوان الواجهة الزجاجية والوضعية المظلمة الفاخرة (Neon Theme)
  static const Color darkBgTop      = Color(0xFF0D1527);
  static const Color darkBgBottom   = Color(0xFF020408);
  static const Color cyanGlow       = Color(0xFF00E5FF);
  static const Color orangeSun      = Color(0xFFFF6B00);
  static const Color redFuse        = Color(0xFFFF2D55);
  static const Color greenSuccess   = Color(0xFF00E676);

  // 🎨 ألوان الهوية البصرية الموحدة
  static const Color panelBg        = Color(0xFF0A0A0B);
  static const Color logoWhite      = Color(0xFFFFFFFF);
}
