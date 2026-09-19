class CarStatusModel {
  final String state;
  final bool red;
  final bool blue;
  final bool door1;
  final bool door2;
  final bool light1;
  final bool light2;
  final int starts;
  final bool vibrationAlert;
  final int vibrationCount;
  final String appPassword; // 🔐 المتغير الجديد المضاف لاستقبال رمز حماية المنظومة

  CarStatusModel({
    required this.state,
    required this.red,
    required this.blue,
    required this.door1,
    required this.door2,
    required this.light1,
    required this.light2,
    required this.starts,
    required this.vibrationAlert,
    required this.vibrationCount,
    required this.appPassword, // إلزامي في كونسلوتر البناء
  });

  // دالة تحويل الـ JSON القادم من السيرفر (ESP32) إلى كائن Dart
  factory CarStatusModel.fromJson(Map<String, dynamic> json) {
    return CarStatusModel(
      state: json['state'] ?? 'VEHICLE_OFF',
      red: json['red'] ?? false,
      blue: json['blue'] ?? false,
      door1: json['door1'] ?? false,
      door2: json['door2'] ?? false,
      light1: json['light1'] ?? false,
      light2: json['light2'] ?? false,
      starts: json['starts'] ?? 0,
      vibrationAlert: json['vibrationAlert'] ?? false,
      vibrationCount: json['vibrationCount'] ?? 0,
      appPassword: json['appPassword'] ?? '1234', // 🔐 فك ترميز الرمز واستلامه ديناميكياً مع وضع قيمة افتراضية للاحتياط
    );
  }
}

