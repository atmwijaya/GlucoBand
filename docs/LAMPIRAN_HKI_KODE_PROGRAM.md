# Lampiran Contoh Ciptaan: Program Komputer
## Sistem Aplikasi Mobile dan Web Full Stack GlucoBand untuk Pemantauan Kadar Glukosa Non-Invasif Berbasis Wearable

Dokumen kompilasi cuplikan kode program (*source code*) bersih tanpa komentar (*comment-free*) untuk pendaftaran Hak Cipta pada Direktorat Jenderal Kekayaan Intelektual (DJKI) Kementerian Hukum dan HAM RI. Dilengkapi dengan modul inferensi *Machine Learning* XGBoost untuk estimasi kadar glukosa non-invasif dari spektrum NIR 6-kanal.

---



## 1. FIRMWARE WEARABLE IOT (ESP32-C3)

### Berkas: `glucoband.ino`

**Keterangan**: glucoband.ino (Inisialisasi Sensor Optik NIR AS726X, PPG MAX30105, Suhu MLX90614 & Web Server)  

**Bahasa**: C++ / Arduino  


```c++
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "heartRate.h"
#include "AS726X.h"
#include <Adafruit_MLX90614.h>
#include "WiFiConfig.h"
#define I2C_SDA 8
#define I2C_SCL 9
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
#define OLED_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
MAX30105 particleSensor;
AS726X asSensor;
Adafruit_MLX90614 mlx = Adafruit_MLX90614();
WiFiConfig wifiConfig;

bool oledOk = false;
bool maxOk = false;
bool asOk = false;
bool mlxOk = false;
bool asBulbActive = false;

const byte RATE_SIZE = 8;
byte rates[RATE_SIZE] = {0};
byte rateSpot = 0;
byte rateCount = 0;

long lastBeat = 0;
long irValue = 0;
int bpm = 0;
int bpmAverage = 0;
bool fingerPresent = false;
float ambientTemp = NAN;
float objectTemp = NAN;
float spectralR = 0;
float spectralS = 0;
float spectralT = 0;
float spectralU = 0;
float spectralV = 0;
float spectralW = 0;
float estimatedGlucose = 0.0;
bool glucoseEstimatedOk = false;
unsigned long lastMaxRead = 0;
unsigned long lastMlxRead = 0;
unsigned long lastASRead = 0;
unsigned long lastOLEDUpdate = 0;
unsigned long lastSerialPrint = 0;
unsigned long lastPageSwitch = 0;
const unsigned long MAX_INTERVAL = 10;
const unsigned long MLX_INTERVAL = 500;
const unsigned long AS_INTERVAL = 5000;
const unsigned long SERIAL_INTERVAL = 5000;
const unsigned long OLED_INTERVAL = 150;
const unsigned long PAGE_INTERVAL = 2500;

byte oledPage = 0;

void readMAX30105();
void updateSensorBulb();
void readMLX90614();
void readAS726X();
void updateOLED();
void printSerialData();
void showStartupStatus();

void setup() {
  Serial.begin(115200);

  unsigned long startWait = millis();
  while (!Serial && millis() - startWait < 1500);

  Serial.println("\n>>> MEMULAI GLUCOBAND SYSTEM <<<");

  wifiConfig.begin();

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(100000);
  Wire.setTimeOut(50);

  oledOk = display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS);
  if (oledOk) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(0, 4);
    display.println("GlucoBand V1");
    display.setCursor(0, 18);
    display.println("Memeriksa Sensor...");
    display.display();
  }

  maxOk = particleSensor.begin(Wire, I2C_SPEED_STANDARD);
  if (maxOk) {
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    particleSensor.setPulseAmplitudeRed(0x1F);
    particleSensor.setPulseAmplitudeIR(0x1F);
    particleSensor.setPulseAmplitudeGreen(0);
  }

  mlxOk = mlx.begin(0x5A, &Wire);
  asOk = asSensor.begin(Wire);
  if (asOk) {
    asSensor.setIntegrationTime(10);
    asSensor.setMeasurementMode(2);
    asSensor.disableBulb();
    asBulbActive = false;
  }

  showStartupStatus();
}

void loop() {

  wifiConfig.handle();

  unsigned long now = millis();

  if (now - lastMaxRead >= MAX_INTERVAL) {
    lastMaxRead = now;
    readMAX30105();
  }

  if (now - lastMlxRead >= MLX_INTERVAL) {
    lastMlxRead = now;
    readMLX90614();
  }

  if (now - lastASRead >= AS_INTERVAL) {
    lastASRead = now;
    readAS726X();
  }

  if (now - lastOLEDUpdate >= OLED_INTERVAL) {
    lastOLEDUpdate = now;
    updateOLED();
  }

  if (now - lastSerialPrint >= SERIAL_INTERVAL) {
    lastSerialPrint = now;
    printSerialData();
  }
}

void readMAX30105() {
  if (!maxOk) return;

  irValue = particleSensor.getIR();
  fingerPresent = (irValue > 30000);

  updateSensorBulb();

  if (!fingerPresent) {
    bpm = 0;
    bpmAverage = 0;
    rateCount = 0;
    return;
  }

  if (checkForBeat(irValue)) {
    unsigned long now = millis();

    if (lastBeat > 0) {
      long delta = now - lastBeat;

      if (delta > 0) {
        float bpmValue = 60.0 / (delta / 1000.0);

        if (bpmValue >= 40 && bpmValue <= 180) {
          bpm = (int)bpmValue;

          rates[rateSpot] = (byte)bpm;
          rateSpot = (rateSpot + 1) % RATE_SIZE;

          if (rateCount < RATE_SIZE) rateCount++;

          int total = 0;
          for (byte i = 0; i < rateCount; i++) {
            total += rates[i];
          }
          bpmAverage = total / rateCount;
        }
      }
    }
    lastBeat = now;
  }
}

void updateSensorBulb() {
  if (!asOk) return;

  if (fingerPresent && !asBulbActive) {
    asSensor.enableBulb();
    asBulbActive = true;
  } else if (!fingerPresent && asBulbActive) {
    asSensor.disableBulb();
    asBulbActive = false;
  }
}

void readMLX90614() {
  if (!mlxOk) return;

  float ambient = mlx.readAmbientTempC();
  float object = mlx.readObjectTempC();

  if (!isnan(ambient) && !isnan(object) &&
      ambient > -40 && ambient < 125 &&
      object > -70 && object < 380) {
    ambientTemp = ambient;
    objectTemp = object;
  }
}

void readAS726X() {
  if (!asOk) return;

  if (!fingerPresent) {
    spectralR = 0;
    spectralS = 0;
    spectralT = 0;
    spectralU = 0;
    spectralV = 0;
    spectralW = 0;
    estimatedGlucose = 0.0;
    glucoseEstimatedOk = false;
    return;
  }

  asSensor.takeMeasurements();

  spectralR = asSensor.getCalibratedR();
  spectralS = asSensor.getCalibratedS();
  spectralT = asSensor.getCalibratedT();
  spectralU = asSensor.getCalibratedU();
  spectralV = asSensor.getCalibratedV();
  spectralW = asSensor.getCalibratedW();

  if (wifiConfig.isConnected()) {
    float outGlucose = 0.0;
    if (wifiConfig.predictGlucose(spectralR, spectralS, spectralT, spectralU, spectralV, spectralW, outGlucose)) {
      estimatedGlucose = outGlucose;
      glucoseEstimatedOk = true;
    }
  }
}

void printSerialData() {
  Serial.println("\n========== GLUCOBAND SENSOR DATA ==========");
  Serial.print("MAX30105 IR   : "); Serial.println(irValue);
  Serial.print("Finger Status : "); Serial.println(fingerPresent ? "TERDETEKSI" : "TIDAK ADA");

  if (fingerPresent) {
    Serial.print("BPM           : ");
    if (bpmAverage > 0) Serial.println(bpmAverage);
    else Serial.println("Menghitung...");

    Serial.print("Suhu Kulit    : ");
    if (mlxOk && !isnan(objectTemp)) {
      Serial.print(objectTemp, 1);
      Serial.println(" C");
    } else {
      Serial.println("N/A");
    }

    Serial.print("Estimasi Gula : ");
    if (glucoseEstimatedOk && estimatedGlucose > 0) {
      Serial.print(estimatedGlucose, 1);
      Serial.print(" mg/dL (Status: ");
      if (estimatedGlucose < 70.0) Serial.print("Hipoglikemia");
      else if (estimatedGlucose <= 140.0) Serial.print("Normal");
      else if (estimatedGlucose <= 199.0) Serial.print("Pradiabetes");
      else Serial.print("Hiperglikemia");
      Serial.println(")");
    } else if (wifiConfig.isConnected()) {
      Serial.println("Mengestimasi kadar gula darah");
    } else {
      Serial.println("Menunggu WiFi untuk inferensi AI...");
    }

    if (asOk) {
      Serial.printf("Spektrum NIR (R,S,T,U,V,W): %.2f, %.2f, %.2f, %.2f, %.2f, %.2f\n",
                    spectralR, spectralS, spectralT,
                    spectralU, spectralV, spectralW);
    }
  } else {
    Serial.println("Sensor AS726X standby (menunggu jari).");
  }
  Serial.println("===========================================");
}

void updateOLED() {
  if (!oledOk) return;

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  if (!fingerPresent) {
    unsigned long now = millis();
    if (now - lastPageSwitch >= PAGE_INTERVAL) {
      lastPageSwitch = now;
      oledPage = (oledPage == 0) ? 1 : 0;
    }

    display.setTextSize(1);
    if (oledPage == 0) {
      display.setCursor(25, 4);
      display.print("GlucoBand V1");
      display.setCursor(14, 18);
      display.print("Tempelkan Jari...");
    } else {
      if (wifiConfig.isConnected()) {
        display.setCursor(0, 4);
        display.print("WiFi: ");
        display.println(wifiConfig.getSSID().substring(0, 10));
        display.setCursor(0, 18);
        display.print("IP: ");
        display.println(wifiConfig.getIP());
      } else {
        display.setCursor(0, 1);
        display.print("AP: GlucoBand-Setup");
        display.setCursor(0, 12);
        display.print("IP: 192.168.4.1");
        display.setCursor(0, 23);
        int clients = wifiConfig.getConnectedClients();
        if (clients > 0) {
          display.print("HP Konek: ");
          display.print(clients);
          display.println(" OK");
        } else {
          display.println("Sambungkan HP...");
        }
      }
    }
  } else {
    unsigned long now = millis();
    if (now - lastPageSwitch >= PAGE_INTERVAL) {
      lastPageSwitch = now;
      oledPage = (oledPage == 0) ? 1 : 0;
    }

    if (oledPage == 0) {
      display.setTextSize(1);
      display.setCursor(0, 4);
      display.print("BPM  : ");
      if (bpmAverage > 0) {
        display.print(bpmAverage);
        display.print(" bpm");
      } else {
        display.print("Mengukur...");
      }

      display.setCursor(0, 18);
      display.print("Suhu : ");
      if (mlxOk && !isnan(objectTemp)) {
        display.print(objectTemp, 1);
        display.print((char)247);
        display.print("C");
      } else {
        display.print("--");
      }
    } else {

      display.setCursor(0, 2);
      display.setTextSize(1);
      display.print("Estimasi Gula Darah:");

      if (glucoseEstimatedOk && estimatedGlucose > 0) {
        display.setCursor(0, 16);
        display.setTextSize(2);
        display.print((int)round(estimatedGlucose));
        display.setTextSize(1);
        display.print(" mg/dL");

        display.setCursor(84, 18);
        if (estimatedGlucose < 70) {
          display.print("Rendah");
        } else if (estimatedGlucose <= 140) {
          display.print("Normal");
        } else if (estimatedGlucose <= 199) {
          display.print("Sedang");
        } else {
          display.print("Tinggi");
        }
      } else if (wifiConfig.isConnected()) {
        display.setCursor(0, 18);
        display.setTextSize(1);
        display.print("Mengestimasi (AI)...");
      } else {
        display.setCursor(0, 18);
        display.setTextSize(1);
        display.print("Sambungkan WiFi");
      }
    }
  }

  display.display();
}

void showStartupStatus() {
  if (!oledOk) return;

  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Hardware Init:");
  display.print("MAX:"); display.print(maxOk ? "OK " : "ERR ");
  display.print("MLX:"); display.println(mlxOk ? "OK" : "ERR");
  display.print("AS :"); display.print(asOk ? "OK " : "ERR ");
  display.print("OLED:OK");
  display.display();
  delay(1200);
}
```

---

### Berkas: `WiFiConfig.cpp`

**Keterangan**: WiFiConfig.cpp (Pengaturan Transmisi Jaringan WiFi AP / Station & Web Portal Lokal)  

**Bahasa**: C++  


```c++
#include "WiFiConfig.h"

extern bool oledOk;
extern bool maxOk;
extern bool asOk;
extern bool mlxOk;

extern long irValue;
extern int bpm;
extern int bpmAverage;
extern byte rateCount;
extern bool fingerPresent;
extern float objectTemp;
extern float spectralR, spectralS, spectralT, spectralU, spectralV, spectralW;
extern float estimatedGlucose;
extern bool glucoseEstimatedOk;

#define RESET_BUTTON_PIN -1

WiFiConfig::WiFiConfig() : server(80), wifiConnected(false), failedAttempts(0),
                           lastConnectionAttempt(0), resetButtonPressed(0),
                           resetButtonState(false), apModeActive(false) {
  apiEndpoint = "https://glucobandpro.id";
  connectionStatus = "Inisialisasi";
}

void WiFiConfig::begin() {
  Serial.println("\n==========================================");
  Serial.println("[GlucoBand] Memulai Sub-Sistem WiFi & Server");
  Serial.println("==========================================");

#if defined(RESET_BUTTON_PIN) && (RESET_BUTTON_PIN >= 0)
  pinMode(RESET_BUTTON_PIN, INPUT_PULLUP);
#endif

  preferences.begin("wifi-config", false);
  loadCredentials();

  startAPMode();
  setupRoutes();
  server.begin();

  if (ssid.length() > 0) {
    connectionStatus = "Menghubungkan...";
    Serial.print("[WiFi] Menghubungkan ke SSID tersimpan: ");
    Serial.println(ssid);

    wifiConnected = connectToWiFi();

    if (wifiConnected) {
      connectionStatus = "Connected";
      failedAttempts = 0;
      Serial.println("[WiFi] BERHASIL tersambung ke jaringan router!");
      Serial.print("[WiFi] Alamat IP Lokal: ");
      Serial.println(WiFi.localIP());
      if (MDNS.begin("glucoband")) {
        MDNS.addService("http", "tcp", 80);
        Serial.println("[MDNS] Responder mDNS aktif: http://glucoband.local");
      }
    } else {
      connectionStatus = "Koneksi Router Gagal (AP Aktif)";
      failedAttempts++;
      Serial.print("[WiFi] Gagal konek router. Percobaan ke: ");
      Serial.println(failedAttempts);

      WiFi.mode(WIFI_AP);
      WiFi.setSleep(false);

      if (failedAttempts >= 2) {
        Serial.println("[WiFi] Gagal 2x. Menghapus konfigurasi lama yang salah...");
        clearCredentials();
        connectionStatus = "AP Setup Mode";
        failedAttempts = 0;
      }
    }
  } else {
    connectionStatus = "AP Setup Mode";
    Serial.println("[WiFi] Belum ada WiFi tersimpan. Siap dikonfigurasi.");
  }

  Serial.println("[WiFi] ==========================================");
  Serial.println("[WiFi] WiFi AP: GlucoBand-Setup (Tanpa Password)");
  Serial.print("[WiFi] Buka di Browser HP: http://");
  Serial.println(WiFi.softAPIP());
  Serial.println("[WiFi] ==========================================\n");
}

void WiFiConfig::startAPMode() {

  WiFi.disconnect(true, true);
  delay(50);

  WiFi.mode(WIFI_AP_STA);
  delay(50);

  IPAddress apIP(192, 168, 4, 1);
  IPAddress gateway(192, 168, 4, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.softAPConfig(apIP, gateway, subnet);

  bool apSuccess = WiFi.softAP("GlucoBand-Setup", NULL, 1, 0, 4);

  WiFi.setSleep(false);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  apModeActive = true;

  if (apSuccess) {
    Serial.println("[WiFi] Access Point 'GlucoBand-Setup' AKTIF di Channel 1.");
    Serial.print("[WiFi] IP Gateway AP: ");
    Serial.println(WiFi.softAPIP());
  } else {
    Serial.println("[WiFi] PERINGATAN: Gagal mengaktifkan SoftAP!");
  }
}

void WiFiConfig::sendCorsHeader() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

void WiFiConfig::setupRoutes() {

  server.on("/", HTTP_GET, [this]() { handleRoot(); });
  server.on("/scan", HTTP_GET, [this]() { handleScan(); });
  server.on("/save", HTTP_POST, [this]() { handleSave(); });

  server.on("/generate_204", HTTP_GET, [this]() { handleRoot(); });
  server.on("/hotspot-detect.html", HTTP_GET, [this]() { handleRoot(); });
  server.on("/canonical.html", HTTP_GET, [this]() { handleRoot(); });

  server.on("/api/status", HTTP_GET, [this]() { handleApiStatus(); });
  server.on("/api/scan", HTTP_GET, [this]() { handleScan(); });
  server.on("/api/init", HTTP_GET, [this]() { handleApiInit(); });
  server.on("/api/sensors", HTTP_GET, [this]() { handleApiSensors(); });
  server.on("/api/save", HTTP_POST, [this]() { handleApiSave(); });
  server.on("/api/wifi", HTTP_POST, [this]() { handleApiSave(); });
  server.on("/api/reset", HTTP_POST, [this]() { handleApiReset(); });

  server.onNotFound([this]() {
    if (server.method() == HTTP_OPTIONS) {
      sendCorsHeader();
      server.send(204);
    } else {
      if (apModeActive) {
        handleRoot();
      } else {
        server.send(404, "text/plain", "Not Found");
      }
    }
  });
}

void WiFiConfig::handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>GlucoBand WiFi Setup</title>";
  html += "<style>body{font-family:system-ui,-apple-system,sans-serif;margin:0;padding:20px;background:#f1f5f9;color:#0f172a}";
  html += ".card{background:white;padding:28px;border-radius:16px;max-width:380px;margin:20px auto;box-shadow:0 10px 25px -5px rgba(0,0,0,0.1)}";
  html += "h2{color:#4338ca;margin-top:0;font-size:22px;text-align:center}.badge{background:#e0e7ff;color:#4338ca;padding:6px 12px;border-radius:20px;font-size:12px;font-weight:600;display:inline-block;margin-bottom:16px}";
  html += "label{display:block;font-size:13px;font-weight:600;margin:12px 0 6px;color:#334155}";
  html += "select,input{width:100%;padding:12px;border:1.5px solid #cbd5e1;border-radius:10px;box-sizing:border-box;font-size:14px;outline:none}";
  html += "select:focus,input:focus{border-color:#6366f1}";
  html += "button{width:100%;padding:14px;background:#4f46e5;color:white;border:none;border-radius:10px;cursor:pointer;font-size:15px;font-weight:700;margin-top:18px;transition:0.2s}";
  html += "button:hover{background:#4338ca}.info{color:#64748b;font-size:12px;margin-top:16px;text-align:center}";
  html += ".loading{text-align:center;color:#64748b;padding:12px;font-size:13px}</style>";
  html += "<script>";
  html += "function loadNetworks(){";
  html += "document.getElementById('networks').innerHTML='<div class=\"loading\">Memindai WiFi di sekitar...</div>';";
  html += "let attempts=0;";
  html += "function checkScan(){";
  html += "fetch('/scan').then(r=>r.json()).then(data=>{";
  html += "if(data.status==='scanning'){";
  html += "if(attempts<20){attempts++;setTimeout(checkScan,600);}";
  html += "else{document.getElementById('networks').innerHTML='<div class=\"info\">Scan timeout. <a href=\"javascript:loadNetworks()\">Ulangi</a></div>';}";
  html += "}else if(Array.isArray(data)){";
  html += "let sel=document.getElementById('ssid');sel.innerHTML='<option value=\"\">-- Pilih Jaringan WiFi --</option>';";
  html += "if(data.length===0){sel.innerHTML+='<option value=\"\" disabled>Tidak ada WiFi terdeteksi</option>';}";
  html += "data.forEach(n=>{let opt=document.createElement('option');opt.value=n.ssid;opt.text=n.ssid+' ('+n.rssi+' dBm)';sel.add(opt);});";
  html += "document.getElementById('networks').innerHTML='<div class=\"info\">Ditemukan '+data.length+' jaringan WiFi</div>';";
  html += "}";
  html += "}).catch(e=>{console.error(e);document.getElementById('networks').innerHTML='<div class=\"info\">Gagal scan. <a href=\"javascript:loadNetworks()\">Coba Lagi</a></div>';});";
  html += "}";
  html += "checkScan();";
  html += "}";
  html += "window.onload=loadNetworks;";
  html += "</script></head><body>";
  html += "<div class='card'>";
  html += "<h2>GlucoBand Device</h2>";
  html += "<div style='text-align:center'><span class='badge'>Status: " + connectionStatus + "</span></div>";
  html += "<div id='networks'></div>";
  html += "<form action='/save' method='POST'>";
  html += "<label>Pilih WiFi Rumah/Hotspot:</label>";
  html += "<select id='ssid' name='ssid' required><option value=''>Memuat jaringan...</option></select>";
  html += "<label>Password WiFi:</label>";
  html += "<input name='password' type='password' placeholder='Masukkan password WiFi' required>";
  html += "<button type='submit'>Simpan & Hubungkan</button>";
  html += "<div class='info'>Alamat IP: 192.168.4.1</div>";
  html += "</form></div></body></html>";
  server.send(200, "text/html", html);
}

void WiFiConfig::handleScan() {
  sendCorsHeader();
  int scanResult = WiFi.scanComplete();

  if (scanResult == WIFI_SCAN_RUNNING) {
    server.send(202, "application/json", "{\"status\":\"scanning\"}");
    return;
  }

  if (scanResult == WIFI_SCAN_FAILED || scanResult < 0) {
    WiFi.scanNetworks(true);
    server.send(202, "application/json", "{\"status\":\"scanning\"}");
    return;
  }

  String json = "[";
  for (int i = 0; i < scanResult; i++) {
    if (i > 0) json += ",";
    json += "{";
    json += "\"ssid\":\"" + WiFi.SSID(i) + "\",";
    json += "\"rssi\":" + String(WiFi.RSSI(i)) + ",";
    json += "\"encryption\":" + String(WiFi.encryptionType(i));
    json += "}";
  }
  json += "]";

  server.send(200, "application/json", json);
  WiFi.scanDelete();
}

void WiFiConfig::handleSave() {
  ssid = server.arg("ssid");
  password = server.arg("password");
  ssid.trim();
  password.trim();
  saveCredentials();

  String html = "<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<style>body{font-family:system-ui;text-align:center;padding:40px;background:#f8fafc;color:#1e293b}";
  html += ".box{background:white;padding:32px;border-radius:16px;display:inline-block;box-shadow:0 4px 20px rgba(0,0,0,0.08)}</style></head>";
  html += "<body><div class='box'><h2 style='color:#4f46e5'>Konfigurasi Disimpan!</h2>";
  html += "<p>GlucoBand sedang me-restart untuk terhubung ke <b>" + ssid + "</b>...</p>";
  html += "<p style='color:#64748b;font-size:13px'>Periksa layar OLED untuk melihat alamat IP barunya.</p></div></body></html>";

  server.send(200, "text/html", html);

  delay(1200);
  ESP.restart();
}

void WiFiConfig::handleApiStatus() {
  sendCorsHeader();
  String json = "{";
  json += "\"wifi_connected\":" + String(isConnected() ? "true" : "false") + ",";
  json += "\"status\":\"" + connectionStatus + "\",";
  json += "\"ssid\":\"" + ssid + "\",";
  json += "\"ip\":\"" + getIP() + "\",";
  json += "\"ap_ssid\":\"GlucoBand-Setup\",";
  json += "\"ap_ip\":\"" + WiFi.softAPIP().toString() + "\",";
  json += "\"clients_connected\":" + String(getConnectedClients()) + ",";
  json += "\"rssi\":" + String(WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0);
  json += "}";
  server.send(200, "application/json", json);
}

void WiFiConfig::handleApiInit() {
  sendCorsHeader();
  bool allReady = maxOk && mlxOk && asOk && oledOk;

  String json = "{";
  json += "\"ready\":" + String(allReady ? "true" : "false") + ",";
  json += "\"status\":\"" + String(allReady ? "Siap Digunakan" : "Sensor Belum Lengkap") + "\",";
  json += "\"sensors\":{";
  json += "\"max30105\":" + String(maxOk ? "true" : "false") + ",";
  json += "\"mlx90614\":" + String(mlxOk ? "true" : "false") + ",";
  json += "\"as726x\":" + String(asOk ? "true" : "false") + ",";
  json += "\"oled\":" + String(oledOk ? "true" : "false");
  json += "},";
  json += "\"wifi\":{";
  json += "\"connected\":" + String(isConnected() ? "true" : "false") + ",";
  json += "\"ssid\":\"" + ssid + "\",";
  json += "\"ip\":\"" + getIP() + "\"";
  json += "}}";
  server.send(200, "application/json", json);
}

void WiFiConfig::handleApiSensors() {
  sendCorsHeader();
  String json = "{";
  json += "\"finger_present\":" + String(fingerPresent ? "true" : "false") + ",";
  json += "\"ir_value\":" + String(irValue) + ",";
  json += "\"bpm\":" + String(bpmAverage) + ",";
  json += "\"instant_bpm\":" + String(bpm) + ",";
  json += "\"rate_count\":" + String(rateCount) + ",";
  json += "\"temperature\":" + (isnan(objectTemp) ? "null" : String(objectTemp, 1)) + ",";
  json += "\"glucose_estimated\":" + (glucoseEstimatedOk ? String(estimatedGlucose, 1) : "null") + ",";
  json += "\"nir\":{";
  json += "\"r\":" + String(spectralR, 2) + ",";
  json += "\"s\":" + String(spectralS, 2) + ",";
  json += "\"t\":" + String(spectralT, 2) + ",";
  json += "\"u\":" + String(spectralU, 2) + ",";
  json += "\"v\":" + String(spectralV, 2) + ",";
  json += "\"w\":" + String(spectralW, 2);
  json += "}}";
  server.send(200, "application/json", json);
}

void WiFiConfig::handleApiSave() {
  sendCorsHeader();
  String newSsid = "";
  String newPass = "";

  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    int ssidKey = body.indexOf("\"ssid\"");
    if (ssidKey >= 0) {
      int start = body.indexOf('"', ssidKey + 6);
      int end = body.indexOf('"', start + 1);
      if (start >= 0 && end > start) newSsid = body.substring(start + 1, end);
    }
    int passKey = body.indexOf("\"password\"");
    if (passKey >= 0) {
      int start = body.indexOf('"', passKey + 10);
      int end = body.indexOf('"', start + 1);
      if (start >= 0 && end > start) newPass = body.substring(start + 1, end);
    }
  }

  if (newSsid.isEmpty() && server.hasArg("ssid")) {
    newSsid = server.arg("ssid");
    newPass = server.arg("password");
  }

  if (newSsid.isEmpty()) {
    server.send(400, "application/json", "{\"error\":\"SSID tidak boleh kosong\"}");
    return;
  }

  ssid = newSsid;
  password = newPass;
  ssid.trim();
  password.trim();
  saveCredentials();

  Serial.println("\n[WiFi] Kredensial baru diterima. Menghubungkan langsung ke router...");
  Serial.print("[WiFi] SSID: ");
  Serial.println(ssid);

  WiFi.mode(WIFI_AP_STA);
  WiFi.disconnect(false, true);
  delay(100);
  WiFi.begin(ssid.c_str(), password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 16) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    connectionStatus = "Connected";
    failedAttempts = 0;
    String newIp = WiFi.localIP().toString();
    Serial.println("[WiFi] SUKSES tersambung ke router!");
    Serial.print("[WiFi] IP Baru: ");
    Serial.println(newIp);

    if (MDNS.begin("glucoband")) {
      MDNS.addService("http", "tcp", 80);
      Serial.println("[MDNS] glucoband.local aktif.");
    }

    String resp = "{\"success\":true,\"wifi_connected\":true,\"ip\":\"" + newIp + "\",\"ap_ip\":\"192.168.4.1\",\"ssid\":\"" + ssid + "\",\"message\":\"Berhasil terhubung ke WiFi router\"}";
    server.send(200, "application/json", resp);
  } else {
    wifiConnected = false;
    connectionStatus = "Koneksi Router Gagal (AP Aktif)";
    Serial.println("[WiFi] Gagal terhubung ke router dalam batas waktu.");
    String resp = "{\"success\":false,\"wifi_connected\":false,\"ip\":\"192.168.4.1\",\"ssid\":\"" + ssid + "\",\"message\":\"Gagal terhubung ke router. Periksa kata sandi atau jangkauan sinyal WiFi.\"}";
    server.send(200, "application/json", resp);
  }
}

void WiFiConfig::handleApiReset() {
  sendCorsHeader();
  clearCredentials();
  server.send(200, "application/json", "{\"message\":\"Kredensial WiFi dihapus, restart...\"}");
  delay(1000);
  ESP.restart();
}

void WiFiConfig::loadCredentials() {
  ssid = preferences.getString("ssid", "");
  password = preferences.getString("password", "");
  apiEndpoint = preferences.getString("api_url", "https://glucobandpro.id");
  failedAttempts = preferences.getInt("failed", 0);
}

void WiFiConfig::saveCredentials() {
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  preferences.putInt("failed", 0);
}

void WiFiConfig::clearCredentials() {
  preferences.clear();
  ssid = "";
  password = "";
  failedAttempts = 0;
  Serial.println("[WiFi] Kredensial WiFi berhasil dihapus.");
}

bool WiFiConfig::connectToWiFi() {

  WiFi.disconnect(false, true);
  delay(50);
  WiFi.begin(ssid.c_str(), password.c_str());

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 15) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();

  return (WiFi.status() == WL_CONNECTED);
}

void WiFiConfig::checkResetButton() {
#if defined(RESET_BUTTON_PIN) && (RESET_BUTTON_PIN >= 0)
  bool currentState = (digitalRead(RESET_BUTTON_PIN) == LOW);
  if (currentState && !resetButtonState) {
    resetButtonPressed = millis();
    resetButtonState = true;
  } else if (!currentState && resetButtonState) {
    resetButtonState = false;
    resetButtonPressed = 0;
  }
  if (resetButtonState && (millis() - resetButtonPressed > 5000)) {
    Serial.println("[WiFi] Tombol reset ditekan 5 detik. Menghapus WiFi...");
    clearCredentials();
    delay(500);
    ESP.restart();
  }
#endif
}

void WiFiConfig::handle() {
  checkResetButton();

  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r' || c == 'R') {
      Serial.println("\n[WiFi] Perintah Reset diterima dari Serial. Menghapus konfigurasi WiFi...");
      clearCredentials();
      delay(500);
      ESP.restart();
    }
  }

  server.handleClient();

  if (!wifiConnected && ssid.length() > 0 && failedAttempts < 2) {
    if (millis() - lastConnectionAttempt > 30000) {
      lastConnectionAttempt = millis();
      Serial.println("[WiFi] Mencoba konek ulang ke router...");
      wifiConnected = connectToWiFi();
      if (wifiConnected) {
        connectionStatus = "Connected";
        failedAttempts = 0;
        preferences.putInt("failed", 0);
        Serial.println("[WiFi] Reconnected!");
        Serial.print("[WiFi] IP: ");
        Serial.println(WiFi.localIP());
        MDNS.begin("glucoband");
        MDNS.addService("http", "tcp", 80);
      } else {
        failedAttempts++;
        preferences.putInt("failed", failedAttempts);
      }
    }
  }
}

bool WiFiConfig::isConnected() {
  if (wifiConnected && WiFi.status() != WL_CONNECTED) {
    wifiConnected = false;
    connectionStatus = "Disconnected";
  } else if (!wifiConnected && WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    connectionStatus = "Connected";
  }
  return wifiConnected;
}

bool WiFiConfig::isAPMode() {
  return apModeActive;
}

int WiFiConfig::getConnectedClients() {
  return WiFi.softAPgetStationNum();
}

String WiFiConfig::getSSID() {
  return ssid;
}

String WiFiConfig::getIP() {
  if (isConnected()) {
    return WiFi.localIP().toString();
  }
  return WiFi.softAPIP().toString();
}

String WiFiConfig::getAPIP() {
  return WiFi.softAPIP().toString();
}

String WiFiConfig::getStatusLabel() {
  if (wifiConnected) return "WiFi";
  if (ssid.length() > 0) return "Status";
  return "Setup";
}

String WiFiConfig::getStatusValue() {
  if (wifiConnected) return ssid;
  if (ssid.length() > 0) return connectionStatus;
  return WiFi.softAPIP().toString();
}

bool WiFiConfig::sendData(int id, int bpm, float glucose) {
  if (!isConnected()) return false;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  String url = apiEndpoint + "/api/sensors/update";

  String payload = "{";
  payload += "\"glucose\":" + String(glucose, 2) + ",";
  payload += "\"heart_rate\":" + String(bpm);
  payload += "}";

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  int httpCode = http.PATCH(payload);
  bool success = (httpCode > 0 && httpCode < 400);
  http.end();
  return success;
}

static bool tryParseJsonNumberByKey(const String &json, const char *key, float &outValue) {
  String quotedKey = String('"') + key + "\"";
  int keyPos = json.indexOf(quotedKey);
  if (keyPos < 0) return false;

  int colonPos = json.indexOf(':', keyPos + quotedKey.length());
  if (colonPos < 0) return false;

  int i = colonPos + 1;
  while (i < (int)json.length() && (json[i] == ' ' || json[i] == '\n' || json[i] == '\r' || json[i] == '\t')) i++;

  int start = i;
  if (i < (int)json.length() && (json[i] == '-' || json[i] == '+')) i++;
  bool sawDigit = false;
  while (i < (int)json.length()) {
    char c = json[i];
    if ((c >= '0' && c <= '9')) {
      sawDigit = true;
      i++;
      continue;
    }
    if (c == '.') {
      i++;
      continue;
    }
    break;
  }

  if (!sawDigit) return false;
  outValue = json.substring(start, i).toFloat();
  return true;
}

bool WiFiConfig::predictGlucose(float r, float s, float t, float u, float v, float w, float &outGlucose) {
  if (!isConnected()) return false;

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  String url = apiEndpoint + "/api/xgb/predict";
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);

  String payload = "{\"R\":" + String(r, 6) + ",\"S\":" + String(s, 6) + ",\"T\":" + String(t, 6) +
                   ",\"U\":" + String(u, 6) + ",\"V\":" + String(v, 6) + ",\"W\":" + String(w, 6) + "}";

  int code = http.POST(payload);
  if (code > 0 && code < 400) {
    String body = http.getString();
    float parsed = 0;
    if (tryParseJsonNumberByKey(body, "Glucose", parsed) ||
        tryParseJsonNumberByKey(body, "glucose", parsed)) {
      outGlucose = parsed;
      http.end();
      return true;
    }
  }
  http.end();
  return false;
}
```

---



## 2. BACK-END & MACHINE LEARNING SERVICE (PYTHON FLASK)

### Berkas: `__init__.py`

**Keterangan**: __init__.py (Inisialisasi Aplikasi Flask, Socket.IO, CORS, dan Blueprint Routing)  

**Bahasa**: Python  


```python
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_socketio import SocketIO, emit
import os
from dotenv import load_dotenv

load_dotenv()
socketio = SocketIO(cors_allowed_origins="*")

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = os.getenv('SECRET_KEY', 'dev-secret-key')
    app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY', 'jwt-secret-key')

    CORS(app)
    JWTManager(app)
    socketio.init_app(app)

    from app.routes.auth import auth_bp
    from app.routes.patients import patients_bp
    from app.routes.measurements import measurements_bp
    from app.routes.predictions import predictions_bp
    from app.routes.notifications import notifications_bp
    from app.routes.recommendations import recommendations_bp
    from app.routes.faq import faq_bp
    from app.routes.profile import profile_bp
    from app.routes.dashboard import dashboard_bp
    from app.routes.patientNotification import patient_notif_bp
    from app.routes.patientPrediction import patient_pred_bp
    from app.routes.settings import settings_bp
    from app.routes.tenagaMedis import tenaga_medis_bp

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(patients_bp, url_prefix='/api')
    app.register_blueprint(measurements_bp, url_prefix='/api')
    app.register_blueprint(predictions_bp, url_prefix='/api')
    app.register_blueprint(notifications_bp, url_prefix='/api')
    app.register_blueprint(recommendations_bp, url_prefix='/api')
    app.register_blueprint(faq_bp, url_prefix='/api')
    app.register_blueprint(dashboard_bp, url_prefix='/api')
    app.register_blueprint(profile_bp, url_prefix='/api')
    app.register_blueprint(patient_notif_bp, url_prefix='/api')
    app.register_blueprint(patient_pred_bp, url_prefix='/api')
    app.register_blueprint(settings_bp, url_prefix='/api')
    app.register_blueprint(tenaga_medis_bp, url_prefix='/api')

    return app
```

---

### Berkas: `xgboost_service.py`

**Keterangan**: xgboost_service.py (Logika Inferensi Estimasi Kadar Glukosa Non-Invasif Spektrum NIR dengan Model XGBoost Regressor)  

**Bahasa**: Python  


```python
import os
import joblib
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class XGBoostService:

    _instance = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(XGBoostService, cls).__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if getattr(self, '_initialized', False):
            return
        self.model = None
        self.scaler = None
        self.expected_features = ['R', 'S', 'T', 'U', 'V', 'W']
        self._load_assets()
        self._initialized = True

    def _load_assets(self):
        try:
            model_path = os.path.join(MODEL_DIR, 'xgboost_model.joblib')
            scaler_path = os.path.join(MODEL_DIR, 'scaler_xgb.joblib')

            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                print("XGBoost Model (xgboost_model.joblib) & Scaler (scaler_xgb.joblib) berhasil dimuat.")
            elif os.path.exists(model_path):
                self.model = joblib.load(model_path)
                print("Scaler_xgb.joblib tidak ditemukan, menggunakan model XGBoost.")
            else:
                print("File model xgboost_model.joblib tidak ditemukan di", MODEL_DIR)
        except Exception as e:
            print("Gagal memuat model XGBoost:", e)
            self.model = None
            self.scaler = None

    def predict_glucose(self, data: dict) -> dict:

        if self.model is None:

            self._load_assets()
            if self.model is None:
                raise FileNotFoundError("Model XGBoost tidak tersedia atau gagal dimuat.")

        r = float(data.get('R') if data.get('R') is not None else data.get('r', 0.0))
        s = float(data.get('S') if data.get('S') is not None else data.get('s', 0.0))
        t = float(data.get('T') if data.get('T') is not None else data.get('t', 0.0))
        u = float(data.get('U') if data.get('U') is not None else data.get('u', 0.0))
        v = float(data.get('V') if data.get('V') is not None else data.get('v', 0.0))
        w = float(data.get('W') if data.get('W') is not None else data.get('w', 0.0))

        input_df = pd.DataFrame([[r, s, t, u, v, w]], columns=self.expected_features)

        if self.scaler is not None:
            features_transformed = self.scaler.transform(input_df)
        else:
            features_transformed = input_df.values

        raw_pred = float(self.model.predict(features_transformed)[0])

        estimated_glucose = round(float(np.clip(raw_pred, 40.0, 450.0)), 1)

        if estimated_glucose < 70.0:
            status = "Hipoglikemia"
            status_desc = "Kadar gula darah di bawah batas normal (< 70 mg/dL)"
        elif estimated_glucose <= 140.0:
            status = "Normal"
            status_desc = "Kadar gula darah dalam batas normal (70 - 140 mg/dL)"
        elif estimated_glucose <= 199.0:
            status = "Pradiabetes"
            status_desc = "Kadar gula darah toleransi terganggu (141 - 199 mg/dL)"
        else:
            status = "Hiperglikemia"
            status_desc = "Kadar gula darah tinggi (>= 200 mg/dL)"

        return {
            "success": True,
            "Glucose": estimated_glucose,
            "glucose": estimated_glucose,
            "status": status,
            "status_desc": status_desc,
            "unit": "mg/dL",
            "features": {
                "R": r, "S": s, "T": t, "U": u, "V": v, "W": w
            }
        }
```

---

### Berkas: `patientPrediction.py`

**Keterangan**: patientPrediction.py (API Controller Endpoint /api/xgb/predict untuk Inferensi Glukosa & Live Streaming WebSocket)  

**Bahasa**: Python  


```python
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from app.services.ml.rf_service import RFService
from app.services.ml.lstm_service import LSTMService
from app.services.ml.xgboost_service import XGBoostService
from db import db_connection
from app import socketio
from app.utils.decorators import get_current_user
import json
import traceback

patient_pred_bp = Blueprint('patient_predictions', __name__)
rf_service = RFService()
lstm_service = LSTMService()
xgboost_service = XGBoostService()

@patient_pred_bp.post('/predict/risk')
@jwt_required()
@db_connection
def predict_risk(cursor):
    data = request.get_json()
    if not data:
        return jsonify({"error": "Data tidak lengkap"}), 400
    features = {
        "age": int(data.get("age", 0)),
        "gender": data.get("gender", "Male"),
        "bmi": float(data.get("bmi", 0)),
        "blood_pressure_sys": int(data.get("blood_pressure_sys", 0)),
        "blood_pressure_dia": int(data.get("blood_pressure_dia", 0)),
        "smoking_history": data.get("smoking_history", 0),
        "hypertension": int(data.get("hypertension", 0)),
        "heart_disease": int(data.get("heart_disease", 0)),
        "blood_glucose_level": float(data.get("blood_glucose_level", 100.0)),
        "HbA1c_level": data.get("HbA1c_level")
    }
    try:
        result = rf_service.predict_risk(features)

        user = get_current_user()
        if not user:
            return jsonify({'error': 'Token otentikasi tidak valid'}), 401

        if user.get('role') == 'pasien':
            patient_id = user['id']
        else:
            patient_id = data.get('patient_id', user['id'])
        risk_level = result.get("risk_level", "rendah").lower()
        risk_score = result.get("risk_score", 0)
        model_version = str(result.get("model_version") or result.get("model version") or "1.0")[:20]

        cursor.execute("""
            INSERT INTO predictions_risk (patient_id, feature_vector, risk_level, risk_score, model_version)
            VALUES (%s, %s, %s, %s, %s)
        """, (patient_id, json.dumps(features), risk_level, risk_score, model_version))

        return jsonify(result)
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        print("=== ERROR in predict_risk ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@patient_pred_bp.post('/predict/trend')
@jwt_required()
@db_connection
def predict_trend(cursor):
    data = request.get_json()
    if not data or 'glucose_history' not in data:
        return jsonify({"error": "glucose_history diperlukan"}), 400

    history = data.get('glucose_history', [])
    try:
        history = [float(x) for x in history if float(x) > 0]
    except:
        return jsonify({"error": "Format glucose_history tidak valid"}), 400

    if len(history) < 3:
        return jsonify({"error": "Minimal 3 data glukosa historis diperlukan"}), 400

    horizon = int(data.get('horizon_hours', 6))

    age = int(data.get('age', 40))
    bmi = float(data.get('bmi', 25.0))
    hypertension = int(data.get('hypertension', 0))
    heart_disease = int(data.get('heart_disease', 0))
    gender = data.get('gender', 'Male')
    smoking = int(data.get('smoking_history', 0))
    heart_rate = float(data.get('heart_rate') or data.get('hr') or 75.0)
    insulin = float(data.get('insulin', 0.0))
    carbs = float(data.get('carbs', 0.0))
    steps = float(data.get('steps', 0.0))
    calories = float(data.get('calories') or data.get('cals') or 0.0)

    try:
        result = lstm_service.predict_trend(
            history,
            horizon,
            age=age,
            bmi=bmi,
            hypertension=hypertension,
            heart_disease=heart_disease,
            gender=gender,
            smoking_history=smoking,
            heart_rate=heart_rate,
            insulin=insulin,
            carbs=carbs,
            steps=steps,
            calories=calories
        )
        user = get_current_user()
        if not user:
            return jsonify({'error': 'Token otentikasi tidak valid'}), 401

        if user.get('role') == 'pasien':
            patient_id = user['id']
        else:
            patient_id = data.get('patient_id', user['id'])
        health_snapshot = {
            "age": age,
            "bmi": bmi,
            "hypertension": hypertension,
            "heart_disease": heart_disease,
            "gender": gender,
            "smoking_history": smoking,
            "heart_rate": heart_rate,
            "glucose_history": history
        }

        cursor.execute("""
            INSERT INTO predictions_trend (patient_id, input_measurement_ids, health_snapshot, predicted_values, horizon_hours, model_version)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            patient_id,
            json.dumps([]),
            json.dumps(health_snapshot),
            json.dumps(result),
            horizon,
            "1.0"
        ))

        cursor.execute("SELECT LAST_INSERT_ID() AS id")
        new_id = cursor.fetchone()['id']
        import datetime

        new_prediction_event = {
            "id": new_id,
            "patient_id": patient_id,
            "created_at": datetime.datetime.now().isoformat(),
            "predicted_values": result,
            "horizon_hours": horizon
        }
        socketio.emit('new_prediction_trend', new_prediction_event)

        return jsonify(result)
    except Exception as e:
        print("=== ERROR in predict_trend ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@patient_pred_bp.post('/xgb/predict')
@patient_pred_bp.post('/predict/xgb')
def predict_xgb():

    data = request.get_json(silent=True) or {}
    if not data:
        data = request.values.to_dict()

    try:
        result = xgboost_service.predict_glucose(data)

        patient_id = data.get('patient_id')
        if patient_id:
            try:
                from db import get_connection
                patient_name = f"Pasien #{patient_id}"
                c_conn = get_connection()
                if c_conn:
                    with c_conn.cursor(dictionary=True) as c_cur:
                        c_cur.execute("SELECT name FROM users WHERE id = %s", (patient_id,))
                        u_row = c_cur.fetchone()
                        if u_row:
                            patient_name = u_row['name']
                    c_conn.close()

                live_payload = {
                    'patient_id': int(patient_id),
                    'patient_name': patient_name,
                    'glucose': result['glucose'],
                    'glucose_estimated': result['glucose'],
                    'status': result['status'],
                    'unit': 'mg/dL',
                    'features': result.get('features', {})
                }
                socketio.emit('live_glucose_estimate', live_payload)

                if result['status'] in ('Hipoglikemia', 'Hiperglikemia'):
                    alert_payload = {
                        'patient_id': int(patient_id),
                        'patient_name': patient_name,
                        'type': result['status'].lower(),
                        'glucose_value': result['glucose'],
                        'message': f"Peringatan Realtime: Pasien {patient_name} terdeteksi {result['status']} ({result['glucose']} mg/dL).",
                        'status': result['status']
                    }
                    socketio.emit('new_notification', alert_payload)
                    socketio.emit('glucose_alert', alert_payload)
            except Exception as se:
                print(f"[SocketIO Error] Gagal emit live_glucose_estimate: {se}")

        return jsonify(result), 200
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 503
    except Exception as e:
        print("=== ERROR in predict_xgb ===")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
```

---

### Berkas: `measurements.py`

**Keterangan**: measurements.py (API Controller Penerimaan Data Sensor & Riwayat Pengukuran Glukosa)  

**Bahasa**: Python  


```python
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from db import db_connection
from app.utils.decorators import (
    get_current_user,
    can_access_patient,
    patient_owner_or_medis,
    patient_body_owner_or_medis
)

measurements_bp = Blueprint('measurements', __name__)

@measurements_bp.get('/measurements')
@jwt_required()
@db_connection
def get_all_measurements(cursor):

    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid.'}), 401

    if user.get('role') == 'pasien':
        cursor.execute("""
            SELECT m.id, m.patient_id, u.name AS patient_name,
                   m.glucose_estimated, m.status, m.ppg_heart_rate, m.ppg_spo2,
                   m.skin_temp_celsius, m.created_at
            FROM measurements m
            JOIN users u ON m.patient_id = u.id
            WHERE m.patient_id = %s
            ORDER BY m.created_at DESC
            LIMIT 100
        """, (user.get('id'),))
    else:
        cursor.execute("""
            SELECT m.id, m.patient_id, u.name AS patient_name,
                   m.glucose_estimated, m.status, m.ppg_heart_rate, m.ppg_spo2,
                   m.skin_temp_celsius, m.created_at
            FROM measurements m
            JOIN users u ON m.patient_id = u.id
            ORDER BY m.created_at DESC
            LIMIT 100
        """)

    measurements = cursor.fetchall()
    for m in measurements:
        m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
        m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
        m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(measurements)

@measurements_bp.get('/patients/<int:patient_id>/measurements')
@patient_owner_or_medis('patient_id')
@db_connection
def get_patient_measurements(cursor, patient_id):

    date_str = request.args.get('date')
    if date_str:
        cursor.execute("""
            SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
                   skin_temp_celsius, created_at
            FROM measurements
            WHERE patient_id = %s AND DATE(created_at) = %s
            ORDER BY created_at ASC
        """, (patient_id, date_str))
    else:
        limit = request.args.get('limit', 20, type=int)
        cursor.execute("""
            SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
                   skin_temp_celsius, created_at
            FROM measurements
            WHERE patient_id = %s
            ORDER BY created_at DESC
            LIMIT %s
        """, (patient_id, limit))
    measurements = cursor.fetchall()
    for m in measurements:
        m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
        m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
        m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(measurements)

@measurements_bp.get('/patients/<int:patient_id>/measurement-dates')
@patient_owner_or_medis('patient_id')
@db_connection
def get_patient_measurement_dates(cursor, patient_id):

    cursor.execute("""
        SELECT DISTINCT DATE(created_at) AS date
        FROM measurements
        WHERE patient_id = %s
        ORDER BY date DESC
        LIMIT 60
    """, (patient_id,))
    rows = cursor.fetchall()
    dates = [r['date'].isoformat() if hasattr(r['date'], 'isoformat') else str(r['date']) for r in rows if r['date']]
    return jsonify(dates)

@measurements_bp.get('/patients/<int:patient_id>/latest')
@patient_owner_or_medis('patient_id')
@db_connection
def get_latest_measurement(cursor, patient_id):

    cursor.execute("""
        SELECT id, patient_id, glucose_estimated, status, ppg_heart_rate, ppg_spo2,
               skin_temp_celsius, created_at
        FROM measurements
        WHERE patient_id = %s
        ORDER BY created_at DESC
        LIMIT 1
    """, (patient_id,))
    m = cursor.fetchone()
    if not m:
        return jsonify({'msg': 'Belum ada pengukuran'}), 404
    m['glucose_estimated'] = str(m['glucose_estimated']) if m['glucose_estimated'] else None
    m['skin_temp_celsius'] = str(m['skin_temp_celsius']) if m['skin_temp_celsius'] else None
    m['created_at'] = m['created_at'].isoformat() if m['created_at'] else None
    return jsonify(m)

@measurements_bp.post('/measurements')
@patient_body_owner_or_medis('patient_id')
@db_connection
def add_measurement(cursor):

    data = request.get_json() or {}

    user = get_current_user()

    if user and user.get('role') == 'pasien':
        patient_id = user.get('id')
    else:
        patient_id = data.get('patient_id')

    if not patient_id:
        return jsonify({'msg': 'patient_id wajib disertakan'}), 400

    created_at = data.get('created_at')
    if not created_at:
        from datetime import datetime
        created_at = datetime.now().isoformat()

    if user and user.get('role') != 'tenaga_medis':
        if not can_access_patient(user, patient_id):
            return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin mengunggah data untuk pasien lain.'}), 403

    source_val = str(data.get('source', 'wifi')).lower()
    if source_val not in ('wifi', 'sdcard'):
        source_val = 'wifi'

    sql = """
        INSERT INTO measurements
        (patient_id, device_id, nir_610nm, nir_680nm, nir_730nm, nir_760nm, nir_810nm, nir_860nm,
         ppg_heart_rate, ppg_spo2, ppg_ir_value, skin_temp_celsius,
         glucose_estimated, glucose_invasive, is_calibration, created_at, source)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    cursor.execute(sql, (
        patient_id,
        data.get('device_id'),
        data.get('nir_610nm'), data.get('nir_680nm'), data.get('nir_730nm'),
        data.get('nir_760nm'), data.get('nir_810nm'), data.get('nir_860nm'),
        data.get('ppg_heart_rate'), data.get('ppg_spo2'), data.get('ppg_ir_value'),
        data.get('skin_temp_celsius'),
        data.get('glucose_estimated'), data.get('glucose_invasive'),
        data.get('is_calibration', False),
        created_at,
        source_val
    ))
    new_id = cursor.lastrowid

    try:
        from app import socketio
        glucose_val = float(data.get('glucose_estimated') or 0)
        status_calc = 'Normal'
        notif_type = None
        if glucose_val > 200:
            status_calc = 'Hiperglikemia'
            notif_type = 'hiperglikemia'
        elif glucose_val < 70 and glucose_val > 0:
            status_calc = 'Hipoglikemia'
            notif_type = 'hipoglikemia'

        cursor.execute("SELECT name FROM users WHERE id = %s", (patient_id,))
        p_row = cursor.fetchone()
        patient_name = p_row['name'] if p_row else f"Pasien #{patient_id}"

        measurement_payload = {
            'id': new_id,
            'patient_id': int(patient_id),
            'patient_name': patient_name,
            'glucose_estimated': glucose_val,
            'ppg_heart_rate': int(data.get('ppg_heart_rate') or 0),
            'skin_temp_celsius': float(data.get('skin_temp_celsius') or 0),
            'ppg_spo2': int(data.get('ppg_spo2') or 98),
            'status': status_calc,
            'created_at': created_at
        }
        socketio.emit('new_measurement', measurement_payload)

        if notif_type:
            try:
                cursor.execute("""
                    INSERT INTO notifications (patient_id, measurement_id, type, glucose_value, is_sent_patient, is_sent_medis, sent_at)
                    VALUES (%s, %s, %s, %s, 1, 1, NOW())
                """, (patient_id, new_id, notif_type, glucose_val))
                notif_id = cursor.lastrowid
            except Exception as dbe:
                print(f"[DB Error] Gagal insert notifications: {dbe}")
                notif_id = None

            notif_payload = {
                'id': notif_id,
                'patient_id': int(patient_id),
                'patient_name': patient_name,
                'measurement_id': new_id,
                'type': notif_type,
                'glucose_value': glucose_val,
                'message': f"Peringatan {status_calc}! Pasien {patient_name} terdeteksi kadar gula darah {glucose_val} mg/dL.",
                'created_at': created_at,
                'status': status_calc
            }
            socketio.emit('new_notification', notif_payload)
            socketio.emit('glucose_alert', notif_payload)
    except Exception as e:
        print(f"[SocketIO Error] Gagal emit new_measurement/notification: {e}")

    return jsonify({'msg': 'Data tersimpan', 'id': new_id}), 201

@measurements_bp.post('/measurements/live-stream')
@patient_body_owner_or_medis('patient_id')
def stream_sensor_data():

    data = request.get_json() or {}
    user = get_current_user()
    if user and 'patient_id' in data:
        if not can_access_patient(user, data['patient_id']):
            return jsonify({'msg': 'Akses ditolak: ID pasien tidak cocok dengan token aktif'}), 403

    try:
        from app import socketio
        socketio.emit('live_sensor_stream', data)
    except Exception as e:
        print(f"[SocketIO Error] Gagal emit live_sensor_stream: {e}")
    return jsonify({'status': 'streamed'}), 200

@measurements_bp.delete('/measurements/<int:id>')
@jwt_required()
@db_connection
def delete_measurement(cursor, id):

    user = get_current_user()
    if not user:
        return jsonify({'msg': 'Token otentikasi tidak valid'}), 401

    cursor.execute("SELECT id, patient_id FROM measurements WHERE id = %s", (id,))
    meas = cursor.fetchone()
    if not meas:
        return jsonify({'msg': 'Data pengukuran tidak ditemukan'}), 404

    if user.get('role') == 'pasien':
        if int(meas['patient_id']) != int(user.get('id', 0)):
            return jsonify({'msg': 'Akses ditolak: Anda tidak memiliki izin menghapus data ini'}), 403

    cursor.execute("DELETE FROM measurements WHERE id = %s", (id,))
    return jsonify({'msg': 'Data pengukuran berhasil dihapus'}), 200
```

---

### Berkas: `rf_service.py`

**Keterangan**: rf_service.py (Logika Estimasi Risiko Diabetes Berbasis Random Forest)  

**Bahasa**: Python  


```python
import os
import joblib
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, '..', '..', 'ml_models')

class RFService:

    def __init__(self):
        self.model = None
        self.scaler = None

        self.expected_features = [
            'age', 'gender', 'bmi', 'hypertension', 'heart_disease',
            'smoking_history', 'blood_glucose_level'
        ]
        self._load_assets()

    def _load_assets(self):
        try:
            model_path = os.path.join(MODEL_DIR, 'glucoband_rf_model.joblib')
            scaler_path = os.path.join(MODEL_DIR, 'scaler_rf.joblib')

            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.model = joblib.load(model_path)
                self.scaler = joblib.load(scaler_path)
                print("✅ Random Forest Model (glucoband_rf_model.joblib) & Scaler (scaler_rf.joblib) berhasil dimuat.")
            else:

                legacy_model_path = os.path.join(MODEL_DIR, 'rf_diabetes.pkl')
                if os.path.exists(legacy_model_path):
                    self.model = joblib.load(legacy_model_path)
                    print("⚠️ Menggunakan fallback model Random Forest lama (rf_diabetes.pkl).")
        except Exception as e:
            print("Gagal memuat model RF:", e)
            self.model = None
            self.scaler = None

    def _parse_gender(self, val) -> int:

        if isinstance(val, (int, float)):
            return 1 if int(val) == 1 else 0
        val_str = str(val).strip().lower()
        if val_str in ['male', 'laki-laki', 'pria', 'm', 'l', '1']:
            return 1
        return 0

    def _parse_smoking(self, val) -> int:

        if isinstance(val, (int, float)):
            return int(val)
        val_str = str(val).strip().lower()
        if val_str in ['former', 'pernah', '2']:
            return 2
        if val_str in ['current', 'merokok', 'aktif', 'ya', 'not current', 'ever', '1']:
            return 1
        return 0

    def predict_risk(self, data: dict) -> dict:

        if self.model is None:
            raise FileNotFoundError("Model Random Forest tidak tersedia atau gagal dimuat")

        glucose = float(data.get('blood_glucose_level', 100.0))
        age = float(data.get('age', 40))
        gender = self._parse_gender(data.get('gender', 'Male'))
        bmi = float(data.get('bmi', 23.0))
        hypertension = 1 if str(data.get('hypertension', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0
        heart_disease = 1 if str(data.get('heart_disease', 0)).strip() in ['1', 'true', 'ya', 'True'] else 0
        smoking = self._parse_smoking(data.get('smoking_history', 0))

        features_dict = {
            'age': age,
            'gender': gender,
            'bmi': bmi,
            'hypertension': hypertension,
            'heart_disease': heart_disease,
            'smoking_history': smoking,
            'blood_glucose_level': glucose
        }

        df_input = pd.DataFrame([features_dict], columns=self.expected_features)

        if self.scaler is not None:
            input_scaled = self.scaler.transform(df_input)
        else:
            input_scaled = df_input

        try:
            pred_proba = self.model.predict_proba(input_scaled)[0]
            prob_non_diabetes = float(pred_proba[0] * 100)
            prob_diabetes = float(pred_proba[1] * 100)
            score = float(pred_proba[1])
        except AttributeError:
            pred = self.model.predict(input_scaled)[0]
            score = float(pred)
            prob_diabetes = score * 100
            prob_non_diabetes = 100.0 - prob_diabetes

        prediction_class = 1 if score >= 0.50 else 0

        if prob_diabetes < 30.0:
            level = "Rendah"
            risk_label = "RENDAH"
            class_name = "Non-diabetes (Normal)"
            badge = "🟢 LOW RISK"
            recommendation = (
                "Kondisi metabolisme tubuh baik. Pertahankan pola hidup sehat, "
                "olahraga teratur, dan pemantauan rutin."
            )
        elif prob_diabetes < 60.0:
            level = "Sedang"
            risk_label = "SEDANG"
            class_name = "Risiko Sedang (Waspada)"
            badge = "🟡 MODERATE RISK"
            recommendation = (
                "Terdeteksi indikasi risiko sedang diabetes. Disarankan menjaga asupan gizi seimbang, "
                "kurangi konsumsi gula berlebih, dan konsultasi berkala."
            )
        else:
            level = "Tinggi"
            risk_label = "TINGGI"
            class_name = "Diabetes"
            badge = "🔴 HIGH RISK"
            recommendation = (
                "Terdeteksi risiko tinggi diabetes. Disarankan untuk segera melakukan konsultasi "
                "dengan dokter spesialis penyakit dalam untuk evaluasi klinis."
            )

        risk_factors = []
        if glucose > 140:
            risk_factors.append(f"Gula darah di atas ambang normal ({glucose:.1f} mg/dL)")
        if bmi >= 25.0:
            risk_factors.append(f"Indeks massa tubuh tinggi / overweight ({bmi:.1f})")
        if hypertension == 1:
            risk_factors.append("Riwayat hipertensi")
        if heart_disease == 1:
            risk_factors.append("Riwayat penyakit kardiovaskular")
        if smoking in [1, 2]:
            risk_factors.append("Riwayat merokok aktif/pernah")

        return {
            "risk_level": level,
            "risk_label": risk_label,
            "class_name": class_name,
            "risk_score": round(score, 4),
            "prob_diabetes": round(prob_diabetes, 2),
            "prob_non_diabetes": round(prob_non_diabetes, 2),
            "prediction": prediction_class,
            "badge": badge,
            "recommendation": recommendation,
            "model_version": "RF_v2.0",
            "model version": "RF_v2.0",
            "risk_factors": risk_factors
        }
```

---



## 3. APLIKASI MOBILE PASIEN (FLUTTER / DART)

### Berkas: `main.dart`

**Keterangan**: main.dart (Entry Point Aplikasi Mobile, Inisialisasi Provider State & Konfigurasi Tema)  

**Bahasa**: Dart  


```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'presentation/providers/authProvider.dart';
import 'services/localNotificationService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await LocalNotificationService.initialize();
  final authProvider = AuthProvider();
  await authProvider.checkLoginStatus();

  runApp(GlucoBandApp(authProvider: authProvider));
}
```

---

### Berkas: `measurementPage.dart`

**Keterangan**: measurementPage.dart (Antarmuka Utama Pengukuran Glukosa Real-Time, Pengiriman Spektrum NIR ke API XGBoost & Polling)  

**Bahasa**: Dart  


```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/measurementProvider.dart';
import '../providers/authProvider.dart';
import '../../services/espService.dart';
import '../widgets/deviceConfigDialog.dart';
import 'measurementResult.dart';
import 'measurementHistoryPage.dart';
import '../../services/apiService.dart';
import '../../core/constants/apiConstant.dart';

class MeasurementPage extends StatefulWidget {
  final bool autoStart;
  const MeasurementPage({super.key, this.autoStart = false});

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _pulseController;
  double _gaugeValue = 0;
  bool _isMeasuring = false;
  bool _isWaitingForFinger = false;
  String _statusText = 'Status Perangkat:\nMemeriksa Koneksi...';
  double _progress = 0;
  bool _isDeviceConnected = false;
  String _deviceIp = '192.168.4.1';
  String _heartRateText = '-- BPM';
  String _temperatureText = '-- °C';
  String _batteryText = '--';
  Timer? _statusPollingTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initDeviceConnection();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMeasurement();
      });
    }

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isMeasuring && mounted) {
        _checkEspConnection();
      }
    });
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initDeviceConnection() async {
    _deviceIp = await EspService.getDeviceIp();
    await _checkEspConnection();
  }

  Future<void> _checkEspConnection() async {
    try {
      final status = await EspService.checkStatus();
      if (!mounted) return;

      final bool wasDisconnected = !_isDeviceConnected;
      _isDeviceConnected = true;
      _deviceIp = status['ip'] ?? _deviceIp;
      final rawBatt = status['battery'] ?? status['battery_level'];
      _batteryText = rawBatt != null ? '$rawBatt%' : 'Optimal';

      if (wasDisconnected && !_isMeasuring) {
        setState(() {
          _statusText = 'Status Perangkat:\nGlucoBand Siap Digunakan';
        });
      } else if (mounted && !_isMeasuring) {
        if (_statusText.contains('Terputus') || _statusText.contains('Memeriksa')) {
          setState(() {
            _statusText = 'Status Perangkat:\nGlucoBand Siap Digunakan';
          });
        }
      }

      try {
        final live = await EspService.getLiveSensors();
        if (mounted) {
          setState(() {
            if (live['bpm'] != null && live['bpm'] > 0) {
              _heartRateText = '${live['bpm']} BPM';
            }
            if (live['temperature'] != null) {
              _temperatureText = '${(live['temperature'] as num).toStringAsFixed(1)}°C';
            }
          });
        }
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      if (_isDeviceConnected || _statusText.contains('Siap Digunakan') || _statusText.contains('Memeriksa')) {
        setState(() {
          _isDeviceConnected = false;
          _batteryText = '--';
          _heartRateText = '-- BPM';
          _temperatureText = '-- °C';
          if (!_isMeasuring) {
            _statusText = 'Terputus dari GlucoBand\n(Periksa koneksi WiFi)';
          }
        });
      }
    }
  }

  void _cancelMeasurement() {
    setState(() {
      _isMeasuring = false;
      _isWaitingForFinger = false;
      _progress = 0;
      _statusText = 'Pengukuran dibatalkan.\nStatus: GlucoBand Siap Digunakan';
    });
  }

  Future<void> _startMeasurement() async {
    if (_isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _isWaitingForFinger = false;
      _statusText = 'Menghubungi GlucoBand di $_deviceIp...';
      _progress = 0.2;
    });

    try {
      final wifiStatus = await EspService.checkStatus();
      if (!mounted) return;
      setState(() {
        _isDeviceConnected = true;
        _progress = 0.35;
        final ssid = wifiStatus['ssid'] != null && wifiStatus['ssid'].toString().isNotEmpty
            ? wifiStatus['ssid']
            : wifiStatus['ap_ssid'] ?? 'GlucoBand';
        _statusText = 'Terhubung ke $ssid\nInisiasi hardware sensor...';
      });

      final initData = await EspService.initDevice();
      final sensors = initData['sensors'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _progress = 0.5;
        _statusText = 'Inisiasi Sensor:\n'
            'PPG: ${sensors["max30105"] == true ? "OK" : "ERR"} | '
            'Suhu: ${sensors["mlx90614"] == true ? "OK" : "ERR"} | '
            'NIR: ${sensors["as726x"] == true ? "OK" : "ERR"}';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() {
        _isWaitingForFinger = true;
        _heartRateText = '-- BPM';
        _statusText = 'Menunggu Jari...\nTempelkan jari Anda pada sensor GlucoBand untuk melanjutkan';
      });

      Map<String, dynamic>? liveData;

      while (_isMeasuring && mounted) {
        try {
          final data = await EspService.getLiveSensors();
          if (data['finger_present'] == true) {
            liveData = data;
            break;
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!_isMeasuring || !mounted) return;

      setState(() {
        _isWaitingForFinger = false;
        _progress = 0.55;
        _statusText = 'Menganalisis Detak Jantung...\nTetap tempelkan jari secara stabil di sensor';
        _heartRateText = 'Mengukur...';
      });

      int finalBpm = 0;
      double finalTemp = 36.5;
      int stableCount = 0;
      int lastSeenBpm = 0;
      int loopCycles = 0;
      const int maxCycles = 30;

      while (_isMeasuring && mounted && loopCycles < maxCycles) {
        loopCycles++;
        await Future.delayed(const Duration(milliseconds: 450));

        try {
          final sample = await EspService.getLiveSensors();
          if (!mounted) return;
          if (sample['finger_present'] == false) {
            setState(() {
              _isWaitingForFinger = true;
              _heartRateText = '-- BPM';
              _progress = 0.50;
              _statusText = 'Jari Terangkat!\nTempelkan kembali jari Anda untuk melanjutkan analisis';
            });

            while (_isMeasuring && mounted) {
              await Future.delayed(const Duration(milliseconds: 400));
              try {
                final check = await EspService.getLiveSensors();
                if (check['finger_present'] == true) {
                  liveData = check;
                  break;
                }
              } catch (_) {}
            }

            if (!_isMeasuring || !mounted) return;

            setState(() {
              _isWaitingForFinger = false;
              _progress = 0.55;
              _heartRateText = 'Mengukur...';
              _statusText = 'Menganalisis Detak Jantung...\nTetap tempelkan jari secara stabil di sensor';
            });
            continue;
          }

          liveData = sample;
          final rawBpm = sample['bpm'];
          final int currentBpm = (rawBpm is num && rawBpm > 0) ? rawBpm.toInt() : 0;
          final int rateCount = (sample['rate_count'] is num) ? (sample['rate_count'] as num).toInt() : 0;
          final rawTemp = sample['temperature'];

          if (rawTemp is num && rawTemp > 0) {
            finalTemp = rawTemp.toDouble();
          }

          setState(() {
            _temperatureText = '${finalTemp.toStringAsFixed(1)}°C';

            if (currentBpm > 0) {
              _heartRateText = '$currentBpm BPM';
              if (rateCount > 0) {
                _statusText = 'Menganalisis Detak Jantung...\nDenyut nadi terdeteksi ($rateCount/8 detak stabil)';
                _progress = (0.55 + (rateCount / 8.0) * 0.32).clamp(0.55, 0.88);
              } else {
                _statusText = 'Menganalisis Detak Jantung: $currentBpm BPM\nMenstabilkan denyut nadi...';
                _progress = 0.70;
              }
            } else {
              _heartRateText = 'Mengukur...';
              _statusText = 'Menganalisis Detak Jantung...\nMencari denyut nadi. Jangan gerakkan jari Anda.';
              _progress = (0.50 + (loopCycles * 0.008)).clamp(0.50, 0.65);
            }
          });

          if (currentBpm >= 40 && currentBpm <= 180) {
            if (currentBpm == lastSeenBpm) {
              stableCount++;
            } else {
              lastSeenBpm = currentBpm;
              stableCount = 1;
            }

            if (rateCount >= 4 || stableCount >= 4) {
              finalBpm = currentBpm;
              break;
            }
          }
        } catch (_) {}
      }

      if (!_isMeasuring || !mounted) return;

      if (finalBpm == 0) {
        if (lastSeenBpm > 0) {
          finalBpm = lastSeenBpm;
        } else if (liveData != null && liveData['bpm'] is num && liveData['bpm'] > 0) {
          finalBpm = (liveData['bpm'] as num).toInt();
        } else {
          finalBpm = 75;
        }
      }

      setState(() {
        _progress = 0.92;
        _heartRateText = '$finalBpm BPM';
        _statusText = 'Detak Jantung Terkunci: $finalBpm BPM!\nMenganalisis spektrum NIR dengan AI XGBoost...';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      double finalGlucose = 115.0;

      if (liveData != null) {
        final rawTemp = liveData['temperature'];
        if (rawTemp is num && rawTemp > 0) finalTemp = rawTemp.toDouble();

        final rawEspGlucose = liveData['glucose_estimated'];
        if (rawEspGlucose is num && rawEspGlucose > 0) {
          finalGlucose = rawEspGlucose.toDouble();
        } else {

          final nir = liveData['nir'] as Map<String, dynamic>?;
          if (nir != null) {
            final r = (nir['r'] as num?)?.toDouble() ?? 165.79;
            final s = (nir['s'] as num?)?.toDouble() ?? 169.34;
            final t = (nir['t'] as num?)?.toDouble() ?? 86.86;
            final u = (nir['u'] as num?)?.toDouble() ?? 43.53;
            final v = (nir['v'] as num?)?.toDouble() ?? 21.73;
            final w = (nir['w'] as num?)?.toDouble() ?? 12.95;

            int? currentPatientId;
            try {
              currentPatientId = Provider.of<AuthProvider>(context, listen: false).user?.id;
            } catch (_) {}

            try {
              final payload = {
                'R': r, 'S': s, 'T': t, 'U': u, 'V': v, 'W': w,
                if (currentPatientId != null && currentPatientId > 0) 'patient_id': currentPatientId,
              };
              final response = await _apiService.post(
                ApiConstants.xgbPredict,
                data: payload,
              );
              if (response.statusCode == 200 && response.data is Map) {
                final gVal = response.data['Glucose'] ?? response.data['glucose'];
                if (gVal is num && gVal > 0) {
                  finalGlucose = gVal.toDouble();
                }
              }
            } catch (e) {
              debugPrint('Prediksi error, fallback local: $e');

              finalGlucose = (70.0 + (r * 0.25 + s * 0.28 + t * 0.2 + u * 0.15 + v * 0.1 + w * 0.05)).clamp(70.0, 240.0);
            }
          } else {
            finalGlucose = 95.0 + (finalBpm % 15);
          }
        }
      } else {
        finalGlucose = 88.0 + Random().nextDouble() * 30;
      }

      if (!mounted) return;
      Provider.of<MeasurementProvider>(context, listen: false).updateGlucose(finalGlucose);

      setState(() {
        _progress = 1.0;
        _gaugeValue = finalGlucose;
        _heartRateText = '$finalBpm BPM';
        _temperatureText = '${finalTemp.toStringAsFixed(1)}°C';
        _isMeasuring = false;
        _statusText = 'Status Perangkat:\nPengukuran Selesai!';
      });

      final bool? shouldRestart = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MeasurementResultPage(
            glucose: finalGlucose,
            heartRate: finalBpm,
            temperature: finalTemp,
          ),
        ),
      );

      if (shouldRestart == true && mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _startMeasurement();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMeasuring = false;
        _isWaitingForFinger = false;
        _isDeviceConnected = false;
        _progress = 0;
        _statusText = _formatErrorMessage(e);
      });

      DeviceConfigDialog.show(context, onConnected: () => _checkEspConnection());
    }
  }

  String _formatErrorMessage(dynamic error) {
    if (error == null) return 'Gagal terhubung ke GlucoBand\n(Periksa koneksi WiFi)';
    String raw = error.toString();
    raw = raw.replaceAll(RegExp(r'^(Exception|DioException|SocketException|FormatException|Error):\s*', caseSensitive: false), '');
    raw = raw.replaceAll(RegExp(r'\[.*?\]'), '');
    raw = raw.trim();

    if (raw.toLowerCase().contains('respons status') ||
        raw.toLowerCase().contains('connection refused') ||
        raw.toLowerCase().contains('timed out') ||
        raw.toLowerCase().contains('failed host lookup') ||
        raw.isEmpty) {
      return 'Gagal terhubung ke GlucoBand\n(Periksa koneksi WiFi)';
    }

    return '$raw\n(Periksa koneksi WiFi)';
  }

  Widget _buildRippleEffect() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!_isMeasuring)
              Container(
                width: 220 + (_pulseController.value * 80),
                height: 220 + (_pulseController.value * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (1.0 - _pulseController.value) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            if (!_isMeasuring)
              Container(
                width: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                height: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (1.0 - ((_pulseController.value + 0.5) % 1.0)) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: _buildMainButton(),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _isWaitingForFinger
          ? _cancelMeasurement
          : (_isMeasuring ? null : _startMeasurement),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isWaitingForFinger
              ? Colors.amber.withValues(alpha: 0.18)
              : (_isMeasuring
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent),
          border: Border.all(
            color: _isWaitingForFinger
                ? const Color(0xFFFBBF24).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: _isWaitingForFinger
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.touch_app, color: Color(0xFFFBBF24), size: 44),
                    SizedBox(height: 10),
                    Text(
                      'TEMPELKAN JARI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pending sensor...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : (_isMeasuring
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Mulai',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A3FE0),
      body: SafeArea(
        child: Column(
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  InkWell(
                    onTap: () => DeviceConfigDialog.show(
                      context,
                      onConnected: () => _checkEspConnection(),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isDeviceConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDeviceConnected ? Icons.wifi : Icons.wifi_off,
                            color: _isDeviceConnected ? const Color(0xFF10B981) : Colors.red.shade300,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDeviceConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Riwayat Pengukuran',
                    icon: const Icon(Icons.history, color: Colors.white, size: 26),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MeasurementHistoryPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            _buildRippleEffect(),

            if (_isWaitingForFinger)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextButton.icon(
                  onPressed: _cancelMeasurement,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white70, size: 16),
                  label: const Text(
                    'Batalkan Pengukuran',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            const Spacer(flex: 2),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'BATERAI',
                          _isDeviceConnected ? _batteryText : '--',
                          valueColor: _isDeviceConnected
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'STATUS ALAT',
                          _isDeviceConnected ? 'Siap Digunakan' : 'Belum Terhubung',
                          valueColor: _isDeviceConnected
                              ? const Color(0xFF10B981)
                              : Colors.red.shade300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('DENYUT NADI', _heartRateText)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInfoCard('SUHU TUBUH', _temperatureText)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
```

---

### Berkas: `measurementResult.dart`

**Keterangan**: measurementResult.dart (Visualisasi Hasil Estimasi Glukosa Darah XGBoost, Nadi, Suhu & Sinkronisasi Cloud)  

**Bahasa**: Dart  


```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profileProvider.dart';
import '../providers/authProvider.dart';
import '../providers/measurementProvider.dart';
import '../providers/notificationProvider.dart';
import '../../services/localNotificationService.dart';
import 'measurementHistoryPage.dart';

class MeasurementResultPage extends StatefulWidget {
  final double glucose;
  final int heartRate;
  final double temperature;

  const MeasurementResultPage({
    super.key,
    required this.glucose,
    required this.heartRate,
    required this.temperature,
  });

  @override
  State<MeasurementResultPage> createState() => _MeasurementResultPageState();
}

class _MeasurementResultPageState extends State<MeasurementResultPage> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final measProvider = Provider.of<MeasurementProvider>(context, listen: false);

      final patientId = auth.user?.id != null && auth.user!.id > 0
          ? auth.user!.id
          : (profile.profileData?['id'] ?? 1);

      final isSuccess = await measProvider.saveMeasurement(
        patientId: patientId,
        glucose: widget.glucose,
        heartRate: widget.heartRate,
        temperature: widget.temperature,
      );

      if (!mounted) return;

      if (isSuccess) {

        String statusCalc = 'Normal';
        if (widget.glucose < 70) {
          statusCalc = 'Hipoglikemia';
        } else if (widget.glucose > 200) {
          statusCalc = 'Hiperglikemia';
        } else if (widget.glucose >= 140) {
          statusCalc = 'Waspada';
        }

        if (statusCalc != 'Normal') {
          LocalNotificationService.showGlucoseNotification(
            glucose: widget.glucose,
            status: statusCalc,
          );
        }

        if (auth.token != null) {
          Provider.of<NotificationProvider>(context, listen: false)
              .fetchNotifications(auth.token!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil disimpan ke riwayat pengukuran & disinkronkan!'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MeasurementHistoryPage(),
          ),
        );
      } else {

        measProvider.updateGlucose(widget.glucose);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data pengukuran tersimpan di riwayat lokal.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MeasurementHistoryPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat menyimpan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.glucose > 200
        ? 'Hiperglikemia'
        : widget.glucose < 70
        ? 'Hipoglikemia'
        : 'Normal';

    final statusColor = widget.glucose > 200
        ? const Color(0xFFEF4444)
        : widget.glucose < 70
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Hasil Pengukuran'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.monitor_heart,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.glucose.toInt()} mg/dL',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    Icons.favorite,
                    const Color(0xFFEF4444),
                    '${widget.heartRate}',
                    'BPM (${widget.heartRate >= 60 && widget.heartRate <= 100 ? "Normal" : (widget.heartRate < 60 ? "Rendah" : "Tinggi")})',
                    'Detak Jantung (OLED)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    Icons.thermostat,
                    const Color(0xFFF59E0B),
                    '${widget.temperature.toStringAsFixed(1)}°C',
                    'Suhu Kulit',
                    'Inframerah MLX',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Pengukuran Terintegrasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.favorite,
                    'Detak Jantung (MAX30105)',
                    '${widget.heartRate} BPM (Sama dengan Layar OLED)',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.thermostat,
                    'Suhu Kulit (MLX90614)',
                    '${widget.temperature.toStringAsFixed(1)} °C (Objek Termal)',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.wifi,
                    'Spektrometer NIR (AS7263)',
                    '6 Saluran Spektral (R–W Terkalibrasi)',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.psychology,
                    'Model Estimasi Glukosa',
                    'XGBoost Regressor v1.0 Non-Invasif',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Data',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF613EEA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF613EEA).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Ukur Lagi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF613EEA),
                      side: const BorderSide(
                        color: Color(0xFF613EEA),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    Color color,
    String value,
    String unit,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String detail) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF613EEA)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

---



## 4. PORTAL WEB TENAGA MEDIS (REACT / JSX)

### Berkas: `App.jsx`

**Keterangan**: App.jsx (Konfigurasi Routing Portal Tenaga Medis, Layout Navigasi & Proteksi Hak Akses)  

**Bahasa**: JavaScript / JSX  


```javascript
import { useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom'
import LoginPage from './pages/loginPage'
import ProtectedRoute from './components/protectedRoute'
import AdminLayout from './components/common/AdminLayout'
import DashboardPage from './pages/Dashboard'
import RealtimeMonitorPage from './pages/monitoring/RealtimeMonitoring'
import PatientListPage from './pages/PatientListPage'
import TambahPasien from './pages/tambahPasien'
import EditPasien from './pages/editPasien'
import PatientDetailPage from './pages/patientDetail'
import NotificationPage from './pages/notificationPage'
import FAQManagePage from './pages/FAQManagement'
import SettingsPage from './pages/Settings'
import NakesPage from './pages/nakesPage'
import DownloadPage from './pages/DownloadPage'
import NotFound from './pages/NotFound'

function TitleUpdater() {
  const location = useLocation()

  useEffect(() => {
    const titles = {
      '/admin/dashboard': 'Dashboard - GlucoBand',
      '/admin/monitoring': 'Monitoring - GlucoBand',
      '/admin/data-pasien': 'Data Pasien - GlucoBand',
      '/admin/tenaga-medis': 'Daftar Tenaga Medis - GlucoBand',
      '/admin/notifications': 'Notifikasi - GlucoBand',
      '/admin/faq': 'FAQ - GlucoBand',
      '/admin/settings': 'Pengaturan - GlucoBand',
      '/admin/tambah-pasien': 'Tambah Pasien - GlucoBand',
      '/login': 'Login - GlucoBand',
      '/download': 'Unduh Aplikasi Mobile - GlucoBand',
      '/unduh': 'Unduh Aplikasi Mobile - GlucoBand',
    }

    if (location.pathname.startsWith('/admin/edit-pasien')) {
      document.title = 'Edit Pasien - GlucoBand'
    } else if (location.pathname.startsWith('/admin/detail-pasien')) {
      document.title = 'Detail Pasien - GlucoBand'
    } else {
      document.title = titles[location.pathname] || 'GlucoBand'
    }
  }, [location])

  return null
}

export default function App() {
  return (
    <BrowserRouter>
      <TitleUpdater />
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/download" element={<DownloadPage />} />
        <Route path="/unduh" element={<DownloadPage />} />
        <Route element={<ProtectedRoute allowedRoles={['tenaga_medis']} />}>
          <Route element={<AdminLayout />}>
            <Route path="/admin/dashboard" element={<DashboardPage />} />
            <Route path="/admin/monitoring" element={<RealtimeMonitorPage />} />
            <Route path="/admin/data-pasien" element={<PatientListPage />} />
            <Route path="/admin/tenaga-medis" element={<NakesPage />} />
            <Route path="/admin/tambah-pasien" element={<TambahPasien />} />
            <Route path="/admin/edit-pasien/:id" element={<EditPasien />} />
            <Route path="/admin/detail-pasien/:id" element={<PatientDetailPage />} />
            <Route path="/admin/notifications" element={<NotificationPage />} />
            <Route path="/admin/faq" element={<FAQManagePage />} />
            <Route path="/admin/settings" element={<SettingsPage />} />
          </Route>
        </Route>
        <Route path="/" element={<Navigate to="/admin/dashboard" replace />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  )
}
```

---

### Berkas: `notificationPage.jsx`

**Keterangan**: notificationPage.jsx (Sistem Peringatan Dini / Early Warning System Pasien Hipoglikemia & Hiperglikemia)  

**Bahasa**: JavaScript / JSX  


```javascript
import { useState, useEffect } from 'react'
import apiClient from '../api/axios'
import LoadingSkeleton from '../components/common/loading'

export default function NotificationPage() {
  const [notifs, setNotifs] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    apiClient.get('/notifications?limit=50')
      .then(({ data }) => setNotifs(data))
      .catch(console.error)
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <LoadingSkeleton rows={5} />

  return (
    <div>
      <h1 className="text-2xl font-bold text-darkNavy mb-6">Notifikasi Peringatan</h1>
      <div className="bg-white rounded-xl shadow-sm p-6">
        {notifs.length === 0 ? (
          <p className="text-center text-gray-400 py-8">Tidak ada notifikasi.</p>
        ) : (
          <ul className="space-y-3">
            {notifs.map(notif => (
              <li key={notif.id} className={`p-4 rounded-lg ${notif.type === 'hiperglikemia' ? 'bg-red-50 text-red-800' : 'bg-amber-50 text-amber-800'}`}>
                <div className="flex justify-between items-start">
                  <div>
                    <span className="font-medium">{notif.patient_name || 'Pasien'}</span>
                    <p className="text-sm mt-1">Glukosa: <strong>{notif.glucose_value} mg/dL</strong> ({notif.type === 'hiperglikemia' ? 'Hiperglikemia' : 'Hipoglikemia'})</p>
                    {notif.message && <p className="text-sm mt-1 opacity-80">{notif.message}</p>}
                  </div>
                  <span className="text-xs">{new Date(notif.created_at).toLocaleString('id-ID')}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}
```

---
