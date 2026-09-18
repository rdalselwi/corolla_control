<div align="center">

#  Ultimate Smart Car Telemetry & Control System
# نظام التحكم الذكي للسيارات والقيادة المدمجة عن بعد

<p align="center">
  <b> A Professional IoT Mobile & Desktop Control System Built for ESP32, Node-RED & Flutter </b>
  <br>
  <b>نظام إنترنت أشياء متطور للتحكم عن بعد بالسيارة عبر ESP32، MQTT، والذكاء الاصطناعي</b>
</p>

<!-- Shields Badges -->
<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/ESP32-Microcontroller-E7352C?style=for-the-badge&logo=espressif&logoColor=white" alt="ESP32">
  <img src="https://img.shields.io/badge/Node--RED-IoT-8F0000?style=for-the-badge&logo=node-red&logoColor=white" alt="Node-RED">
  <img src="https://img.shields.io/badge/MQTT-Protocol-660066?style=for-the-badge&logo=mqtt&logoColor=white" alt="MQTT">
  <img src="https://img.shields.io/badge/License-MIT-F39C12?style=for-the-badge" alt="License">
</p>

<p align="center">
  <a href="https://github.com/rdalselwi"><img src="https://img.shields.io/badge/GitHub-rdalselwi-181717?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a>
  <a href="https://www.linkedin.com/in/raad-al-selwi-23202a421"><img src="https://img.shields.io/badge/LinkedIn-Raad%20Al--Selwi-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a>
  <a href="https://t.me/r1h_x"><img src="https://img.shields.io/badge/Telegram-@r1h__x-229ED9?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram"></a>
  <a href="mailto:r.dalselwi@gmail.com"><img src="https://img.shields.io/badge/Email-r.dalselwi@gmail.com-EA4335?style=for-the-badge&logo=gmail&logoColor=white" alt="Email"></a>
</p>

---

</div>

##  واجهات النظام (System Dashboards & UI)

<p align="center">
  <img src="CAR.jpg" alt="Telemetry & Speedometer" width="30%" height="500">
  &nbsp;&nbsp;
  <img src="CAR1.jpg" alt="Car Controls & Lights" width="30%" height="500">
  &nbsp;&nbsp;
  <img src="CAR2.jpg" alt="AI Assistant Chatbot" width="30%" height="500">
</p>
<p align="center">
  <img src="CAR3.jpg" alt="System Settings & Options" width="30%" height="500">
  &nbsp;&nbsp;
  <img src="CAR4.jpg" alt="Security Login & Gateway" width="30%" height="500">
</p>

---

##  نبذة عن المشروع (About The Project)

**Ultimate Smart Car Telemetry & Control System** هو نظام إنترنت أشياء متكامل مصمم للربط المباشر بين التطبيق والسيارة (Toyota Corolla) عبر متحكم **ESP32**. يتيح النظام مراقبة وتعديل حالة السيارة بالكامل لحظياً (Real-time telemetry)، بدءاً من تشغيل المحرك عن بعد، التحكم بالإضاءة والأبواب، مراقبة السرعة والحرارة (RPM & Temp)، وصولاً إلى مساعد ذكي مدمج (مساعد رعد الصلوي الذكي) للتفاعل الصوتي والنصي مع منظومة السيارة عبر بروتوكولات **MQTT** و **Wi-Fi**.

---

## ✨ المميزات والخصائص الرئيسية (Key Features)

1. **بوابة الأمان والتحقق المتقدم:** حماية النظام عبر رمز السر (PIN Code) أو بصمة الإصبع مع واجهة دخول فاخرة تحاكي أحدث أنظمة السيارات الرياضية.
2. **لوحة العدادات الحية (Live Telemetry):** عرض سرعة السيارة، عدد لفات المحرك (RPM)، درجة الحرارة، ومستوى الوقود بتصميم دائري عصري (Dark Glassmorphism).
3. **التحكم الكامل عن بعد:** إمكانية تشغيل وإطفاء المحرك، قفل وفتح الأبواب وباب الشنطة، والتحكم بالأضواء الأمامية والإضاءة المحيطية (حمراء وزرقاء).
4. **المساعد الذكي للسيارة (AI Assistant):** مساعد مدمج للإجابة على حالة السيارة، فحص الأعطال، وتدقيق الأمان بصوت ونصوص تفاعلية.
5. **الربط السحابي والمحلي (MQTT & Node-RED):** دعم التبديل السريع بين وضع السيرفر المركزي واتصال الـ MQTT لضمان استقرار الإرسال والاستقبال مع شريحة ESP32.

---

## 🛠️ المكونات التقنية وتقنيات الربط (Tech Stack & Architecture)

* **المتحكم الدقيق (Microcontroller):** ESP32 NodeMCU / ESP32-WROOM مع وحدة Wi-Fi مدمجة.
* **بروتوكول الاتصال:** MQTT Broker (HiveMQ / Local Broker) & WebSockets.
* **البرمجيات الوسيطة (Middleware):** Node-RED Dashboard 2.0 لإدارة التدفقات وقراءات المستشعرات.
* **تطبيق الواجهة (UI/UX):** تطوير عبر Flutter بتصميم Dark Glassmorphism مستوحى من أحدث منصات السيارات.
* **التنبيهات:** تكامل مع بوت التليجرام (Telegram Bot) لإرسال تنبيهات الطوارئ والسرقة وحالة المحرك.

---

## 📂 هيكلية ملفات المشروع (Project Directory Structure)

يحتوي المستودع على المجلدات والملفات الأساسية التالية الخاصة بمشروع Flutter:
* `lib/` : يحتوي على الشيفرات البرمجية لتطبيق الـ Flutter وتصاميم الواجهات.
* `assets/` : الموارد والأصول المستخدمة في التطبيق.
* `android/`, `ios/`, `windows/`, `linux/`, `macos/`, `web/` : مجلدات الدعم الخاصة بالمنصات المختلفة.
* `pubspec.yaml` : ملف إعدادات الحزم والاعتماديات الخاصة بالمشروع.


## 👨‍💻 المطور وحسابات التواصل (Developer & Contact)
تم تطوير وتصميم هذه المنظومة بواسطة المهندس رعد فهد عبده قائد الصلوي (Raad Al-Selwi):
* 🐙 GitHub: @rdalselwi
* 💼 LinkedIn: Raad Al-Selwi
* ✈️ Telegram: @r1h_x
* 📧 Email: r.dalselwi@gmail.com
## 📄 حقوق النشر والترخيص (License & Copyright)
جميع الحقوق محفوظة © 2026 المهندس رعد فهد عبده قائد الصلوي (Raad Al-Selwi).

All rights reserved © 2026 Raad Al-Selwi.
