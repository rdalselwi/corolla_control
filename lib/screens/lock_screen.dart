import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network_service.dart';
import 'home_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final LocalAuthentication _auth = LocalAuthentication();

  bool _isFirstTimeSetup = false;
  String _errorMessage = "";
  bool _canCheckBiometrics = false;

  final Map<String, String> _carModels = {
    'corolla': 'تويوتا كورولا / Toyota Corolla',
    'camry': 'تويوتا كامري / Toyota Camry',
    'yaris': 'تويوتا يارس / Toyota Yaris',
    'prado': 'برادو / Prado',
    'bmw_m5': 'بي ام دبليو ام 5 / BMW M5',
    'bmw_m5_24': 'بي ام دبليو ام 5 2024 / BMW M5 2024',
    'bmw_m3': 'بي ام دبليو ام 3 / BMW M3',
    'mercedes_90': 'مرسيدس 90 / Mercedes 90',
    'mercedes_24': 'مرسيدس 2024 / Mercedes 2024',
    'tesla': 'تسلا / Tesla',
    'accent_17': 'اكسنت 2017 / Accent 2017',
    'santafe_24': 'سنتافي 2024 / Santafe 2024',
    'kia_rio': 'كيا ريو / Kia Rio',
  };
  String _selectedCarKey = 'corolla';

  final Map<String, Map<String, String>> _localizedStrings = {
    'ar': {
      'sub_title_setup': 'تهيئة النظام وإنشاء مستخدم جديد',
      'sub_title_lock': 'البوابة الآمنة للمنظومة الذكية',
      'ip_label': 'عنوان الـ IP للمتحكم',
      'code_label': 'أدخل رمز الدخول السري',
      'biometric_reason': 'الرجاء مسح البصمة للدخول الآمن لمنظومة السيارة',
      'biometric_hint': 'اضغط ضغطة سريعة لفتح قفل التطبيق 🔓',
      'btn_setup': 'حفظ وتهيئة المنظومة',
      'btn_unlock': 'الدخول اليدوي للسيارة',
      'has_account': 'لديك حساب سيارة مسجل؟ دخول',
      'no_account': 'تسجيل سيارة ومستخدم جديد',
      'err_empty': 'الرجاء التحقق من البيانات المدخلة',
      'err_save': 'فشل في حفظ إعدادات للسيارة',
      'err_incorrect': 'رمز الدخول أو عنوان IP غير صحيح',
      'err_biometric': 'حدث خطأ أثناء التحقق من البصمة',
      'menu_lang': 'تغيير اللغة إلى الإنجليزية',
      'menu_to_light': 'تبديل الوضع إلى نهاري',
      'menu_to_dark': 'تبديل الوضع إلى ليلي',
      'menu_about': 'حول التطبيق',
      'menu_cars': 'تغيير السيارة المحددة',
      'app_name': 'Car Control',
      'app_version': '1.0.0',
      'all_rights': 'جميع الحقوق محفوظة لدى',
      'ok': 'حسناً',
    },
    'en': {
      'sub_title_setup': 'System Setup & Create New User',
      'sub_title_lock': 'The Secure Gateway for the Smart System',
      'ip_label': 'IP ADDRESS',
      'code_label': 'ENTER SECURITY CODE',
      'biometric_reason': 'Please scan your fingerprint for secure access to the vehicle system',
      'biometric_hint': 'Tap to unlock the application using biometrics 🔓',
      'btn_setup': 'Save & Initialize System',
      'btn_unlock': 'Manual Unlock',
      'has_account': 'Already registered? Login',
      'no_account': 'Register Vehicle & New User',
      'err_empty': 'Please check the entered data',
      'err_save': 'Failed to save vehicle settings',
      'err_incorrect': 'Incorrect Passcode or IP Address',
      'err_biometric': 'An error occurred during biometric authentication',
      'menu_lang': 'Change Language to Arabic',
      'menu_to_light': 'Switch to Light Mode',
      'menu_to_dark': 'Switch to Dark Mode',
      'menu_about': 'About App',
      'menu_cars': 'Change Selected Vehicle',
      'app_name': 'Car Control',
      'app_version': '1.0.0',
      'all_rights': 'All rights reserved',
      'ok': 'OK',
    }
  };

  String _getTxt(String key, bool isArabic) {
    return _localizedStrings[isArabic ? 'ar' : 'en']?[key] ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadSavedConfiguration();

    // 📶 استدعاء متتابع آمن: تشغيل أوتوماتيكي صريح للواي فاي ثم الاتصال التلقائي بالمركبة فور قراءة الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final networkProvider = Provider.of<NetworkService>(context, listen: false);
        // استدعاء دالة الخدمة الذكية لتشغيل التابع والأقلمة مع عتاد الهاتف
        await networkProvider.autoConnectToVehicleWifi();
      }
    });
  }

  void _loadSavedConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isConfigured = prefs.getBool('is_system_configured') ?? false;

      // استرجاع السيارة المحفوظة مسبقاً، وإذا لم توجد نعتمد الافتراضية 'corolla'
      _selectedCarKey = prefs.getString('selected_car_key') ?? 'corolla';

      final server = Provider.of<NetworkService>(context, listen: false);

      // فحص آمن لدعم البصمة
      bool hasHardware = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();
      _canCheckBiometrics = hasHardware && isSupported;

      if (isConfigured) {
        _isFirstTimeSetup = false;
        if (server.baseUrl.isNotEmpty) {
          _ipController.text = server.baseUrl;
        }

        // لا نطلب البصمة تلقائياً إلا إذا كان الجهاز يدعمها ومجرب مسبقاً
        if (_canCheckBiometrics) {
          List<BiometricType> availableBiometrics = await _auth.getAvailableBiometrics();
          if (availableBiometrics.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _authenticate(server.isArabic);
            });
          }
        }
      } else {
        _ipController.text = "192.168.4.1";
        _isFirstTimeSetup = true;
      }
    } catch (e) {
      _ipController.text = "192.168.4.1";
      _isFirstTimeSetup = true;
      _canCheckBiometrics = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _authenticate(bool isArabic) async {
    if (!_canCheckBiometrics) return; // حماية إضافية لمنع الانهيار
    try {
      bool authenticated = await _auth.authenticate(
        localizedReason: _getTxt('biometric_reason', isArabic),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true, // يظهر واجهة النظام الرسمية للخطأ بدلاً من الانهيار
        ),
      );

      if (authenticated) {
        _unlock();
      }
    } catch (e) {
      // تفادي إظهار خطأ منبثق للمستخدمين الذين لا يملكون بصمة مفعلة
      debugPrint("Biometric Auth Error: $e");
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showCarSelectionDialog(BuildContext context, bool isArabic, bool isDarkMode, Color textColor, Color panelBg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _getTxt('menu_cars', isArabic),
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _carModels.length,
            itemBuilder: (context, index) {
              String key = _carModels.keys.elementAt(index);
              String name = _carModels.values.elementAt(index);
              bool isSelected = _selectedCarKey == key;

              return ListTile(
                title: Text(
                  name,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFF1E1E) : textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle_outline, color: Color(0xFFFF1E1E)) : null,
                onTap: () async {
                  setState(() {
                    _selectedCarKey = key;
                  });
                  // حفظ مفتاح السيارة الجديدة مباشرة في SharedPreferences عند الاختيار
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selected_car_key', key);

                  if (context.mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
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
                Text(
                  _getTxt('menu_about', isArabic),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                ClipOval(
                  child: Image.asset(
                    'assets/app_icon1.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.info_outline, size: 22, color: Colors.teal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/app_icon1.png',
                  width: 95,
                  height: 95,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_car_filled, size: 70, color: Color(0xFFFF1E1E)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _getTxt('app_name', isArabic),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getTxt('app_version', isArabic),
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getTxt('all_rights', isArabic),
              style: TextStyle(
                color: isDarkMode ? Colors.white38 : Colors.black38,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 25),

            // 🌐 صف الأيقونات التفاعلية للاتصال والتواصل الاجتماعي
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة الاتصال الهاتفي
                IconButton(
                  onPressed: () => _launchURL('tel:777572644'),
                  icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.blueAccent, size: 28),
                  tooltip: 'Call',
                ),
                const SizedBox(width: 20),
                // أيقونة البريد الإلكتروني
                IconButton(
                  onPressed: () => _launchURL('mailto:r.dalselwi.@Gmail.com'),
                  icon: const Icon(Icons.email_outlined, color: Colors.teal, size: 28),
                  tooltip: 'Email',
                ),
                const SizedBox(width: 20),
                // أيقونة إنستغرام (تم استخدام أيقونة الكاميرا والمنشورات لتمثيل إنستغرام برمجياً)
                IconButton(
                  onPressed: () => _launchURL('https://www.instagram.com/r.1h_x/'),
                  icon: const Icon(Icons.linked_camera_outlined, color: Colors.pinkAccent, size: 28),
                  tooltip: 'Instagram',
                ),
              ],
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                  child: Text(
                    _getTxt('ok', isArabic),
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _handleAction(NetworkService server) async {
    final bool isArabic = server.isArabic;
    setState(() => _errorMessage = "");
    final formattedIp = _ipController.text.trim();
    final password = _passController.text;

    if (formattedIp.isEmpty || password.length < 4) {
      setState(() => _errorMessage = _getTxt('err_empty', isArabic));
      return;
    }

    if (_isFirstTimeSetup) {
      try {
        server.updateBaseUrl(formattedIp);
        server.updatePassword(password);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_system_configured', true);
        // حفظ السيارة أيضاً كإجراء احتياطي عند التثبيت لأول مرة
        await prefs.setString('selected_car_key', _selectedCarKey);

        setState(() {
          _isFirstTimeSetup = false;
        });

        _unlock();
      } catch (e) {
        setState(() => _errorMessage = _getTxt('err_save', isArabic));
      }
    } else {
      if (formattedIp == server.baseUrl && password == server.appPassword) {
        _unlock();
      } else {
        setState(() => _errorMessage = _getTxt('err_incorrect', isArabic));
        _passController.clear();
      }
    }
  }

  void _unlock() {
    try {
      Provider.of<NetworkService>(context, listen: false).startStatusLoop();
    } catch (_) {}

    _passController.clear();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = Provider.of<NetworkService>(context);
    final bool isArabic = server.isArabic;
    final bool isDarkMode = server.isDarkMode;

    final Color currentBg = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color currentPanelBg = isDarkMode ? const Color(0xFF0A0A0B) : const Color(0xFFF2F2F7);
    final Color currentTextColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final Color currentFieldBg = isDarkMode ? const Color(0xFF060607) : const Color(0xFFE5E5EA);

    const Color logoRed = Color(0xFFFF1E1E);

    return Scaffold(
      backgroundColor: currentBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double availableHeight = constraints.maxHeight;
            double imagePercent = _isFirstTimeSetup ? 0.22 : 0.32;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        icon: Icon(
                            Icons.menu_rounded,
                            color: currentTextColor.withValues(alpha: 0.8),
                            size: 28
                        ),
                        color: currentPanelBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) {
                          if (value == 'theme') {
                            server.toggleTheme();
                          } else if (value == 'lang') {
                            server.toggleLanguage();
                          } else if (value == 'cars') {
                            _showCarSelectionDialog(context, isArabic, isDarkMode, currentTextColor, currentPanelBg);
                          } else if (value == 'about') {
                            _showAboutAppDialog(context, isArabic, isDarkMode);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'cars',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getTxt('menu_cars', isArabic), style: TextStyle(color: currentTextColor, fontSize: 14)),
                                const SizedBox(width: 15),
                                const Icon(Icons.directions_car_filled_rounded, color: logoRed, size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'theme',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(isDarkMode ? _getTxt('menu_to_light', isArabic) : _getTxt('menu_to_dark', isArabic), style: TextStyle(color: currentTextColor, fontSize: 14)),
                                const SizedBox(width: 15),
                                Icon(isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: isDarkMode ? Colors.amber : Colors.indigo, size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'lang',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getTxt('menu_lang', isArabic), style: TextStyle(color: currentTextColor, fontSize: 14)),
                                const SizedBox(width: 15),
                                Icon(Icons.language_rounded, color: currentTextColor.withValues(alpha: 0.6), size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'about',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getTxt('menu_about', isArabic), style: TextStyle(color: currentTextColor, fontSize: 14)),
                                const SizedBox(width: 15),
                                const Icon(Icons.info_outline, color: Colors.teal, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.2, end: 0.75),
                          duration: const Duration(seconds: 2),
                          curve: Curves.easeInOutSine,
                          builder: (context, value, child) {
                            return Container(
                              width: double.infinity,
                              height: availableHeight * imagePercent,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0.0, 0.0),
                                  radius: 0.7,
                                  colors: [
                                    logoRed.withValues(alpha: value),
                                    logoRed.withValues(alpha: value * 0.0),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: Image.asset(
                                    "assets/${_selectedCarKey}_${isDarkMode ? 'dark' : 'light'}.png",
                                    key: ValueKey(_selectedCarKey + isDarkMode.toString()),
                                    width: constraints.maxWidth * 0.85,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.directions_car_filled,
                                      size: 100,
                                      color: logoRed,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 6),
                        Text(
                          _isFirstTimeSetup ? _getTxt('sub_title_setup', isArabic) : _getTxt('sub_title_lock', isArabic),
                          style: TextStyle(color: currentTextColor.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: currentPanelBg,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: currentTextColor.withValues(alpha: 0.03)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: isDarkMode ? 0.4 : 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6)
                                )
                              ]
                          ),
                          child: Column(
                            crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (_isFirstTimeSetup) ...[
                                Text(_getTxt('ip_label', isArabic), style: const TextStyle(color: Color(0xFF534F4F), fontSize: 11, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _ipController,
                                  keyboardType: TextInputType.url,
                                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                  style: TextStyle(color: currentTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: "192.168.4.1",
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                    filled: true,
                                    fillColor: currentFieldBg,
                                    prefixIcon: Icon(Icons.router_rounded, color: currentTextColor.withValues(alpha: 0.4), size: 20),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: currentTextColor.withValues(alpha: 0.05))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: logoRed, width: 1.5)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              Text(_getTxt('code_label', isArabic), style: const TextStyle(color: Color(0xFF534F4F), fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passController,
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: isArabic ? TextAlign.right : TextAlign.left,
                                style: TextStyle(
                                    color: currentTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: _passController.text.isEmpty ? 0 : 8
                                ),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  counterText: "",
                                  hintText: "••••",
                                  hintStyle: TextStyle(color: isDarkMode ? Colors.white38 : Colors.black38, letterSpacing: 0),
                                  filled: true,
                                  fillColor: currentFieldBg,
                                  prefixIcon: Icon(Icons.lock_outline_rounded, color: currentTextColor.withValues(alpha: 0.4), size: 20),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: currentTextColor.withValues(alpha: 0.05))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: logoRed, width: 1.5)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                ),
                                onSubmitted: (_) => _handleAction(server),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (!_isFirstTimeSetup && _canCheckBiometrics) ...[
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _authenticate(isArabic),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: currentPanelBg,
                                      border: Border.all(color: logoRed.withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(Icons.fingerprint_rounded, color: logoRed, size: 46),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _getTxt('biometric_hint', isArabic),
                                  style: TextStyle(color: currentTextColor.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],

                        InkWell(
                          onTap: () => _handleAction(server),
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDarkMode ? const Color(0xFF080809) : const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: logoRed.withValues(alpha: 0.8), width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: logoRed.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    spreadRadius: 1
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                _isFirstTimeSetup ? _getTxt('btn_setup', isArabic) : _getTxt('btn_unlock', isArabic),
                                style: TextStyle(color: currentTextColor, fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ),
                          ),
                        ),

                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF1A0000) : const Color(0xFFFFD6D6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: logoRed.withValues(alpha: 0.2)),
                              ),
                              child: Text(_errorMessage, style: const TextStyle(color: logoRed, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                            ),
                          ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isFirstTimeSetup = !_isFirstTimeSetup;
                              _passController.clear();
                              _errorMessage = "";
                            });
                          },
                          child: Text(
                            _isFirstTimeSetup ? _getTxt('has_account', isArabic) : _getTxt('no_account', isArabic),
                            style: TextStyle(color: currentTextColor.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}