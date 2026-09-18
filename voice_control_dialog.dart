import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../core/network_service.dart';

class VoiceControlDialog extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const VoiceControlDialog({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  static Future<void> show(BuildContext context, {required bool isArabic, required bool isDarkMode}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceControlDialog(isArabic: isArabic, isDarkMode: isDarkMode),
    );
  }

  @override
  State<VoiceControlDialog> createState() => _VoiceControlDialogState();
}

class _VoiceControlDialogState extends State<VoiceControlDialog> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  String _lastWords = '';
  String _commandFeedback = '';
  bool _isExecutingStep = false;
  int _currentStepIndex = 0;
  List<String> _executionSteps = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _manualTextController = TextEditingController();
  Timer? _listeningTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // بدء الاستماع التلقائي عند فتح النافذة
    _startListening();
  }

  @override
  void dispose() {
    _listeningTimer?.cancel();
    _pulseController.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _commandFeedback = widget.isArabic
          ? "🎙️ الوميض الصوتي نشط! جاري الاستماع لأمرك (مثل: OK CAR، تشغيل السيارة، اطفاء...)"
          : "🎙️ Voice Pulse Active! Listening for command (e.g., OK CAR, start car, off...)";
    });

    _listeningTimer?.cancel();
    // محاكاة نبض الاستماع المستمر
    _listeningTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _isListening) {
        setState(() {});
      }
    });
  }

  void _stopListening() {
    _listeningTimer?.cancel();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processSpokenText(String text) {
    if (text.isEmpty) return;
    final lower = text.toLowerCase().trim();

    setState(() {
      _lastWords = text;
    });

    // 1. كلمة التفعيل "OK CAR"
    if (lower.contains("ok car") ||
        lower.contains("اوكي كار") ||
        lower.contains("أوكي كار") ||
        lower.contains("اوك كار") ||
        lower.contains("أوك كار")) {
      setState(() {
        _commandFeedback = widget.isArabic
            ? "⚡ تم التقاط كلمة التفعيل (OK CAR)! تفضل بأمرك الصوتي..."
            : "⚡ Trigger Word (OK CAR) Detected! Speak your command...";
      });

      String cleanText = lower
          .replaceAll("ok car", "")
          .replaceAll("اوكي كار", "")
          .replaceAll("أوكي كار", "")
          .replaceAll("اوك كار", "")
          .replaceAll("أوك كار", "")
          .trim();

      if (cleanText.isNotEmpty) {
        _processCommand(cleanText);
      } else {
        _startListening();
      }
      return;
    }

    _processCommand(lower);
  }

  Future<void> _processCommand(String text) async {
    final server = Provider.of<NetworkService>(context, listen: false);
    final isAr = widget.isArabic;

    // أ. تشغيل السيارة بخطواتها
    if (text.contains("تشغيل السيارة") ||
        text.contains("تشغيل محرك") ||
        text.contains("تشغيل المحرك") ||
        text.contains("شغل السيارة") ||
        text.contains("شغل المحرك") ||
        text.contains("اشتغل") ||
        text.contains("start car") ||
        text.contains("start engine")) {
      await _executeCarStartSequence(server);
      return;
    }

    // ب. إطفاء السيارة
    if (text.contains("اطفاء السيارة") ||
        text.contains("إطفاء السيارة") ||
        text.contains("اطفاء المحرك") ||
        text.contains("إطفاء المحرك") ||
        text.contains("طفي السيارة") ||
        text.contains("طفي المحرك") ||
        text.contains("أطفئ السيارة") ||
        text.contains("أطفئ المحرك") ||
        (text.contains("اطفاء") && !text.contains("الضوء")) ||
        (text.contains("إطفاء") && !text.contains("الضوء")) ||
        text.contains("stop car") ||
        text.contains("turn off car")) {
      await server.sendCommand('O');
      setState(() {
        _commandFeedback = isAr ? "🛑 تم إرسال أمر إطفاء السيارة بالكامل!" : "🛑 Vehicle OFF command sent successfully!";
      });
      return;
    }

    // ج. الضوء الأحمر - تشغيل
    if (text.contains("تشغيل الضوء الاحمر") ||
        text.contains("تشغيل الضوء الأحمر") ||
        text.contains("شغل الضوء الاحمر") ||
        text.contains("شغل الضوء الأحمر") ||
        text.contains("الضوء الاحمر تشغيل") ||
        text.contains("الضوء الأحمر تشغيل") ||
        text.contains("شغل الاحمر") ||
        text.contains("شغل الأحمر") ||
        text.contains("red light on")) {
      await server.toggleGPIO(19, "on");
      setState(() {
        _commandFeedback = isAr ? "🔴 تم تشغيل الضوء الأحمر للسيارة" : "🔴 Red Light turned ON";
      });
      return;
    }

    // د. الضوء الأحمر - إطفاء
    if (text.contains("اطفاء الضوء الاحمر") ||
        text.contains("إطفاء الضوء الأحمر") ||
        text.contains("طفي الضوء الاحمر") ||
        text.contains("طفي الضوء الأحمر") ||
        text.contains("الضوء الاحمر اطفاء") ||
        text.contains("الضوء الأحمر إطفاء") ||
        text.contains("طفي الاحمر") ||
        text.contains("طفي الأحمر") ||
        text.contains("red light off")) {
      await server.toggleGPIO(19, "off");
      setState(() {
        _commandFeedback = isAr ? "🔴 تم إطفاء الضوء الأحمر للسيارة" : "🔴 Red Light turned OFF";
      });
      return;
    }

    // هـ. الضوء الأزرق - تشغيل
    if (text.contains("تشغيل الضوء الازرق") ||
        text.contains("تشغيل الضوء الأزرق") ||
        text.contains("شغل الضوء الازرق") ||
        text.contains("شغل الضوء الأزرق") ||
        text.contains("الضوء الازرق تشغيل") ||
        text.contains("الضوء الأزرق تشغيل") ||
        text.contains("شغل الازرق") ||
        text.contains("شغل الأزرق") ||
        text.contains("blue light on")) {
      await server.toggleGPIO(21, "on");
      setState(() {
        _commandFeedback = isAr ? "🔵 تم تشغيل الضوء الأزرق للسيارة" : "🔵 Blue Light turned ON";
      });
      return;
    }

    // و. الضوء الأزرق - إطفاء
    if (text.contains("اطفاء الضوء الازرق") ||
        text.contains("إطفاء الضوء الأزرق") ||
        text.contains("طفي الضوء الازرق") ||
        text.contains("طفي الضوء الأزرق") ||
        text.contains("الضوء الازرق اطفاء") ||
        text.contains("الضوء الأزرق إطفاء") ||
        text.contains("طفي الازرق") ||
        text.contains("طفي الأزرق") ||
        text.contains("blue light off")) {
      await server.toggleGPIO(21, "off");
      setState(() {
        _commandFeedback = isAr ? "🔵 تم إطفاء الضوء الأزرق للسيارة" : "🔵 Blue Light turned OFF";
      });
      return;
    }

    // ز. عرض حالة السيارة
    if (text.contains("حالة السيارة") ||
        text.contains("عرض حالة السيارة") ||
        text.contains("كيف حالة السيارة") ||
        text.contains("هل السيارة شغالة") ||
        text.contains("حالة المحرك") ||
        text.contains("وضع السيارة") ||
        text.contains("status") ||
        text.contains("car status")) {
      _showCarStatusSummary(server);
      return;
    }

    setState(() {
      _commandFeedback = isAr
          ? "❓ لم أستطع التعرف على الأمر \"$text\". يرجى تجربة: (OK CAR، تشغيل السيارة، اطفاء، تشغيل الضوء الاحمر/الازرق، حالة السيارة)"
          : "❓ Unrecognized command: \"$text\". Try saying: OK CAR, start car, off, red light on, status";
    });
  }

  Future<void> _executeCarStartSequence(NetworkService server) async {
    final isAr = widget.isArabic;
    setState(() {
      _isExecutingStep = true;
      _currentStepIndex = 1;
      _executionSteps = isAr
          ? [
              "⚡ خطوة 1: تشغيل الطبلون الكهربائي (Ignition ON)...",
              "⛽ خطوة 2: تهيئة ضخ البنزين وكمبيوتر السيارة...",
              "🚀 خطوة 3: الضغط المستمر على السلف (Starter ON)...",
              "✅ خطوة 4: تم تشغيل المحرك بالكامل بنجاح!",
            ]
          : [
              "⚡ Step 1: Ignition ON...",
              "⛽ Step 2: Fuel Pump Priming...",
              "🚀 Step 3: Engaging Starter...",
              "✅ Step 4: Engine Started Fully!",
            ];
      _commandFeedback = _executionSteps[0];
    });

    // 1. Ignition ON
    await server.sendCommand('I');
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _currentStepIndex = 2;
      _commandFeedback = _executionSteps[1];
    });

    // 2. Priming delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _currentStepIndex = 3;
      _commandFeedback = _executionSteps[2];
    });

    // 3. Starter ON
    await server.sendCommand('S');
    await Future.delayed(const Duration(milliseconds: 1500));

    // 4. Starter OFF
    await server.sendCommand('s');

    if (!mounted) return;
    setState(() {
      _currentStepIndex = 4;
      _isExecutingStep = false;
      _commandFeedback = _executionSteps[3];
    });
  }

  void _showCarStatusSummary(NetworkService server) {
    final status = server.currentStatus;
    final isAr = widget.isArabic;

    bool isRunning = (status?.starts != 0) || (status?.state == "ENGINE_RUNNING");
    String engineStatusStr = isAr
        ? (isRunning ? "🚀 المحرك يعمل (السيارة شغالة)" : "🔴 المحرك مطفأ (السيارة متوقفة)")
        : (isRunning ? "🚀 Engine Running" : "🔴 Engine Off");

    String redLightStr = (status?.red ?? false) ? (isAr ? "نشطة 🟢" : "Active 🟢") : (isAr ? "مطفأة ⚪" : "Off ⚪");
    String blueLightStr = (status?.blue ?? false) ? (isAr ? "نشطة 🟢" : "Active 🟢") : (isAr ? "مطفأة ⚪" : "Off ⚪");
    String connStr = server.isConnected ? (isAr ? "متصل بالسيارة ✅" : "Connected ✅") : (isAr ? "غير متصل ❌" : "Offline ❌");

    setState(() {
      _commandFeedback = isAr
          ? "📊 حالة السيارة التفصيلية:\n"
            "• الاتصال بالمتحكم: $connStr\n"
            "• وضع التشغيل: $engineStatusStr\n"
            "• الضوء الأحمر: $redLightStr\n"
            "• الضوء الأزرق: $blueLightStr"
          : "📊 Detailed Car Status:\n"
            "• Connection: $connStr\n"
            "• Engine State: $engineStatusStr\n"
            "• Red Light: $redLightStr\n"
            "• Blue Light: $blueLightStr";
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isArabic;
    final isDark = widget.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F7FA);
    final cardBg = isDark ? const Color(0xFF191922) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF1E1E).withAlpha(50),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag indicator
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF1E1E).withAlpha(30),
                    ),
                    child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFFFF1E1E), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? "التحكم الصوتي للسيارة" : "Voice Control",
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.black54),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),

          const SizedBox(height: 20),

          // 🌟 الوميض الصوتي المرئي التفاعلي (Voice Pulse & Waves Visualizer) 🌟
          Center(
            child: GestureDetector(
              onTap: () {
                if (_isListening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  double scale = _isListening ? _pulseAnimation.value : 1.0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer pulse aura 2
                      Container(
                        width: 135 * scale,
                        height: 135 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF1E1E).withAlpha(_isListening ? 30 : 10),
                        ),
                      ),
                      // Outer pulse aura 1
                      Container(
                        width: 110 * scale,
                        height: 110 * scale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF1E1E).withAlpha(_isListening ? 65 : 20),
                        ),
                      ),
                      // Core mic glow circle
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF1E1E), Color(0xFF880000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1E1E).withAlpha(130),
                              blurRadius: 16,
                              spreadRadius: 3,
                            )
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Status indication text
          Text(
            _isListening
                ? (isAr ? "🎙️ الوميض الصوتي يعمل! تحدث بأمرك الآن أو قل OK CAR" : "🎙️ Voice Pulse Active! Say your command or OK CAR")
                : (isAr ? "انقر على الميكروفون للبدء بالتحكم الصوتي" : "Tap microphone to start voice control"),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isListening ? const Color(0xFFFF1E1E) : (isDark ? Colors.white60 : Colors.black54),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          // Last Spoken Word Display
          if (_lastWords.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF1E1E).withAlpha(70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over, color: Color(0xFFFF1E1E), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "\"$_lastWords\"",
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          if (_lastWords.isNotEmpty) const SizedBox(height: 12),

          // Feedback & Progress Step Display Box
          if (_commandFeedback.isNotEmpty)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isExecutingStep ? const Color(0xFF2A1500) : cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isExecutingStep ? Colors.orangeAccent : const Color(0xFFFF1E1E).withAlpha(100),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isExecutingStep) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.orangeAccent),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? "جاري تشغيل السيارة بالتتابع..." : "Starting Engine Step-by-Step...",
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _currentStepIndex / 4.0,
                      backgroundColor: Colors.white10,
                      color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _commandFeedback,
                    style: TextStyle(
                      color: _isExecutingStep ? Colors.orangeAccent : (isDark ? Colors.greenAccent : Colors.green[800]),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Quick Commands Selector
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              isAr ? "💡 اختر أمراً صوتياً لتفيذه فوراً:" : "💡 Select a Voice Command:",
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickCommandChip("⚡ OK CAR", isDark, () => _processSpokenText("OK CAR")),
                _buildQuickCommandChip("🚀 تشغيل السيارة", isDark, () => _processSpokenText("تشغيل السيارة")),
                _buildQuickCommandChip("🛑 إطفاء السيارة", isDark, () => _processSpokenText("اطفاء السيارة")),
                _buildQuickCommandChip("🔴 تشغيل الضوء الأحمر", isDark, () => _processSpokenText("تشغيل الضوء الاحمر")),
                _buildQuickCommandChip("🔴 إطفاء الضوء الأحمر", isDark, () => _processSpokenText("اطفاء الضوء الاحمر")),
                _buildQuickCommandChip("🔵 تشغيل الضوء الأزرق", isDark, () => _processSpokenText("تشغيل الضوء الازرق")),
                _buildQuickCommandChip("🔵 إطفاء الضوء الأزرق", isDark, () => _processSpokenText("اطفاء الضوء الازرق")),
                _buildQuickCommandChip("📊 حالة السيارة", isDark, () => _processSpokenText("عرض حالة السيارة")),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Input Text Box
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualTextController,
                  style: TextStyle(color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isAr ? "أو اكتب أمراً صوتياً هنا..." : "Or type command here...",
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      _processSpokenText(val);
                      _manualTextController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  if (_manualTextController.text.trim().isNotEmpty) {
                    _processSpokenText(_manualTextController.text);
                    _manualTextController.clear();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCommandChip(String label, bool isDark, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF22222E) : const Color(0xFFEEEEEE),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: onTap,
      ),
    );
  }
}
