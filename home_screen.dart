import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../core/network_service.dart';
import 'lock_screen.dart';
import 'voice_control_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAutoNightLight = false;
  bool _isVibrationDialogShowing = false;
  bool _isVibrationFeatureEnabled = true;
  bool _isBrakeStopFeatureEnabled = true;
  PageController? _pageController;
  int _currentPage = 0;
  double _currentSpeed = 0.0;
  bool _isSweeping = true;
  StreamSubscription<Position>? _positionStream;
  bool _isTrackingTrip = false;
  double _tripDistance = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Position? _lastPosition;

  // متغيرات حساب الوقود
  double _fuelLiters = 0.0;
  double _fuelRate = 0.0;

  // متغيرات ميزة العثور على السيارة
  bool _wasConnected = false;
  double? _savedCarLat;
  double? _savedCarLong;

  // المتغير الديناميكي لاسم المستخدم
  String _userName = "";

  // إعدادات ميزة الذكاء الاصطناعي مع رسالة ترحيب ديناميكية محدثة
  final List<Map<String, String>> _aiMessages = [
    {
      'role': 'assistant',
      'text': 'مرحباً مالك السيارة! أنا مساعد سيارتك الذكي المدعوم بالذكاء الاصطناعي. كيف يمكنني مساعدتك اليوم؟ 🚗✨'
    }
  ];

  bool _isAiTyping = false;
  final ScrollController _aiScrollController = ScrollController();

  final Map<String, Map<String, String>> _localizedStrings = {
    'ar': {
      'system_stable': 'المنظومة متصلة ومستقرة ✅',
      'system_offline': 'النظام غير متصل ⚠️',
      'vibration_alert': '🚨 تم رصد اهتزاز بالسيارة!',
      'vibration_dialog_title': '⚠️ تحذير أمني عاجل',
      'vibration_dialog_msg': 'تم رصد حركة أو اهتزاز غير طبيعي في السيارة. يرجى التحقق فوراً!',
      'close': 'إغلاق التنبيه',
      'online': 'متصل',
      'offline': 'غير متصل',
      'biometric_reason': 'الرجاء تبصيم الإصبع لتشغيل المحرك بالكامل فوراً 🚀',
      'biometric_not_supported': '⚠️ الهاتف لا يدعم الحماية بالبصمة!',
      'auth_success': '🚀 تم التحقق! جاري تشغيل المحرك بالتتابع الآمن...',
      'auth_error': '❌ خطأ في مستشعر البصمة: ',
      'wifi_title': 'تحديث شبكة ESP32',
      'wifi_ssid_label': 'اسم الشبكة الجديد (SSID)',
      'wifi_ssid_hint': 'مثال: Corolla_WiFi',
      'wifi_pass_label': 'كلمة مرور الشبكة الجديدة',
      'wifi_pass_hint': 'لا تقل عن 8 خانات',
      'cancel': 'إلغاء',
      'update_send': 'تحديث وإرسال',
      'wifi_sending': 'جاري إرسال إعدادات الشبكة...',
      'pass_title': 'تغيير رمز دخول التطبيق',
      'pass_old_label': 'رمز الدخول الحالي (السابق)',
      'pass_new_label': 'رمز الدخول الجديد',
      'pass_new_hint': 'أرقام فقط',
      'save_changes': 'حفظ التغيير',
      'pass_success': 'تم تحديث رمز الحماية بنجاح!',
      'night_light_on': '🌙 وضع القيادة الليلية نشط',
      'night_light_off': 'وضع الوضع التلقائي للإضاءة غير نشط',
      'door1': 'الباب ',
      'door2': 'باب الشنطة ',
      'red_led': 'الإضاءة الحمراء',
      'blue_led': 'الإضاءة الزرقاء',
      'high_beam': 'الضوء العالي',
      'headlights': 'المصابيح الأمامية',
      'open': 'مفتوح',
      'locked': 'مقفل',
      'active': 'مفتوح / نشط',
      'idle': 'مطفأ',
      'start': 'تشغيل',
      'start_eng': '',
      'kill_eng': '',
      'off_car': '',
      'menu_lang': 'تغيير اللغة',
      'menu_theme': 'تبديل المظهر (فاتح/داكن)',
      'menu_wifi': 'إعدادات الواي فاي',
      'menu_pass': 'تغيير رمز الحماية',
      'menu_about': 'حول التطبيق',
      'menu_trip': 'إعدادات الرحلة',
      'trip_settings_title': 'حساب مسافة الوقود',
      'fuel_liters': 'كمية البترول المعبأة (لتر)',
      'fuel_rate': 'معدل الاستهلاك (كم/لتر)',
      'reset_trip': 'إعادة الضبط',
      'app_name': 'Car Control',
      'app_version': '1.0.0',
      'all_rights': 'جميع الحقوق محفوظة لدى',
      'ok': 'حسناً',
      'vibrate_on': 'تم تشغيل حالة الاهتزاز',
      'vibrate_off': 'تم ايقاف حالة الاهتزاز',
      'brake_stop_on': 'تم تفعيل إيقاف السيارة عند البريك فقط',
      'brake_stop_off': 'تم تعطيل إيقاف السيارة عند البريك فقط',
      'trip_dist': 'المسافة',
      'trip_time': 'الوقت',
      'km': 'كم',
      'kmh': 'كم/س',
      'find_car': 'اعثر على سيارتي',
      'no_saved_location': 'لم يتم حفظ موقع للسيارة بعد!',
      'location_saved': '📍 تم حفظ موقع السيارة (انقطع الاتصال)',
      'menu_name': 'تعديل اسم المستخدم',
      'name_title': 'تعديل الاسم الشخصي',
      'name_label': 'اسم المستخدم الجديد',
      'name_hint': 'أدخل اسمك الجديد هنا',
      'name_success': 'تم تحديث اسمك بنجاح! 🎉',
      'menu_server_toggle': 'تشغيل/إيقاف السيرفر المركزي',
      'server_started': '🚀 تم إرسال أمر تشغيل السيرفر والإنذارات!',
      'server_stopped': '🛑 تم إرسال أمر إيقاف السيرفر!',
      'mode_direct': 'الوضع المباشر (ESP32)',
      'mode_server': 'وضع السيرفر وMQTT',
      'switch_mode': 'تبديل وضع الاتصال',
    },
    'en': {
      'system_stable': 'System Connected & Stable ✅',
      'system_offline': 'System is Offline ⚠️',
      'vibration_alert': '🚨 VIBRATION DETECTED!',
      'vibration_dialog_title': '⚠️ Urgent Security Alert',
      'vibration_dialog_msg': 'Unusual vibration or movement detected in the vehicle. Please check immediately!',
      'close': 'Dismiss',
      'online': 'ONLINE',
      'offline': 'OFFLINE',
      'biometric_reason': 'Please scan fingerprint to start engine immediately 🚀',
      'biometric_not_supported': '⚠️ Device does not support biometrics!',
      'auth_success': '🚀 Verified! Starting engine safely...',
      'auth_error': '❌ Biometric error: ',
      'wifi_title': 'Update ESP32 Network',
      'wifi_ssid_label': 'New Network Name (SSID)',
      'wifi_ssid_hint': 'e.g., Corolla_WiFi',
      'wifi_pass_label': 'New Network Password',
      'wifi_pass_hint': 'At least 8 characters',
      'cancel': 'Cancel',
      'update_send': 'Update & Send',
      'wifi_sending': 'Sending network settings...',
      'pass_title': 'Change App Passcode',
      'pass_old_label': 'Current Passcode',
      'pass_new_label': 'New Passcode',
      'pass_new_hint': 'Digits only',
      'save_changes': 'Save Changes',
      'pass_success': 'Passcode updated successfully!',
      'night_light_on': '🌙 Auto Night Light Mode Enabled',
      'night_light_off': 'Auto Night Light Inactive',
      'door1': 'DOOR ',
      'door2': 'TRUNK ',
      'red_led': 'RED LED',
      'blue_led': 'BLUE LED',
      'high_beam': 'HIGH BEAM',
      'headlights': 'HEADLIGHTS',
      'open': 'OPEN',
      'locked': 'LOCKED',
      'active': 'ON / ACTIVE',
      'idle': 'OFF',
      'start': '',
      'start_eng': '',
      'kill_eng': '',
      'off_car': '',
      'menu_lang': 'Change Language',
      'menu_theme': 'Toggle Theme',
      'menu_wifi': 'WiFi Settings',
      'menu_pass': 'Change Passcode',
      'menu_about': 'About App',
      'menu_trip': 'Trip Settings',
      'trip_settings_title': 'Fuel Range Calculator',
      'fuel_liters': 'Fuel Amount (Liters)',
      'fuel_rate': 'Consumption Rate (km/L)',
      'reset_trip': 'Reset',
      'app_name': 'Car Control',
      'app_version': '1.0.0',
      'all_rights': 'All rights reserved',
      'ok': 'OK',
      'vibrate_on': 'Vibration Enabled',
      'vibrate_off': 'Vibration Disabled',
      'brake_stop_on': 'Brake-Only Car Stop Enabled',
      'brake_stop_off': 'Brake-Only Car Stop Disabled',
      'trip_dist': 'Distance',
      'trip_time': 'Time',
      'km': 'km',
      'kmh': 'km/h',
      'find_car': 'Find My Car',
      'no_saved_location': 'No car location saved yet!',
      'location_saved': '📍 Car location saved (Disconnected)',
      'menu_name': 'Change Username',
      'name_title': 'Edit User Name',
      'name_label': 'New Username',
      'name_hint': 'Enter your new name here',
      'name_success': 'Name updated successfully! 🎉',
      'menu_server_toggle': 'Toggle Central Hub Server',
      'server_started': '🚀 Central Hub Server Started!',
      'server_stopped': '🛑 Central Hub Server Stopped!',
      'mode_direct': 'Direct Mode (ESP32)',
      'mode_server': 'Server & MQTT Mode',
      'switch_mode': 'Switch Connection Mode',
    }
  };

  @override
  void initState() {
    super.initState();
    _initPrefsAndController();
    _initSweepAnimation();
    _initLocationTracking();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = Provider.of<NetworkService>(context);
    if (_wasConnected && !server.isConnected) {
      _saveCarLocation(server.isArabic);
    }
    _wasConnected = server.isConnected;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    _pageController?.dispose();
    _aiScrollController.dispose();
    super.dispose();
  }

  Future<void> _initPrefsAndController() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('username') ?? "مالك السيارة";
    final savedPage = prefs.getInt('last_page') ?? 0;
    final savedLiters = prefs.getDouble('fuel_liters') ?? 0.0;
    final savedRate = prefs.getDouble('fuel_rate') ?? 0.0;
    final savedDistance = prefs.getDouble('trip_distance') ?? 0.0;
    final savedLat = prefs.getDouble('car_lat');
    final savedLong = prefs.getDouble('car_long');

    if (mounted) {
      setState(() {
        _userName = savedName;
        _currentPage = savedPage;
        _pageController = PageController(initialPage: _currentPage);
        _fuelLiters = savedLiters;
        _fuelRate = savedRate;
        _tripDistance = savedDistance;
        _savedCarLat = savedLat;
        _savedCarLong = savedLong;

        _aiMessages[0]['text'] = 'مرحباً $_userName! أنا مساعد سيارتك الذكي المدعوم بالذكاء الاصطناعي. كيف يمكنني مساعدتك اليوم؟ 🚗✨';
      });
    }
  }

  void _initSweepAnimation() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _currentSpeed = 240.0);
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _currentSpeed = 0.0;
          _isSweeping = false;
        });
      }
    });
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentSpeed = (position.speed * 3.6).clamp(0.0, 240.0);
          if (_currentSpeed > 1.0 && !_isTrackingTrip) {
            _isTrackingTrip = true;
            _stopwatch.start();
            _timer ??= Timer.periodic(const Duration(seconds: 1), (Timer t) {
              if (mounted) setState(() {});
            });
          }
          if (_isTrackingTrip && _lastPosition != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            _tripDistance += (distanceInMeters / 1000);
            SharedPreferences.getInstance().then((prefs) {
              prefs.setDouble('trip_distance', _tripDistance);
            });
          }
          _lastPosition = position;
        });
      }
    });
  }

  Future<void> _saveCarLocation(bool isArabic) async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('car_lat', position.latitude);
      await prefs.setDouble('car_long', position.longitude);
      if (mounted) {
        setState(() {
          _savedCarLat = position.latitude;
          _savedCarLong = position.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getTxt('location_saved', isArabic)), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      debugPrint("Error saving location: $e");
    }
  }

  Future<void> _findMyCar(bool isArabic) async {
    if (_savedCarLat != null && _savedCarLong != null) {
      final String googleMapsUrl = "https://www.google.com/maps/dir/?api=1&destination=$_savedCarLat,$_savedCarLong&travelmode=walking";
      await _launchURL(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getTxt('no_saved_location', isArabic)), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _toggleTripAndStart(NetworkService server) {
    server.sendCommand('I');
    setState(() {
      _isTrackingTrip = !_isTrackingTrip;
      if (_isTrackingTrip) {
        _tripDistance = 0.0;
        _lastPosition = null;
        _stopwatch.reset();
        _stopwatch.start();
        _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
          if (mounted) setState(() {});
        });
      } else {
        _stopwatch.stop();
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  String _getTxt(String key, bool isArabic) {
    return _localizedStrings[isArabic ? 'ar' : 'en']?[key] ?? '';
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw 'Could not launch $urlString';
    } catch (_) {
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  void _showTripSettingsDialog(BuildContext context, NetworkService server) {
    final TextEditingController litersController = TextEditingController(text: _fuelLiters > 0 ? _fuelLiters.toString() : '');
    final TextEditingController rateController = TextEditingController(text: _fuelRate > 0 ? _fuelRate.toString() : '');
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0B) : const Color(0xFFF2F2F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.teal, width: 1)),
        title: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.local_gas_station_rounded, color: Colors.teal),
            const SizedBox(width: 10),
            Text(_getTxt('trip_settings_title', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(_getTxt('fuel_liters', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: litersController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration('0.0', Icons.water_drop_outlined, isDarkMode)
              ),
              const SizedBox(height: 12),
              Text(_getTxt('fuel_rate', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration('0.0', Icons.speed_outlined, isDarkMode)
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        actions: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  setState(() {
                    _fuelLiters = 0.0;
                    _fuelRate = 0.0;
                    _tripDistance = 0.0;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('fuel_liters', 0.0);
                  await prefs.setDouble('fuel_rate', 0.0);
                  await prefs.setDouble('trip_distance', 0.0);
                  if (mounted) Navigator.pop(context);
                },
                child: Text(_getTxt('reset_trip', isArabic), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_getTxt('cancel', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: () async {
                  double parsedLiters = double.tryParse(litersController.text) ?? 0.0;
                  double parsedRate = double.tryParse(rateController.text) ?? 0.0;
                  setState(() {
                    _fuelLiters = parsedLiters;
                    _fuelRate = parsedRate;
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('fuel_liters', parsedLiters);
                  await prefs.setDouble('fuel_rate', parsedRate);
                  if (mounted) Navigator.pop(context);
                },
                child: Text(_getTxt('save_changes', isArabic), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutAppDialog(BuildContext context, bool isArabic, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF141416) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(_getTxt('menu_about', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                ClipOval(child: Image.asset('assets/app_icon1.png', width: 24, height: 24, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.info_outline, size: 22, color: Colors.teal))),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1), blurRadius: 12, offset: const Offset(0, 4))]),
              child: ClipOval(child: Image.asset('assets/app_icon1.png', width: 95, height: 95, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car_filled, size: 70, color: Color(0xFFFF1E1E)))),
            ),
            const SizedBox(height: 15),
            Text(_getTxt('app_name', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_getTxt('app_version', isArabic), style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.black54, fontSize: 14)),
            const SizedBox(height: 12),
            Text(_getTxt('all_rights', isArabic), style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, fontSize: 12)),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => _launchURL('tel:777572644'), icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.blueAccent, size: 28)),
                const SizedBox(width: 20),
                IconButton(onPressed: () => _launchURL('mailto:r.dalselwi.@Gmail.com'), icon: const Icon(Icons.email_outlined, color: Colors.teal, size: 28)),
                const SizedBox(width: 20),
                IconButton(onPressed: () => _launchURL('https://www.instagram.com/r.1h_x/'), icon: const Icon(Icons.linked_camera_outlined, color: Colors.pinkAccent, size: 28)),
              ],
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [TextButton(onPressed: () => Navigator.pop(context), child: Text(_getTxt('ok', isArabic), style: const TextStyle(color: Colors.teal, fontSize: 15, fontWeight: FontWeight.bold)))]),
          ],
        ),
      ),
    );
  }

  Future<void> _authenticateToStartEngine(bool isArabic) async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!mounted) return;
      if (!canCheckBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTxt('biometric_not_supported', isArabic)), backgroundColor: Colors.amber));
        return;
      }
      bool authenticated = await _auth.authenticate(localizedReason: _getTxt('biometric_reason', isArabic), options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true));
      if (!mounted) return;
      if (authenticated) {
        Provider.of<NetworkService>(context, listen: false).startEngineFullyDirectly();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTxt('auth_success', isArabic)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${_getTxt('auth_error', isArabic)}$e"), backgroundColor: Colors.red));
    }
  }

  void _logoutAndGoToLockScreen(NetworkService server) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LockScreen()), (Route<dynamic> route) => false);
  }

  void _triggerVibrationDialog(bool isArabic) {
    if (_isVibrationDialogShowing) return;
    _isVibrationDialogShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A0505),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFFF1E1E), width: 2)),
          title: Row(textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, children: [const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF1E1E), size: 28), const SizedBox(width: 10), Text(_getTxt('vibration_dialog_title', isArabic), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
          content: Text(_getTxt('vibration_dialog_msg', isArabic), textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() { _isVibrationDialogShowing = false; }); }, child: Text(_getTxt('ok', isArabic), style: const TextStyle(color: Colors.teal, fontSize: 15, fontWeight: FontWeight.bold)))],
        ),
      );
    });
  }

  void _showWifiSettingsDialog(BuildContext context, NetworkService server) {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController wifiPassController = TextEditingController();
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0B) : const Color(0xFFF2F2F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.blueAccent, width: 1)),
        title: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.wifi_find_rounded, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text(_getTxt('wifi_title', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(_getTxt('wifi_ssid_label', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: ssidController,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration(_getTxt('wifi_ssid_hint', isArabic), Icons.ssid_chart, isDarkMode)
              ),
              const SizedBox(height: 16),
              Text(_getTxt('wifi_pass_label', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: wifiPassController,
                  obscureText: true,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration(_getTxt('wifi_pass_hint', isArabic), Icons.password, isDarkMode)
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_getTxt('cancel', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              String newSsid = ssidController.text.trim();
              String newWifiPass = wifiPassController.text.trim();
              if (newSsid.isNotEmpty && newWifiPass.length >= 8) {
                server.updateWifiSettings(newSsid, newWifiPass);
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTxt('wifi_sending', isArabic)), backgroundColor: Colors.blue));
              }
            },
            child: Text(_getTxt('update_send', isArabic), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAppPasswordDialog(BuildContext context, NetworkService server) {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0B) : const Color(0xFFF2F2F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFFF1E1E), width: 1)),
        title: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFF1E1E)),
            const SizedBox(width: 10),
            Text(_getTxt('pass_title', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(_getTxt('pass_old_label', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: oldPassController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration("••••", Icons.lock_outline, isDarkMode)
              ),
              const SizedBox(height: 16),
              Text(_getTxt('pass_new_label', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: newPassController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration(_getTxt('pass_new_hint', isArabic), Icons.lock_reset, isDarkMode)
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_getTxt('cancel', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (oldPassController.text == server.appPassword && newPassController.text.length >= 4) {
                server.updateAppPassword(newPassController.text.trim());
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTxt('pass_success', isArabic)), backgroundColor: const Color(0xFFFF1E1E)));
              }
            },
            child: Text(_getTxt('save_changes', isArabic), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showChangeNameDialog(BuildContext context, NetworkService server) {
    final TextEditingController nameController = TextEditingController(text: _userName);
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF0A0A0B) : const Color(0xFFF2F2F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.blueAccent, width: 1)),
        title: Row(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.person_outline_rounded, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text(_getTxt('name_title', isArabic), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(_getTxt('name_label', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                  controller: nameController,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                  decoration: _dialogInputDecoration(_getTxt('name_hint', isArabic), Icons.person, isDarkMode)
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_getTxt('cancel', isArabic), style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('username', newName);
                setState(() {
                  _userName = newName;
                  _aiMessages[0]['text'] = isArabic
                      ? 'مرحباً $_userName! أنا مساعد سيارتك الذكي المدعوم بالذكاء الاصطناعي. كيف يمكنني مساعدتك اليوم؟ 🚗✨'
                      : 'Hello $_userName! I am your AI-powered smart car assistant. How can I help you today? 🚗✨';
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_getTxt('name_success', isArabic)), backgroundColor: Colors.teal));
                }
              }
            },
            child: Text(_getTxt('save_changes', isArabic), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String hint, IconData icon, bool isDarkMode) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDarkMode ? Colors.white24 : Colors.black38, fontSize: 13),
      filled: true,
      fillColor: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
      prefixIcon: Icon(icon, color: isDarkMode ? Colors.white38 : Colors.black45, size: 18),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.black12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF1E1E), width: 1)),
    );
  }

  Future<String> _callGeminiAPI(String prompt, NetworkService server) async {
    const String apiKey = "YOUR_GEMINI_API_KEY";
    final String url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey";

    final status = server.currentStatus;

    String isConnectedStr = server.isConnected ? "متصل ومستقر" : "غير متصل";
    String door1Str = (status?.door1 ?? false) ? "مفتوح" : "مغلق ومقفل";
    String door2Str = (status?.door2 ?? false) ? "مفتوح" : "مغلق ومقفل";
    String redLedStr = (status?.red ?? false) ? "مفتوحة/نشطة" : "مطفأة";
    String blueLedStr = (status?.blue ?? false) ? "مفتوحة/نشطة" : "مطفأة";
    String highBeamStr = (status?.light1 ?? false) ? "نشط" : "مطفأ";
    String headlightsStr = (status?.light2 ?? false) ? "نشط" : "مطفأ";
    String speedStr = _currentSpeed.toStringAsFixed(1);
    String distanceStr = _tripDistance.toStringAsFixed(2);
    String fuelLitersStr = _fuelLiters.toString();
    String fuelRateStr = _fuelRate.toString();
    String vibrationStr = (status?.vibrationAlert ?? false) ? "نشط (يوجد اهتزاز مشبوه!)" : "مستقر (لا يوجد اهتزاز)";
    String nightLightStr = _isAutoNightLight ? "نشط" : "غير نشط";

    final systemPrompt = "أنت مساعد الذكاء الاصطناعي المدمج في نظام السيارة الذكي للمستخدم $_userName. لديك وصول مباشر إلى بيانات السيارة الحالية عبر الحساسات والمتحكم ESP32. حالة السيارة الحالية هي:\n"
        "- الاتصال بالمتحكم: $isConnectedStr\n"
        "- الباب 1: $door1Str\n"
        "- باب الشنطة (الباب 2): $door2Str\n"
        "- الإضاءة الحمراء: $redLedStr\n"
        "- الإضاءة الزرقاء: $blueLedStr\n"
        "- الضوء العالي: $highBeamStr\n"
        "- المصابيح الأمامية: $headlightsStr\n"
        "- السرعة الحالية: $speedStr كم/ساعة\n"
        "- مسافة الرحلة الحالية: $distanceStr كم\n"
        "- كمية الوقود المعبأة: $fuelLitersStr لتر\n"
        "- معدل استهلاك الوقود: $fuelRateStr كم/لتر\n"
        "- التنبيه بالاهتزاز: $vibrationStr\n"
        "- وضع الإضاءة الليلية التلقائي: $nightLightStr\n\n"
        "أجب على أسئلة $_userName بدقة وبطريقة ذكية، ودودة ومختصرة (أجوبة تناسب شاشات السيارات والهاتف). تحدث باللغة العربية بأسلوب راقٍ وذكي مثل مساعد سيارات تيسلا الذكي. إذا طلب $_userName التحكم بشيء ما (مثال: تشغيل الإضاءة الحمراء)، فاشرح له أنه يمكنه استخدام الأزرار في لوحة التحكم الرئيسية مباشرة للقيام بذلك.";

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "systemInstruction": {
        "parts": [
          {"text": systemPrompt}
        ]
      }
    };

    int delaySeconds = 1;
    for (int i = 0; i < 5; i++) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final text = decoded['candidates']?[0]?['content']?[0]?['text'] ?? decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "عذراً، لم أستطع معالجة الرد.";
          return text;
        } else {
          debugPrint("Gemini API Error Code: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        debugPrint("Exception during Gemini API Call: $e");
      }
      await Future.delayed(Duration(seconds: delaySeconds));
      delaySeconds *= 2;
    }

    return "عذراً $_userName، حدث خطأ في الاتصال بخوادم الذكاء الاصطناعي. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.";
  }

  void _showAIAssistantBottomSheet(BuildContext context, NetworkService server) {
    final TextEditingController messageController = TextEditingController();
    final bool isDarkMode = server.isDarkMode;
    final bool isArabic = server.isArabic;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF0D0D10) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void sendMessage(String text) async {
              if (text.trim().isEmpty) return;
              setModalState(() {
                _aiMessages.add({'role': 'user', 'text': text});
                _isAiTyping = true;
              });
              messageController.clear();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_aiScrollController.hasClients) {
                  _aiScrollController.animateTo(
                    _aiScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
              });
              final response = await _callGeminiAPI(text, server);
              if (mounted) {
                setModalState(() {
                  _aiMessages.add({'role': 'assistant', 'text': response});
                  _isAiTyping = false;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_aiScrollController.hasClients) {
                    _aiScrollController.animateTo(
                      _aiScrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.65,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.purple.withAlpha(40),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isArabic ? "مساعد $_userName الذكي ✦" : "$_userName's AI Assistant ✦",
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDarkMode ? Colors.white54 : Colors.black54),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    Expanded(
                      child: ListView.builder(
                        controller: _aiScrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _aiMessages.length + (_isAiTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _aiMessages.length && _isAiTyping) {
                            return _buildAiTypingIndicator(isDarkMode);
                          }
                          final msg = _aiMessages[index];
                          final isUser = msg['role'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blueAccent.withAlpha(200) : (isDarkMode ? const Color(0xFF1B1B1E) : const Color(0xFFF0F0F3)),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isUser ? const Radius.circular(0) : const Radius.circular(16),
                                  bottomRight: isUser ? const Radius.circular(16) : const Radius.circular(0),
                                ),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                                textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildQuickChip(isArabic ? "📊 فحص حالة السيارة" : "📊 Car Status", () => sendMessage(isArabic ? "أعطني تقريراً شاملاً عن حالة سيارتي الحالية" : "Give me a full status report of my car"), isDarkMode),
                          _buildQuickChip(isArabic ? "⛽ كفاءة الوقود" : "⛽ Fuel Efficiency", () => sendMessage(isArabic ? "كيف يمكنني تحسين استهلاك الوقود الحالي؟" : "How can I optimize my current fuel consumption?"), isDarkMode),
                          _buildQuickChip(isArabic ? "🔒 تدقيق أمان السيارة" : "🔒 Security Check", () => sendMessage(isArabic ? "هل هناك أي ثغرات أو تحذيرات أمنية لسيارتي؟" : "Are there any security warnings or vulnerability checks?"), isDarkMode),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: isArabic ? "اسأل الذكاء الاصطناعي عن سيارتك..." : "Ask AI about your car...",
                              hintStyle: TextStyle(color: isDarkMode ? Colors.white30 : Colors.black38, fontSize: 13),
                              filled: true,
                              fillColor: isDarkMode ? const Color(0xFF141416) : const Color(0xFFF2F2F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => sendMessage(messageController.text),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.purpleAccent,
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: isDarkMode ? const Color(0xFF1A1A1D) : const Color(0xFFE5E5EA),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: Text(label, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildAiTypingIndicator(bool isDarkMode) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1B1B1E) : const Color(0xFFF0F0F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              return Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGauges(bool isDarkMode, bool isArabic, Color neonColor, double availableHeight) {
    String formattedTime = "${_stopwatch.elapsed.inHours.toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}";
    double simulatedRpm = 0.0;
    if (_isSweeping) {
      simulatedRpm = (_currentSpeed / 240.0) * 8.0;
    } else {
      simulatedRpm = (_currentSpeed < 1) ? 0.8 : (1.8 + ((_currentSpeed % 40) / 40) * 4.2);
    }
    double simulatedTemp = 50.0 + (_isSweeping ? ((_currentSpeed / 240.0) * 40.0) : (_stopwatch.elapsed.inSeconds * 0.6).clamp(0, 40));

    double currentFuelRange = (_fuelLiters * _fuelRate) - _tripDistance;
    if (currentFuelRange < 0) currentFuelRange = 0.0;

    double mainGaugeHeight = availableHeight * 0.55;
    double sideGaugeSize = availableHeight * 0.22;
    if (sideGaugeSize > 130) sideGaugeSize = 130;
    if (sideGaugeSize < 85) sideGaugeSize = 85;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          height: mainGaugeHeight,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 240,
                interval: 20,
                startAngle: 150,
                endAngle: 30,
                radiusFactor: 1.0,
                axisLineStyle: AxisLineStyle(thickness: 12, color: isDarkMode ? Colors.white12 : Colors.black12, thicknessUnit: GaugeSizeUnit.logicalPixel),
                majorTickStyle: MajorTickStyle(color: isDarkMode ? Colors.white : Colors.black87, thickness: 1.5),
                axisLabelStyle: GaugeTextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: availableHeight < 500 ? 8 : 10),
                pointers: <GaugePointer>[
                  NeedlePointer(
                    value: _currentSpeed,
                    needleLength: 0.7,
                    needleColor: neonColor,
                    enableAnimation: _isSweeping,
                    animationDuration: 500,
                    knobStyle: KnobStyle(knobRadius: 0.08, color: isDarkMode ? const Color(0xFF141416) : Colors.white, borderColor: neonColor),
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_currentSpeed.toInt().toString(), style: TextStyle(fontSize: availableHeight < 500 ? 22 : 30, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                        Text(_getTxt('kmh', isArabic), style: TextStyle(fontSize: availableHeight < 500 ? 8 : 10, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white54 : Colors.black54)),
                      ],
                    ),
                    angle: 90,
                    positionFactor: 0.70,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: availableHeight < 500 ? -availableHeight * 0.12 : -availableHeight * 0.16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: sideGaugeSize,
                      height: sideGaugeSize,
                      child: _buildSideGauge(isDarkMode, neonColor, simulatedRpm, 0, 8, 2, "RPM", "x1000", 6, true, availableHeight),
                    ),
                    SizedBox(width: availableHeight < 500 ? 20 : 40),
                    SizedBox(
                      width: sideGaugeSize,
                      height: sideGaugeSize,
                      child: _buildSideGauge(isDarkMode, neonColor, simulatedTemp, 50, 130, 40, "TEMP", "°C", 110, false, availableHeight),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 5.0, left: 8.0, right: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildTripInfoBadge(Icons.route_rounded, "${_tripDistance.toStringAsFixed(1)} ${_getTxt('km', isArabic)}", isDarkMode)),
              const SizedBox(width: 6),
              Expanded(child: _buildTripInfoBadge(Icons.timer_outlined, formattedTime, isDarkMode)),
              const SizedBox(width: 6),
              Expanded(child: _buildTripInfoBadge(Icons.local_gas_station_rounded, "${currentFuelRange.toStringAsFixed(1)} ${_getTxt('km', isArabic)}", isDarkMode)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSideGauge(bool isDarkMode, Color neonColor, double value, double min, double max, double interval, String label, String unit, double redStart, bool isRpm, double availableHeight) {
    bool isSmallScreen = availableHeight < 500;
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: min,
          maximum: max,
          interval: interval,
          startAngle: 150,
          endAngle: 30,
          radiusFactor: 0.95,
          axisLineStyle: AxisLineStyle(thickness: isSmallScreen ? 6 : 10, color: isDarkMode ? Colors.white12 : Colors.black12, thicknessUnit: GaugeSizeUnit.logicalPixel),
          majorTickStyle: MajorTickStyle(color: isDarkMode ? Colors.white : Colors.black87, thickness: 1.0, length: isSmallScreen ? 4 : 6),
          minorTickStyle: MinorTickStyle(color: isDarkMode ? Colors.white24 : Colors.black12, length: isSmallScreen ? 2 : 3),
          axisLabelStyle: GaugeTextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 7 : 9),
          pointers: <GaugePointer>[
            NeedlePointer(
              value: value,
              needleLength: 0.6,
              needleColor: neonColor,
              knobStyle: KnobStyle(knobRadius: isSmallScreen ? 0.08 : 0.1, color: isDarkMode ? const Color(0xFF141416) : Colors.white, borderColor: neonColor),
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: isSmallScreen ? 7 : 8, color: isDarkMode ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold)),
                  Text(
                      isRpm ? value.toStringAsFixed(1) : value.toInt().toString(),
                      style: TextStyle(fontSize: isSmallScreen ? 10 : 12, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)
                  ),
                ],
              ),
              angle: 90,
              positionFactor: isSmallScreen ? 0.75 : 0.85,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripInfoBadge(IconData icon, String value, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(10), border: Border.all(color: (isDarkMode ? Colors.white : Colors.black).withAlpha(15))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 12),
          const SizedBox(width: 4),
          Flexible(child: Text(value, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildLowerContent(NetworkService server, bool isArabic, bool isDarkMode, dynamic status, Color neonColor, double pageHeight) {
    return Column(
      children: [
        SizedBox(
          height: pageHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) async {
              setState(() {
                _currentPage = index;
              });
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('last_page', index);
            },
            children: [
              LayoutBuilder(
                  builder: (context, gridConstraints) {
                    double cellWidth = (gridConstraints.maxWidth - 32) / 3;
                    double cellHeight = (gridConstraints.maxHeight - 16) / 2;
                    double dynamicRatio = cellWidth / cellHeight;
                    if (dynamicRatio < 0.7) dynamicRatio = 0.72;
                    if (dynamicRatio > 0.95) dynamicRatio = 0.85;
                    return GridView.count(
                      physics: const BouncingScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: dynamicRatio,
                      children: [
                        _buildSmartGraphicCell(
                            _getTxt('door1', isArabic),
                            (status?.door1 ?? false) ? _getTxt('open', isArabic) : _getTxt('locked', isArabic),
                            "assets/door1_handle_dark.png",
                            "assets/door1_handle_light.png",
                                () => server.toggleGPIO(18, "D"),
                            status?.door1 ?? false,
                            isDarkMode
                        ),
                        _buildSmartGraphicCell(_getTxt('red_led', isArabic), (status?.red ?? false) ? _getTxt('active', isArabic) : _getTxt('idle', isArabic), "assets/red_led_panel_dark.png", "assets/red_led_panel_light.png", () => server.toggleGPIO(19, "R"), status?.red ?? false, isDarkMode),
                        _buildSmartGraphicCell(_getTxt('high_beam', isArabic), (status?.light1 ?? false) ? _getTxt('active', isArabic) : _getTxt('idle', isArabic), "assets/high_beam_icon_dark.png", "assets/high_beam_icon_light.png", () => server.toggleGPIO(16, "L"), status?.light1 ?? false, isDarkMode),
                        _buildSmartGraphicCell(
                            _getTxt('door2', isArabic),
                            (status?.door2 ?? false) ? _getTxt('open', isArabic) : _getTxt('locked', isArabic),
                            "assets/door2_handle_dark.png",
                            "assets/door2_handle_light.png",
                                () => server.toggleGPIO(17, "T"),
                            status?.door2 ?? false,
                            isDarkMode
                        ),
                        _buildSmartGraphicCell(_getTxt('blue_led', isArabic), (status?.blue ?? false) ? _getTxt('active', isArabic) : _getTxt('idle', isArabic), "assets/blue_led_panel_dark.png", "assets/blue_led_panel_light.png", () => server.toggleGPIO(21, "B"), status?.blue ?? false, isDarkMode),
                        _buildSmartGraphicCell(_getTxt('headlights', isArabic), (status?.light2 ?? false) ? _getTxt('active', isArabic) : _getTxt('idle', isArabic), "assets/headlights_icon_dark.png", "assets/headlights_icon_light.png", () => server.toggleGPIO(15, "H"), status?.light2 ?? false, isDarkMode),
                      ],
                    );
                  }
              ),
              Center(
                child: _buildDashboardGauges(isDarkMode, isArabic, neonColor, pageHeight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentPage == 0 ? 18 : 6,
              decoration: BoxDecoration(color: _currentPage == 0 ? neonColor : (isDarkMode ? Colors.white30 : Colors.black26), borderRadius: BorderRadius.circular(10)),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentPage == 1 ? 18 : 6,
              decoration: BoxDecoration(color: _currentPage == 1 ? neonColor : (isDarkMode ? Colors.white30 : Colors.black26), borderRadius: BorderRadius.circular(10)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = Provider.of<NetworkService>(context);
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;
    final status = server.currentStatus;
    bool isVibrating = (status?.vibrationAlert ?? false) && _isVibrationFeatureEnabled;
    if (isVibrating) {
      _triggerVibrationDialog(isArabic);
    }
    final Color currentBg = isVibrating ? const Color(0xFF3A0000) : (isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
    final Color currentInverseColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    const Color logoRed = Color(0xFF880808);
    const Color neonColor = Color(0xFFFF1E1E);
    const Color permanentWhiteText = Colors.white;
    if (_pageController == null) {
      return Scaffold(backgroundColor: currentBg, body: const Center(child: CircularProgressIndicator(color: neonColor)));
    }
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    Widget contentBody = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    splashColor: neonColor.withAlpha(102),
                    highlightColor: neonColor.withAlpha(51),
                    onTap: () => _logoutAndGoToLockScreen(server),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA), border: Border.all(color: neonColor.withAlpha(76))),
                      child: const Icon(Icons.home_outlined, color: neonColor, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: (isDarkMode ? Colors.white : Colors.black).withAlpha(13)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: server.isConnected ? Colors.green : logoRed, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        server.isConnected
                            ? (server.isMqttServerMode ? "MQTT HUB" : _getTxt('online', isArabic))
                            : _getTxt('offline', isArabic),
                        style: TextStyle(
                            color: server.isConnected ? Colors.green : logoRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w900
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    splashColor: Colors.purpleAccent.withAlpha(102),
                    highlightColor: Colors.purpleAccent.withAlpha(51),
                    onTap: () => _showAIAssistantBottomSheet(context, server),
                    child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withAlpha(80),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 18)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    splashColor: Colors.blueAccent.withAlpha(102),
                    highlightColor: Colors.blueAccent.withAlpha(51),
                    onTap: () => _findMyCar(isArabic),
                    child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA)),
                        child: const Icon(Icons.location_on_outlined, color: Colors.blueAccent, size: 18)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    splashColor: neonColor.withAlpha(102),
                    highlightColor: neonColor.withAlpha(51),
                    onTap: () => _authenticateToStartEngine(isArabic),
                    child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA)),
                        child: const Icon(Icons.fingerprint_rounded, color: Colors.greenAccent, size: 18)
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    splashColor: const Color(0xFFFF1E1E).withAlpha(102),
                    highlightColor: const Color(0xFFFF1E1E).withAlpha(51),
                    onTap: () => VoiceControlDialog.show(context, isArabic: isArabic, isDarkMode: isDarkMode),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDarkMode ? const Color(0xFF141416) : const Color(0xFFE5E5EA),
                        border: Border.all(color: const Color(0xFFFF1E1E).withAlpha(100), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF1E1E).withAlpha(60),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mic_rounded, color: Color(0xFFFF1E1E), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Theme(
                  data: Theme.of(context).copyWith(cardColor: isDarkMode ? const Color(0xFF141416) : const Color(0xFFF2F2F7)),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.menu_rounded, color: (isDarkMode ? Colors.white : Colors.black).withAlpha(204), size: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: (isDarkMode ? Colors.white : Colors.black).withAlpha(13))),
                    onSelected: (value) {
                      if (value == 'toggle_server') {
                        bool currentMqtt = server.isMqttServerMode;
                        server.toggleServerState(!currentMqtt);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(!currentMqtt ? _getTxt('server_started', isArabic) : _getTxt('server_stopped', isArabic)),
                            backgroundColor: !currentMqtt ? Colors.green : Colors.redAccent,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (value == 'switch_connection_mode') {
                        final newMode = server.isMqttServerMode ? ConnectionMode.directESP32 : ConnectionMode.serverNodeRed;
                        server.setConnectionMode(newMode);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(newMode == ConnectionMode.serverNodeRed ? _getTxt('mode_server', isArabic) : _getTxt('mode_direct', isArabic)),
                            backgroundColor: Colors.teal,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (value == 'lang') {
                        server.toggleLanguage();
                      } else if (value == 'theme') {
                        server.toggleTheme();
                      } else if (value == 'trip_settings') {
                        _showTripSettingsDialog(context, server);
                      } else if (value == 'night_light') {
                        setState(() {
                          _isAutoNightLight = !_isAutoNightLight;
                        });
                        server.sendCommand(_isAutoNightLight ? 'N' : 'n');
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isAutoNightLight ? _getTxt('night_light_on', isArabic) : _getTxt('night_light_off', isArabic)), duration: const Duration(seconds: 1), backgroundColor: _isAutoNightLight ? neonColor : Colors.grey[800]));
                      } else if (value == 'wifi') {
                        _showWifiSettingsDialog(context, server);
                      } else if (value == 'pass') {
                        _showAppPasswordDialog(context, server);
                      } else if (value == 'change_name') {
                        _showChangeNameDialog(context, server);
                      } else if (value == 'vibration_toggle') {
                        setState(() {
                          _isVibrationFeatureEnabled = !_isVibrationFeatureEnabled;
                        });
                        server.sendCommand(_isVibrationFeatureEnabled ? 'V' : 'v');
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVibrationFeatureEnabled ? _getTxt('vibrate_off', isArabic) : _getTxt('vibrate_on', isArabic)), duration: const Duration(seconds: 1), backgroundColor: _isVibrationFeatureEnabled ? Colors.green : Colors.grey[800]));
                      } else if (value == 'brake_stop_toggle') {
                        setState(() {
                          _isBrakeStopFeatureEnabled = !_isBrakeStopFeatureEnabled;
                        });
                        server.sendCommand(_isBrakeStopFeatureEnabled ? 'B' : 'b');
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isBrakeStopFeatureEnabled ? _getTxt('brake_stop_off', isArabic) : _getTxt('brake_stop_on', isArabic)), duration: const Duration(seconds: 1), backgroundColor: _isBrakeStopFeatureEnabled ? Colors.green : Colors.grey[800]));
                      } else if (value == 'about') {
                        _showAboutAppDialog(context, isArabic, isDarkMode);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'toggle_server',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_getTxt('menu_server_toggle', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)),
                            const Icon(Icons.cloud_sync_rounded, color: Colors.tealAccent, size: 18),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'switch_connection_mode',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(server.isMqttServerMode ? _getTxt('mode_server', isArabic) : _getTxt('mode_direct', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)),
                            Icon(server.isMqttServerMode ? Icons.router_rounded : Icons.wifi_tethering_rounded, color: Colors.amberAccent, size: 18),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(color: Colors.white12),
                      PopupMenuItem(value: 'lang', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_lang', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.language_rounded, color: permanentWhiteText, size: 18)])),
                      PopupMenuItem(value: 'trip_settings', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_trip', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.local_gas_station_rounded, color: Colors.teal, size: 18)])),
                      PopupMenuItem(value: 'night_light', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_isAutoNightLight ? _getTxt('night_light_on', isArabic) : _getTxt('night_light_off', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), Icon(_isAutoNightLight ? Icons.nights_stay_rounded : Icons.nights_stay_outlined, color: _isAutoNightLight ? neonColor : permanentWhiteText, size: 18)])),
                      PopupMenuItem(value: 'theme', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_theme', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), Icon(isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: Colors.amber, size: 18)])),
                      PopupMenuDivider(color: isDarkMode ? Colors.white12 : Colors.black12),
                      PopupMenuItem(value: 'change_name', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_name', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.person_outline_rounded, color: Colors.blueAccent, size: 18)])),
                      PopupMenuItem(value: 'wifi', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_wifi', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.wifi_find_rounded, color: Colors.blueAccent, size: 18)])),
                      PopupMenuItem(value: 'pass', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_pass', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.admin_panel_settings_rounded, color: logoRed, size: 18)])),
                      PopupMenuItem(value: 'vibration_toggle', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_isVibrationFeatureEnabled ? _getTxt('vibrate_off', isArabic) : _getTxt('vibrate_on', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), Icon(Icons.vibration_rounded, color: _isVibrationFeatureEnabled ? neonColor : Colors.greenAccent, size: 18)])),
                      PopupMenuItem(value: 'brake_stop_toggle', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_isBrakeStopFeatureEnabled ? _getTxt('brake_stop_off', isArabic) : _getTxt('brake_stop_on', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), Icon(Icons.car_crash_outlined, color: _isBrakeStopFeatureEnabled ? neonColor : Colors.greenAccent, size: 18)])),
                      PopupMenuItem(value: 'about', child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_getTxt('menu_about', isArabic), style: const TextStyle(color: permanentWhiteText, fontSize: 13, fontWeight: FontWeight.bold)), const Icon(Icons.info_outline, color: Colors.teal, size: 18)])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, constraints) {
            final double panelHeight = constraints.maxWidth * 0.32;
            final double startBtnSize = panelHeight * 1.12;
            return SizedBox(
              height: panelHeight + 35,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: double.infinity,
                      height: panelHeight,
                      decoration: BoxDecoration(
                        color: currentInverseColor,
                        borderRadius: BorderRadius.circular(panelHeight / 2),
                        border: Border.all(color: logoRed.withAlpha(204), width: 1.5),
                      ),
                      child: Padding(
                        padding: EdgeInsets.only(left: startBtnSize * 0.90, right: 16.0),
                        child: Row(
                          textDirection: TextDirection.ltr,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor: neonColor.withAlpha(102),
                                  highlightColor: neonColor.withAlpha(51),
                                  onTapDown: (_) => server.sendCommand('S'),
                                  onTapUp: (_) => server.sendCommand('s'),
                                  onTapCancel: () => server.sendCommand('s'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(child: FractionallySizedBox(widthFactor: 0.70, child: _buildAdaptiveImage(darkPath: "assets/start_engine_btn_dark.png", lightPath: "assets/start_engine_btn_light.png", isDarkMode: isDarkMode))),
                                      const SizedBox(height: 4),
                                      Text(_getTxt('start_eng', isArabic), style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  splashColor: neonColor.withAlpha(102),
                                  highlightColor: neonColor.withAlpha(51),
                                  onTap: () => server.sendCommand('O'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(child: FractionallySizedBox(widthFactor: 0.70, child: _buildAdaptiveImage(darkPath: "assets/off_car_btn_dark.png", lightPath: "assets/off_car_btn_light.png", isDarkMode: isDarkMode))),
                                      const SizedBox(height: 4),
                                      Text(_getTxt('off_car', isArabic), style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -5,
                    bottom: 12,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        splashColor: neonColor.withAlpha(102),
                        highlightColor: neonColor.withAlpha(51),
                        onTap: () => _toggleTripAndStart(server),
                        child: SizedBox(
                          width: startBtnSize,
                          height: startBtnSize,
                          child: _buildAdaptiveImage(darkPath: 'assets/start_btn_dark.png', lightPath: 'assets/start_btn_light.png', isDarkMode: isDarkMode),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        isLandscape ? SizedBox(
          height: 400,
          child: _buildLowerContent(server, isArabic, isDarkMode, status, neonColor, 380),
        ) : Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double pageHeight = constraints.maxHeight - 20;
              return _buildLowerContent(server, isArabic, isDarkMode, status, neonColor, pageHeight);
            },
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: currentBg,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isVibrating ? [const Color(0xFF3A0000), const Color(0xFF1A0000), const Color(0xFF3A0000)] : (isDarkMode ? [const Color(0xFF000000), const Color(0xFF000000), const Color(0xFF000000)] : [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)]),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: isLandscape ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: contentBody,
            ) : contentBody,
          ),
        ),
      ),
    );
  }

  Widget _buildSmartGraphicCell(String title, String subtitle, String darkAsset, String lightAsset, VoidCallback onTap, bool isOn, bool isDarkMode) {
    const Color neonColor = Color(0xFFFF1E1E);
    final Color idleTextColor = isDarkMode ? const Color(0xFF9A9A9E) : const Color(0xFF555559);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: neonColor.withAlpha(64),
        highlightColor: neonColor.withAlpha(25),
        onTap: onTap,
        child: LayoutBuilder(
            builder: (context, constraints) {
              double circleSize = constraints.maxWidth * 0.78;
              if (circleSize > 84) circleSize = 84;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode ? Colors.black : const Color(0xFFFFFFFF),
                      border: Border.all(
                        color: isOn ? neonColor.withAlpha(229) : (isDarkMode ? Colors.white.withAlpha(15) : Colors.black.withAlpha(25)),
                        width: isOn ? 2.5 : 1.2,
                      ),
                      boxShadow: isOn ? [BoxShadow(color: neonColor.withAlpha(89), blurRadius: 12, spreadRadius: 1)] : [],
                    ),
                    child: ClipOval(child: Padding(padding: const EdgeInsets.all(6.0), child: _buildAdaptiveImage(darkPath: darkAsset, lightPath: lightAsset, fit: BoxFit.contain, isDarkMode: isDarkMode))),
                  ),
                  const SizedBox(height: 5),
                  Text(title, style: TextStyle(color: isDarkMode ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E), fontSize: 10.5, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(color: isOn ? neonColor : idleTextColor, fontSize: 8.5, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              );
            }
        ),
      ),
    );
  }

  Widget _buildAdaptiveImage({
    required String darkPath,
    required String lightPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    required bool isDarkMode
  }) {
    return Image.asset(isDarkMode ? darkPath : lightPath, width: width, height: height, fit: fit);
  }
}
