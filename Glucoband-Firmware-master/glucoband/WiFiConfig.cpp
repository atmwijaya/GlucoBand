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
      
      // Re-inisialisasi mode AP secara bersih lengkap dengan IP statis dan DHCP aktif
      startAPMode();
      
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
  // Matikan koneksi WiFi sebelumnya secara bersih
  WiFi.disconnect(true, false);
  delay(100);

  // Set mode AP_STA agar mendukung Access Point sekaligus koneksi STA
  WiFi.mode(WIFI_AP_STA);
  delay(100);

  // Set konfigurasi regulasi negara (Indonesia/International) kanal 1-13
  // Sangat penting agar beacon AP terdeteksi oleh smartphone Samsung, Oppo, Vivo, iPhone
  wifi_country_t country = { .cc = "ID", .schan = 1, .nchan = 13, .max_tx_power = 78, .policy = WIFI_COUNTRY_POLICY_AUTO };
  esp_wifi_set_country(&country);

  // Alamat IP statis default AP (192.168.4.1)
  IPAddress apIP(192, 168, 4, 1);
  IPAddress gateway(192, 168, 4, 1);
  IPAddress subnet(255, 255, 255, 0);
  WiFi.softAPConfig(apIP, gateway, subnet);
  delay(100);

  // Parameter: SSID, password (NULL = Terbuka), channel 1, hidden 0, max 4 device
  bool apSuccess = WiFi.softAP("GlucoBand-Setup", NULL, 1, 0, 4);

  // Optimasi kompatibilitas untuk SEMUA merek HP (Samsung, Vivo, Xiaomi/Redmi, Oppo, Realme, iPhone):
  // 1. Nonaktifkan modem sleep & set kekuatan sinyal RF maksimal (+19.5 dBm)
  WiFi.setSleep(false);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  esp_wifi_set_ps(WIFI_PS_NONE);

  // 2. Kunci bandwidth AP ke 20MHz (HT20) untuk kompatibilitas chipset MediaTek/Exynos/Qualcomm
  esp_wifi_set_bandwidth(WIFI_IF_AP, WIFI_BW_HT20);
  esp_wifi_set_protocol(WIFI_IF_AP, WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N);

  // 3. Jalankan Captive Portal DNS Server pada port 53
  dnsServer.stop();
  dnsServer.start(53, "*", apIP);

  // 4. Aktifkan responder mDNS untuk domain glucoband.local pada AP
  MDNS.begin("glucoband");
  MDNS.addService("http", "tcp", 80);

  apModeActive = true;

  if (apSuccess) {
    Serial.println("[WiFi] Access Point 'GlucoBand-Setup' AKTIF di Channel 1.");
    Serial.println("[WiFi] Captive Portal DNS Server aktif (Port 53)");
    Serial.print("[WiFi] IP Gateway AP: ");
    Serial.println(WiFi.softAPIP());
  } else {
    Serial.println("[WiFi] PERINGATAN: Gagal mengaktifkan SoftAP! Mencoba ulang...");
    delay(200);
    WiFi.softAP("GlucoBand-Setup", NULL, 1, 0, 4);
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

  // Android / Google / Samsung / Pixel / Motorola Captive Portal Probes
  server.on("/generate_204", HTTP_GET, [this]() { sendCorsHeader(); server.send(204); });
  server.on("/gen_204", HTTP_GET, [this]() { sendCorsHeader(); server.send(204); });
  server.on("/mobile/status", HTTP_GET, [this]() { sendCorsHeader(); server.send(204); });

  // Xiaomi / Redmi / MIUI / HyperOS
  server.on("/connect.rom.miui.com/generate_204", HTTP_GET, [this]() { sendCorsHeader(); server.send(204); });

  // Oppo / Realme / OnePlus (ColorOS)
  server.on("/check_network_status", HTTP_GET, [this]() { sendCorsHeader(); server.send(200, "text/plain", "SUCCESS"); });
  server.on("/network/check", HTTP_GET, [this]() { sendCorsHeader(); server.send(200, "text/plain", "SUCCESS"); });

  // Vivo / iQOO (FuntouchOS / OriginOS)
  server.on("/portal/check", HTTP_GET, [this]() { sendCorsHeader(); server.send(200, "text/plain", "SUCCESS"); });

  // Huawei (EMUI / HarmonyOS)
  server.on("/connectivity-check.html", HTTP_GET, [this]() { sendCorsHeader(); server.send(204); });

  // Apple iOS / macOS Captive Network Assistant (CNA)
  server.on("/hotspot-detect.html", HTTP_GET, [this]() { 
    sendCorsHeader();
    server.send(200, "text/html", "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"); 
  });
  server.on("/canonical.html", HTTP_GET, [this]() { 
    sendCorsHeader();
    server.send(200, "text/html", "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"); 
  });
  server.on("/success.html", HTTP_GET, [this]() { 
    sendCorsHeader();
    server.send(200, "text/html", "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"); 
  });
  server.on("/library/test/success.html", HTTP_GET, [this]() { 
    sendCorsHeader();
    server.send(200, "text/html", "<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"); 
  });

  // Microsoft Windows NCSI
  server.on("/ncsi.txt", HTTP_GET, [this]() { sendCorsHeader(); server.send(200, "text/plain", "Microsoft NCSI"); });
  server.on("/connecttest.txt", HTTP_GET, [this]() { sendCorsHeader(); server.send(200, "text/plain", "Microsoft Connect Test"); });

  // REST API Routes
  server.on("/api/status", HTTP_GET, [this]() { handleApiStatus(); });
  server.on("/api/scan", HTTP_GET, [this]() { handleScan(); });
  server.on("/api/init", HTTP_GET, [this]() { handleApiInit(); });
  server.on("/api/sensors", HTTP_GET, [this]() { handleApiSensors(); });
  server.on("/api/save", HTTP_POST, [this]() { handleApiSave(); });
  server.on("/api/wifi", HTTP_POST, [this]() { handleApiSave(); });
  server.on("/api/reset", HTTP_POST, [this]() { handleApiReset(); });
  server.on("/api/disconnect", HTTP_POST, [this]() { handleApiDisconnect(); });
  server.on("/api/disconnect", HTTP_GET, [this]() { handleApiDisconnect(); });

  server.onNotFound([this]() {
    if (server.method() == HTTP_OPTIONS) {
      sendCorsHeader();
      server.send(204);
      return;
    }

    // Jika request mengarah ke endpoint API yang tidak terdaftar, kembalikan 404 JSON (bukan HTML)
    // agar aplikasi Flutter tidak mengalami crash/format exception
    if (server.uri().startsWith("/api/")) {
      sendCorsHeader();
      server.send(404, "application/json", "{\"error\":\"API endpoint tidak ditemukan\"}");
      return;
    }

    if (apModeActive) {
      handleRoot();
    } else {
      server.send(404, "text/plain", "Not Found");
    }
  });
}

void WiFiConfig::handleRoot() {
  sendCorsHeader();
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
  html += ".alert{background:#fef3c7;color:#92400e;padding:10px 14px;border-radius:10px;font-size:12px;margin-bottom:14px;text-align:left;line-height:1.4}";
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
  html += "<div class='alert'><b>Tips Samsung/Vivo/Oppo:</b> Jika muncul notifikasi <i>'WiFi tidak ada internet'</i>, ketuk dan pilih <b>Tetap Terhubung</b> atau nonaktifkan Data Seluler sementara agar koneksi stabil.</div>";
  html += "<div id='networks'></div>";
  html += "<form action='/save' method='POST'>";
  html += "<label>Pilih WiFi Rumah/Hotspot:</label>";
  html += "<select id='ssid' name='ssid' required><option value=''>Memuat jaringan...</option></select>";
  html += "<label>Password WiFi:</label>";
  html += "<input name='password' type='password' placeholder='Masukkan password WiFi' required>";
  html += "<button type='submit'>Simpan & Hubungkan</button>";
  html += "<div class='info'>Alamat IP: 192.168.4.1</div>";
  html += "</form></div></body></html>";
  sendCorsHeader();
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
    WiFi.scanNetworks(true); // scan async
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
  
  sendCorsHeader();
  server.send(200, "text/html", html);
  
  delay(1200);
  ESP.restart();
}

// REST API: GET /api/status
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

// REST API: GET /api/init (Inisiasi hardware & kesiapan sensor)
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

// REST API: GET /api/sensors (Pembacaan live sensor)
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

// REST API: POST /api/save atau /api/wifi
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

  // Pastikan mode WIFI_AP_STA tetap aktif agar SoftAP GlucoBand-Setup tidak putus!
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
  server.send(200, "application/json", "{\"message\":\"Kredensial WiFi dihapus, kembali ke mode AP...\"}");
  delay(500);
  disconnectRouter();
}

void WiFiConfig::handleApiDisconnect() {
  sendCorsHeader();
  disconnectRouter();
  String resp = "{\"success\":true,\"wifi_connected\":false,\"ip\":\"192.168.4.1\",\"ap_ip\":\"192.168.4.1\",\"message\":\"Koneksi router diputus. Mode AP 192.168.4.1 aktif.\"}";
  server.send(200, "application/json", resp);
}

void WiFiConfig::disconnectRouter() {
  Serial.println("\n[WiFi] Memutuskan koneksi router dan mengaktifkan AP 192.168.4.1...");
  wifiConnected = false;
  connectionStatus = "AP Setup Mode";
  failedAttempts = 99; // Hentikan auto-reconnect agar AP tidak terganggu

  // Putuskan STA secara bersih tanpa mematikan modul radio
  WiFi.disconnect(true, false);
  delay(100);

  // Re-aktifkan Access Point pada Channel 1 dengan DNS aktif
  startAPMode();
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
  failedAttempts = 99;
  WiFi.disconnect(true, true); // Hapus juga dari NVS WiFi driver ESP-IDF!
  Serial.println("[WiFi] Kredensial WiFi berhasil dihapus.");
}

bool WiFiConfig::connectToWiFi() {
  // Disconnect STA interface only, do NOT kill the AP interface!
  WiFi.disconnect(false, true); 
  delay(50); 
  WiFi.begin(ssid.c_str(), password.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 12) {
    delay(400);
    // Layani DNS & client AP agar koneksi smartphone tidak terputus/freeze saat ESP mencari router
    if (apModeActive) {
      dnsServer.processNextRequest();
      server.handleClient();
    }
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
    disconnectRouter();
  }
#endif
}

void WiFiConfig::handle() {
  checkResetButton();

  // Proses antrean DNS Captive Portal secara cepat (burst processing)
  // Sangat krusial untuk Samsung, Oppo, Vivo, Realme, dan iPhone agar tidak timeout saat background DNS dikirim
  if (apModeActive) {
    for (int i = 0; i < 4; i++) {
      dnsServer.processNextRequest();
    }
  }

  // Reset via perintah huruf 'r' di Serial Monitor untuk mempermudah pengujian
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r' || c == 'R') {
      Serial.println("\n[WiFi] Perintah Reset diterima dari Serial. Menghapus konfigurasi WiFi...");
      clearCredentials();
      delay(500);
      disconnectRouter();
    }
  }

  // Layani HTTP Web Server & REST API
  server.handleClient();
  
  // Auto reconnect ke router jika sempat putus
  // PENTING: Hanya lakukan jika TIDAK ADA HP yang sedang terhubung ke SoftAP (getConnectedClients() == 0)
  // agar proses scanning router tidak memutus (channel-hopping) koneksi HP yang sedang konfigurasi!
  if (!wifiConnected && ssid.length() > 0 && failedAttempts < 2 && getConnectedClients() == 0) {
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
