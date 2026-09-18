/**
* ============================================================
* نظام تشغيل السيارة عن بُعد — ON CAR
* ESP32 Firmware — Arduino IDE
* النسخة المستقرة: معالجة تذبذب الاتصال + الحفاظ على API ومسارات النظام + دعم MQTT
* ============================================================
*/

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <esp_wifi.h>
#include <PubSubClient.h>

// ══════════════════════════════════════════════════════════════
// إعدادات الواي فاي الافتراضية
// ══════════════════════════════════════════════════════════════
#define DEFAULT_WIFI_SSID        "COROLLA"
#define DEFAULT_WIFI_PASSWORD    "12345678"
#define WIFI_AP_CHANNEL          6
#define WIFI_AP_HIDDEN           0
#define WEB_SERVER_PORT          80

String currentWifiSSID;
String currentWifiPassword;

// إعدادات شبكة الـ MQTT (نقطة اتصال الكمبيوتر)
const char* sta_ssid     = "RAAD DESKTOP";
const char* sta_password = "R333333D";  
const char* mqtt_server  = "192.168.137.1";
const int   mqtt_port    = 1883;
const char* topic_cmd    = "corolla/control/cmd";
const char* topic_status = "corolla/status/json";

WiFiClient espClient;
PubSubClient mqttClient(espClient);

// ══════════════════════════════════════════════════════════════
// منافذ التحكم الأساسية في المحرك
// ══════════════════════════════════════════════════════════════
#define RELAY_IGNITION_PIN    23  // تشغيل الطبلون
#define RELAY_STARTER_PIN     22  // تشغيل السلف
#define RELAY_COILS_PIN       5   // تشغيل الكويلات والبخاخات
#define SPS_POWER_OFF_PIN     13  // إطفاء المنظومة بالكامل (الأمر 'O')

// منافذ الأضواء والأبواب
#define RELAY_LIGHT_RED_PIN   19
#define RELAY_LIGHT_BLUE_PIN  21
#define RELAY_DOOR_1_PIN      18
#define RELAY_DOOR_2_PIN      17
#define RELAY_LIGHT_1_PIN     16
#define RELAY_LIGHT_2_PIN     15

#define VIBRATION_SENSOR_PIN  14

#define PWM_FREQUENCY 5000
#define PWM_RESOLUTION 8
#define PWM_RED_CHANNEL 0
#define PWM_BLUE_CHANNEL 1

#define RELAY_ON   LOW
#define RELAY_OFF  HIGH

typedef enum {
  VEHICLE_OFF = 0,
  IGNITION_ON = 1,
  COILS_ON = 2,
  ENGINE_RUNNING = 3
} VehicleState;

VehicleState currentState = VEHICLE_OFF;

bool ignitionState = false;
bool coilsState = false;
bool starterState = false;

// مؤقت فصل السلف التلقائي الآمن (1.8 ثانية)
unsigned long starterStartTime = 0;
const unsigned long STARTER_MAX_DURATION = 1800;

// متغيرات حماية قفل السلف (مهلة الدقيقتين)
bool starterWindowStarted = false;
unsigned long starterAllowedWindowEndTime = 0;
bool starterBlocked = false;

bool redLightOn = false;
bool blueLightOn = false;
bool door1State = false;
bool door2State = false;
bool light1State = false;
bool light2State = false;

int redBrightness = 0;
int blueBrightness = 0;

unsigned long engineStartCount = 0;
unsigned long engineRunStartTime = 0;
unsigned long totalEngineTimeMs = 0;

bool lastVibrationState = LOW;
unsigned long lastVibrationTime = 0;
const unsigned long vibrationDebounce = 300;
bool vibrationAlertActive = false;
unsigned long vibrationAlertEndTime = 0;
int vibrationTriggerCount = 0;

WebServer webServer(WEB_SERVER_PORT);
Preferences prefs;

void publishStatusMQTT();
String getStatusJSON();
void toggleGPIO(int pin);
void setGPIO(int pin, bool state);

const char* stateName(VehicleState s) {
  switch (s) {
    case VEHICLE_OFF:      return "VEHICLE_OFF";
    case IGNITION_ON:      return "IGNITION_ON";
    case COILS_ON:         return "COILS_ON";
    case ENGINE_RUNNING:   return "ENGINE_RUNNING";
    default:               return "UNKNOWN";
  }
}

void setupPWM() {
  ledcSetup(PWM_RED_CHANNEL, PWM_FREQUENCY, PWM_RESOLUTION);
  ledcSetup(PWM_BLUE_CHANNEL, PWM_FREQUENCY, PWM_RESOLUTION);
  ledcAttachPin(RELAY_LIGHT_RED_PIN, PWM_RED_CHANNEL);
  ledcAttachPin(RELAY_LIGHT_BLUE_PIN, PWM_BLUE_CHANNEL);
  ledcWrite(PWM_RED_CHANNEL, 255);
  ledcWrite(PWM_BLUE_CHANNEL, 255);
}

void setRedBrightness(int value) {
  redBrightness = constrain(value, 0, 255);
  ledcWrite(PWM_RED_CHANNEL, 255 - redBrightness);
}

void setBlueBrightness(int value) {
  blueBrightness = constrain(value, 0, 255);
  ledcWrite(PWM_BLUE_CHANNEL, 255 - blueBrightness);
}

void safeKillEngine(const char* reason) {
  if (currentState == ENGINE_RUNNING && engineRunStartTime > 0) {
    totalEngineTimeMs += (millis() - engineRunStartTime);
    engineRunStartTime = 0;
  }

  digitalWrite(RELAY_STARTER_PIN, RELAY_OFF);
  digitalWrite(RELAY_COILS_PIN, RELAY_OFF);
  digitalWrite(RELAY_IGNITION_PIN, RELAY_OFF);

  ignitionState = false;
  coilsState = false;
  starterState = false;
  currentState = VEHICLE_OFF;

  starterWindowStarted = false;
  starterBlocked = false;
  starterAllowedWindowEndTime = 0;

  Serial.print("⚠️ SYSTEM FULL KILL: ");
  Serial.println(reason);

  digitalWrite(SPS_POWER_OFF_PIN, HIGH);
  delay(600);
  digitalWrite(SPS_POWER_OFF_PIN, LOW);

  publishStatusMQTT();
}

void processCommand(char cmd) {
  switch (cmd) {
    case 'I':
      if (!ignitionState && !coilsState) {
        digitalWrite(RELAY_IGNITION_PIN, RELAY_ON);
        digitalWrite(RELAY_COILS_PIN, RELAY_ON);
        ignitionState = true;
        coilsState = true;
        currentState = COILS_ON;
        Serial.println("✔ [Step 1] GPIO 23 & GPIO 5 -> BOTH ON");
      }
      else if (ignitionState && coilsState) {
        digitalWrite(RELAY_COILS_PIN, RELAY_OFF);
        coilsState = false;
        currentState = IGNITION_ON;
        Serial.println("✔ [Step 2] GPIO 5 -> OFF | GPIO 23 -> ON");
      }
      else if (ignitionState && !coilsState) {
        digitalWrite(RELAY_IGNITION_PIN, RELAY_OFF);
        ignitionState = false;
        currentState = VEHICLE_OFF;
        starterWindowStarted = false;
        starterBlocked = false;
        starterAllowedWindowEndTime = 0;
        Serial.println("✔ [Step 3] GPIO 23 -> OFF | System Reset");
      }
      break;

    case 'K':
      coilsState = !coilsState;
      if (coilsState) {
        digitalWrite(RELAY_COILS_PIN, RELAY_ON);
        if (ignitionState) currentState = COILS_ON;
      } else {
        digitalWrite(RELAY_COILS_PIN, RELAY_OFF);
        if (ignitionState) currentState = IGNITION_ON;
        else {
          currentState = VEHICLE_OFF;
          starterWindowStarted = false;
          starterBlocked = false;
        }
      }
      break;

    case 'S':
      if (ignitionState && coilsState) {
        if (starterBlocked) {
          Serial.println("⚠️ BLOCK: Starter Locked!");
          break;
        }

        if (!starterState) {
          digitalWrite(RELAY_STARTER_PIN, RELAY_ON);
          starterState = true;
          starterStartTime = millis();
          Serial.println("GPIO 22: STARTER ON");
    
          if (currentState != ENGINE_RUNNING) {
            currentState = ENGINE_RUNNING;
            engineStartCount++;
            engineRunStartTime = millis();
        
            if (!starterWindowStarted) {
              starterWindowStarted = true;
              starterAllowedWindowEndTime = millis() + 120000;
            }

            prefs.begin("car_system", false);
            prefs.putULong("startCount", engineStartCount);
            prefs.end();
          }
        } else {
          digitalWrite(RELAY_STARTER_PIN, RELAY_OFF);
          starterState = false;
          Serial.println("GPIO 22: STARTER OFF");
        }
      }
      break;

    case 's':
      digitalWrite(RELAY_STARTER_PIN, RELAY_OFF);
      starterState = false;
      Serial.println("GPIO 22: STARTER OFF (Released)");
      break;

    case 'O':
      safeKillEngine("Shutdown Command");
      break;

    case 'R':
    case 'r':
      toggleGPIO(RELAY_LIGHT_RED_PIN);
      Serial.println("💡 Red Light Toggled");
      break;

    case 'B':
    case 'b':
      toggleGPIO(RELAY_LIGHT_BLUE_PIN);
      Serial.println("💡 Blue Light Toggled");
      break;

    case 'D':
      toggleGPIO(RELAY_DOOR_1_PIN);
      Serial.println("🚪 Door 1 Toggled");
      break;

    case 'd':
      toggleGPIO(RELAY_DOOR_2_PIN);
      Serial.println("🚪 Door 2 Toggled");
      break;

    case 'L':
      toggleGPIO(RELAY_LIGHT_1_PIN);
      Serial.println("💡 Light 1 Toggled");
      break;

    case 'l':
      toggleGPIO(RELAY_LIGHT_2_PIN);
      Serial.println("💡 Light 2 Toggled");
      break;
  }
  publishStatusMQTT();
}

void toggleGPIO(int pin) {
  if (pin == RELAY_LIGHT_RED_PIN) {
    if (redBrightness == 0) setRedBrightness(255);
    else setRedBrightness(0);
    redLightOn = (redBrightness > 0);
    publishStatusMQTT();
    return;
  }
  else if (pin == RELAY_LIGHT_BLUE_PIN) {
    if (blueBrightness == 0) setBlueBrightness(255);
    else setBlueBrightness(0);
    blueLightOn = (blueBrightness > 0);
    publishStatusMQTT();
    return;
  }
  bool currentPinState = digitalRead(pin);
  digitalWrite(pin, !currentPinState);
  if (pin == RELAY_DOOR_1_PIN) door1State = !door1State;
  else if (pin == RELAY_DOOR_2_PIN) door2State = !door2State;
  else if (pin == RELAY_LIGHT_1_PIN) light1State = !light1State;
  else if (pin == RELAY_LIGHT_2_PIN) light2State = !light2State;
  publishStatusMQTT();
}

void setGPIO(int pin, bool state) {
  if (pin == RELAY_LIGHT_RED_PIN) { setRedBrightness(state ? 255 : 0); redLightOn = state; publishStatusMQTT(); return; }
  else if (pin == RELAY_LIGHT_BLUE_PIN) { setBlueBrightness(state ? 255 : 0); blueLightOn = state; publishStatusMQTT(); return; }
  digitalWrite(pin, state ? RELAY_ON : RELAY_OFF);
  if (pin == RELAY_DOOR_1_PIN) door1State = state;
  else if (pin == RELAY_DOOR_2_PIN) door2State = state;
  else if (pin == RELAY_LIGHT_1_PIN) light1State = state;
  else if (pin == RELAY_LIGHT_2_PIN) light2State = state;
  publishStatusMQTT();
}

void notifyVibrationDetected() {
  vibrationTriggerCount++;
  vibrationAlertActive = true;
  vibrationAlertEndTime = millis() + 5000;
  prefs.begin("car_system", false);
  prefs.putInt("vibCount", vibrationTriggerCount);
  prefs.end();
  publishStatusMQTT();
}

String getStatusJSON() {
  char jsonBuf[750];
  snprintf(jsonBuf, sizeof(jsonBuf),
    "{\"state\":\"%s\",\"red\":%s,\"blue\":%s,\"door1\":%s,\"door2\":%s,\"light1\":%s,\"light2\":%s,\"starts\":%lu,\"redBrightness\":%d,\"blueBrightness\":%d,\"vibrationAlert\":%s,\"vibrationCount\":%d,\"starterBlocked\":%s}",
    stateName(currentState), redLightOn ? "true":"false", blueLightOn ? "true":"false",
    door1State ? "true":"false", door2State ? "true":"false", light1State ? "true":"false", light2State ? "true":"false",
    engineStartCount, redBrightness, blueBrightness, vibrationAlertActive ? "true":"false", vibrationTriggerCount,
    starterBlocked ? "true":"false"
  );
  return String(jsonBuf);
}

void publishStatusMQTT() {
  if (mqttClient.connected()) {
    String payload = getStatusJSON();
    mqttClient.publish(topic_status, payload.c_str());
  }
}

void sendCrossOriginHeaders() {
  webServer.sendHeader("Access-Control-Allow-Origin", "*");
  webServer.sendHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  webServer.sendHeader("Access-Control-Allow-Headers", "*");
}

void handleOptions() { sendCrossOriginHeaders(); webServer.send(204); }

void handleUpdateWifi() {
  sendCrossOriginHeaders();
  if (webServer.hasArg("ssid") && webServer.hasArg("password")) {
    String newSSID = webServer.arg("ssid");
    String newPass = webServer.arg("password");
    if (newSSID.length() > 0 && newPass.length() >= 8) {
      prefs.begin("car_system", false);
      prefs.putString("wifi_ssid", newSSID);
      prefs.putString("wifi_pass", newPass);
      prefs.end();
      webServer.send(200, "application/json", "{\"status\":\"success\",\"message\":\"WiFi updated. Restarting...\"}");
      delay(1500);
      ESP.restart();
      return;
    }
  }
  webServer.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid SSID or Password\"}");
}

void handleGPIOCommand() {
  sendCrossOriginHeaders();
  if (webServer.hasArg("pin") && webServer.hasArg("action")) {
    int pin = webServer.arg("pin").toInt();
    String action = webServer.arg("action");
    if (action == "toggle") toggleGPIO(pin);
    else if (action == "on") setGPIO(pin, true);
    else if (action == "off") setGPIO(pin, false);
    webServer.send(200, "application/json", "{\"status\":\"ok\"}");
  }
}

void handlePWMCommand() {
  sendCrossOriginHeaders();
  if (webServer.hasArg("pin") && webServer.hasArg("value")) {
    int pin = webServer.arg("pin").toInt();
    int value = constrain(webServer.arg("value").toInt(), 0, 255);
    if (pin == RELAY_LIGHT_RED_PIN) { setRedBrightness(value); redLightOn = (value > 0); }
    else if (pin == RELAY_LIGHT_BLUE_PIN) { setBlueBrightness(value); blueLightOn = (value > 0); }
    webServer.send(200, "application/json", "{\"status\":\"ok\"}");
    publishStatusMQTT();
  }
}

void handleSPSPowerOff() {
  sendCrossOriginHeaders();
  webServer.send(200, "application/json", "{\"status\":\"power_off\"}");
  delay(100);
  safeKillEngine("SPS Web API");
}

void handleApiCommand() {
  sendCrossOriginHeaders();
  if (webServer.hasArg("cmd")) {
    String cmdArg = webServer.arg("cmd");
    if (cmdArg.length() > 0) processCommand(cmdArg[0]);
  }
  webServer.send(200, "text/plain", "OK");
}

void handleApiStatus() {
  sendCrossOriginHeaders();
  webServer.send(200, "application/json", getStatusJSON());
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("📩 [MQTT Recv] Topic: ");
  Serial.print(topic);
  Serial.print(" | Payload: ");

  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  message.trim();
  Serial.println(message);

  if (message == "SERVER_ON" || message == "STARTER_ON") {
    processCommand('S');
  } else if (message == "SERVER_OFF" || message == "STARTER_OFF") {
    processCommand('s');
  } else if (message.length() > 0) {
    processCommand(message[0]);
  } else {
    Serial.println("⚠️ Warning: Received empty or invalid payload.");
  }
}

void reconnectMQTT() {
  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    Serial.print("🔄 Connecting to MQTT Broker at ");
    Serial.print(mqtt_server);
    Serial.print("...");
  
    String clientId = "CorollaESP32_" + String(random(0xffff), HEX);
    if (mqttClient.connect(clientId.c_str())) {
      Serial.println(" CONNECTED!");
      if (mqttClient.subscribe(topic_cmd)) {
        Serial.print("✔ Subscribed to: ");
        Serial.println(topic_cmd);
      } else {
        Serial.println("❌ Failed to subscribe to cmd topic!");
      }
      publishStatusMQTT();
    } else {
      Serial.print(" FAILED, rc=");
      Serial.println(mqttClient.state());
    }
  }
}

void setupWebServer() {
  webServer.on("/api/command", HTTP_OPTIONS, handleOptions);
  webServer.on("/api/status", HTTP_OPTIONS, handleOptions);
  webServer.on("/api/gpio", HTTP_OPTIONS, handleOptions);
  webServer.on("/api/pwm", HTTP_OPTIONS, handleOptions);
  webServer.on("/api/power/sps_off", HTTP_OPTIONS, handleOptions);
  webServer.on("/api/wifi/update", HTTP_OPTIONS, handleOptions);

  webServer.on("/api/command", handleApiCommand);
  webServer.on("/api/status", handleApiStatus);
  webServer.on("/api/gpio", handleGPIOCommand);
  webServer.on("/api/pwm", handlePWMCommand);
  webServer.on("/api/power/sps_off", HTTP_POST, handleSPSPowerOff);
  webServer.on("/api/wifi/update", HTTP_POST, handleUpdateWifi);

  webServer.begin();
  Serial.println("WebServer Started!");
}

void setupPins() {
  digitalWrite(RELAY_IGNITION_PIN, RELAY_OFF);
  digitalWrite(RELAY_STARTER_PIN, RELAY_OFF);
  digitalWrite(RELAY_COILS_PIN, RELAY_OFF);
  digitalWrite(SPS_POWER_OFF_PIN, LOW);
  digitalWrite(RELAY_DOOR_1_PIN, RELAY_OFF);
  digitalWrite(RELAY_DOOR_2_PIN, RELAY_OFF);
  digitalWrite(RELAY_LIGHT_1_PIN, RELAY_OFF);
  digitalWrite(RELAY_LIGHT_2_PIN, RELAY_OFF);

  pinMode(RELAY_IGNITION_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(RELAY_STARTER_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(RELAY_COILS_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(SPS_POWER_OFF_PIN, OUTPUT);
  pinMode(RELAY_DOOR_1_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(RELAY_DOOR_2_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(RELAY_LIGHT_1_PIN, OUTPUT_OPEN_DRAIN);
  pinMode(RELAY_LIGHT_2_PIN, OUTPUT_OPEN_DRAIN);

  pinMode(VIBRATION_SENSOR_PIN, INPUT);
  setupPWM();
}

void readVibrationSensor() {
  bool currentVibrationState = digitalRead(VIBRATION_SENSOR_PIN);
  if (currentVibrationState != lastVibrationState && (millis() - lastVibrationTime) > vibrationDebounce) {
    lastVibrationTime = millis();
    notifyVibrationDetected();
  }
  lastVibrationState = currentVibrationState;
  if (vibrationAlertActive && millis() > vibrationAlertEndTime) {
    vibrationAlertActive = false;
  }
}

void checkStarterTimeout() {
  if (starterWindowStarted && !starterBlocked) {
    if (millis() > starterAllowedWindowEndTime) {
      starterBlocked = true;
      Serial.println("🔒 Starter Timeout Reached. Blocked.");
    }
  }
}

void setup() {
  Serial.begin(115200);
  setupPins();

  prefs.begin("car_system", false);
  engineStartCount = prefs.getULong("startCount", 0);
  totalEngineTimeMs = prefs.getULong("totalTime", 0);
  vibrationTriggerCount = prefs.getInt("vibCount", 0);
  currentWifiSSID = prefs.getString("wifi_ssid", DEFAULT_WIFI_SSID);
  currentWifiPassword = prefs.getString("wifi_pass", DEFAULT_WIFI_PASSWORD);
  prefs.end();

  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(false);

  WiFi.softAP(currentWifiSSID.c_str(), currentWifiPassword.c_str(), WIFI_AP_CHANNEL, WIFI_AP_HIDDEN, 4);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  IPAddress apIP(192, 168, 4, 1);
  WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));

  setupWebServer();

  WiFi.setAutoReconnect(true);
  WiFi.begin(sta_ssid, sta_password);

  mqttClient.setServer(mqtt_server, mqtt_port);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setKeepAlive(15);
}

void loop() {
  webServer.handleClient();
  readVibrationSensor();
  checkStarterTimeout();

  // فصل السلف تلقائياً وبأمان بعد 1.8 ثانية
  if (starterState && (millis() - starterStartTime >= STARTER_MAX_DURATION)) {
    digitalWrite(RELAY_STARTER_PIN, RELAY_OFF);
    starterState = false;
    Serial.println("GPIO 22: STARTER OFF (Auto-Release Timeout)");
    publishStatusMQTT();
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      static unsigned long lastMqttAttempt = 0;
      if (millis() - lastMqttAttempt > 3000) {
        lastMqttAttempt = millis();
        reconnectMQTT();
      }
    } else {
      mqttClient.loop();
    }
  }

  delay(2);
}
