import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../models/car_status_model.dart';

enum ConnectionMode {
  directESP32, // الاتصال المباشر بنقطة بث الـ ESP32
  serverNodeRed, // الاتصال عبر وسيط وسيرفر Node-RED و MQTT
}

class NetworkService extends ChangeNotifier {
  CarStatusModel? _currentStatus;
  bool _isConnected = true;
  Timer? _statusTimer;

  // 🌍 إدارة اللغة والمظهر
  bool _isArabic = true;
  bool _isDarkMode = true;

  // وضع الاتصال الحالي (افتراضياً: عبر السيرفر و Node-RED ليعمل مع MQTT والإشعارات)
  ConnectionMode _connectionMode = ConnectionMode.serverNodeRed;

  // عناوين الـ IP المحفوظة
  String _esp32DirectIp = "192.168.4.1";
  String _nodeRedServerIp = "192.168.137.1:1880";

  // 🔐 كلمة المرور الافتراضية
  String _appPassword = "1234";

  // Getters المفتوحة للشاشات
  CarStatusModel? get currentStatus => _currentStatus;
  bool get isConnected => _isConnected;
  String get appPassword => _appPassword;
  bool get isArabic => _isArabic;
  bool get isDarkMode => _isDarkMode;
  ConnectionMode get connectionMode => _connectionMode;
  bool get isMqttServerMode => _connectionMode == ConnectionMode.serverNodeRed;

  // الرابط الفعال بحسب وضع الاتصال المختار
  String get baseUrl => isMqttServerMode ? _nodeRedServerIp : _esp32DirectIp;

  NetworkService() {
    _loadSavedConfiguration();
  }

  // تحميل الإعدادات المحفوظة
  Future<void> _loadSavedConfiguration() async {
    final prefs = await SharedPreferences.getInstance();

    _appPassword = prefs.getString('app_password') ?? "1234";
    _esp32DirectIp = prefs.getString('car_ip_address') ?? "192.168.4.1";
    _nodeRedServerIp = prefs.getString('nodered_ip_address') ?? "192.168.137.1:1880";

    _isArabic = prefs.getBool('is_arabic') ?? true;
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;

    // استرجاع وضع الاتصال الأخير
    int? savedModeIndex = prefs.getInt('connection_mode');
    if (savedModeIndex != null && savedModeIndex < ConnectionMode.values.length) {
      _connectionMode = ConnectionMode.values[savedModeIndex];
    }

    notifyListeners();
  }

  // 🔄 دالة التبديل بين الوضع المباشر ووضع السيرفر/MQTT
  Future<void> setConnectionMode(ConnectionMode mode) async {
    _connectionMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('connection_mode', mode.index);
    notifyListeners();
    fetchStatus();
  }

  // تفعيل الواي فاي والاتصال التلقائي بشبكة الـ ESP32
  Future<void> autoConnectToVehicleWifi() async {
    try {
      debugPrint("📶 جاري التحقق من حالة الواي فاي وتفعيلها...");

      bool isWifiEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isWifiEnabled) {
        await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: false);
        await Future.delayed(const Duration(seconds: 2));
      }

      final prefs = await SharedPreferences.getInstance();
      String targetSSID = prefs.getString('saved_wifi_ssid') ?? "COROLLA";
      String targetPassword = prefs.getString('saved_wifi_password') ?? "12345678";

      debugPrint("🚀 محاولة الاتصال التلقائي بشبكة: $targetSSID");

      bool connectResult = await WiFiForIoTPlugin.connect(
        targetSSID,
        password: targetPassword,
        security: NetworkSecurity.WPA,
        joinOnce: false,
      );

      if (connectResult) {
        debugPrint("✅ تم الاتصال بنجاح!");
        await WiFiForIoTPlugin.forceWifiUsage(true);
        fetchStatus();
      } else {
        debugPrint("❌ فشل الاتصال التلقائي.");
      }
    } catch (e) {
      debugPrint("⚠️ خطأ شبكة أثناء محاولة الاتصال: $e");
    }
  }

  Future<void> toggleLanguage() async {
    _isArabic = !_isArabic;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_arabic', _isArabic);
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
  }

  Future<void> updateAppPassword(String newPassword) async {
    _appPassword = newPassword.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_password', _appPassword);
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    await updateAppPassword(newPassword);
  }

  Future<void> updateBaseUrl(String newUrl) async {
    String cleanUrl = newUrl.replaceAll('http://', '').replaceAll('/', '').trim();

    final prefs = await SharedPreferences.getInstance();
    if (isMqttServerMode) {
      _nodeRedServerIp = cleanUrl;
      await prefs.setString('nodered_ip_address', _nodeRedServerIp);
    } else {
      _esp32DirectIp = cleanUrl;
      await prefs.setString('car_ip_address', _esp32DirectIp);
    }
    notifyListeners();
  }

  // 🚀 تشغيل المحرك التتابعي الذكي
  Future<void> startEngineFullyDirectly() async {
    try {
      debugPrint("🚀 جاري بدء تتابع التشغيل الذكي للمركبة...");
      await sendCommand('I'); // فتح السويتش
      await Future.delayed(const Duration(milliseconds: 1500));
      await sendCommand('S'); // ضرب سلف (والـ ESP32 سيفصله تلقائياً بحماية الكود)
      debugPrint("✅ تم إرسال أمر تشغيل المحرك بالكامل!");
    } catch (e) {
      debugPrint("❌ فشل تتابع التشغيل التلقائي: $e");
    }
  }

  // 🔔 دالة تشغيل / إطفاء السيرفر (خاصة بمسار Node-RED و MQTT والتنبيهات)
  Future<void> toggleServerState(bool turnOn) async {
    try {
      final state = turnOn ? "SERVER_ON" : "SERVER_OFF";
      if (isMqttServerMode) {
        await http.get(
          Uri.parse('http://$_nodeRedServerIp/api/vehicle/command?cmd=$state'),
        ).timeout(const Duration(seconds: 3));
      } else {
        // في حال كنت في الوضع المباشر، ترسل تنبيهاً للسيرفر أيضاً
        await http.get(
          Uri.parse('http://$_nodeRedServerIp/api/vehicle/command?cmd=$state'),
        ).timeout(const Duration(seconds: 3));
      }
      debugPrint("✅ تم إرسال حالة السيرفر: $state");
    } catch (e) {
      debugPrint("❌ فشل إرسال حالة السيرفر: $e");
    }
  }

  // تحديث إعدادات الواي فاي في الـ ESP32
  Future<bool> updateWifiSettings(String ssid, String password) async {
    try {
      final targetIp = isMqttServerMode ? _esp32DirectIp : _esp32DirectIp;
      final response = await http.post(
        Uri.parse('http://$targetIp/api/wifi/update'),
        body: {
          'ssid': ssid,
          'password': password,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_wifi_ssid', ssid.trim());
        await prefs.setString('saved_wifi_password', password.trim());
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ خطأ شبكة أثناء إرسال إعدادات الواي فاي: $e");
      return false;
    }
  }

  void startStatusLoop() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      fetchStatus();
    });
  }

  void stopStatusLoop() {
    _statusTimer?.cancel();
  }

  // 📡 جلب الحالة (دايناميكي حسب الوضع المختار)
  Future<void> fetchStatus() async {
    try {
      final url = isMqttServerMode
          ? 'http://$_nodeRedServerIp/api/vehicle/status'
          : 'http://$_esp32DirectIp/api/status';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        _currentStatus = CarStatusModel.fromJson(jsonDecode(response.body));
        _isConnected = true;
      } else {
        _isConnected = false;
      }
    } catch (_) {
      _isConnected = false;
    }
    notifyListeners();
  }

  // ⚡ إرسال الأوامر (دايناميكي حسب الوضع المختار)
  Future<void> sendCommand(String cmd) async {
    try {
      final url = isMqttServerMode
          ? 'http://$_nodeRedServerIp/api/vehicle/command?cmd=$cmd'
          : 'http://$_esp32DirectIp/api/command?cmd=$cmd';

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _isConnected = true;
        fetchStatus();
      }
    } catch (_) {
      _isConnected = false;
      notifyListeners();
    }
  }

  Future<void> toggleGPIO(int pin, String action) async {
    try {
      final url = isMqttServerMode
          ? 'http://$_nodeRedServerIp/api/vehicle/command?cmd=$action'
          : 'http://$_esp32DirectIp/api/gpio?pin=$pin&action=$action';

      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      fetchStatus();
    } catch (_) {}
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}