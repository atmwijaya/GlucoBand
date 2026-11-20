#ifndef WIFICONFIG_H
#define WIFICONFIG_H

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ESPmDNS.h>
#include <DNSServer.h>
#include "esp_wifi.h"
#include "EEPROMStorage.h"

class WiFiConfig {
public:
  WiFiConfig();
  void begin();
  void handle();
  bool isConnected();
  bool isAPMode();
  int getConnectedClients();
  String getSSID();
  String getIP();
  String getAPIP();
  String getStatusLabel();
  String getStatusValue();
  bool predictGlucose(float r, float s, float t, float u, float v, float w, float &outGlucose);
  bool sendData(int id, int bpm, float glucose);
  bool syncOfflineMeasurements(EEPROMStorage &storage, int patientId = 1);
  void checkResetButton();
  void clearCredentials();
  void disconnectRouter();
  bool isPlugged();
  float getBatteryVoltage();
  int getBatteryPercentage();
  void setPowerState(bool plugged, float voltage = 4.2f);
  void readBatteryHardware();
  
private:
  WebServer server;
  DNSServer dnsServer;
  Preferences preferences;
  String ssid;
  String password;
  String apiEndpoint;
  bool wifiConnected;
  String connectionStatus;
  int failedAttempts;
  unsigned long lastConnectionAttempt;
  unsigned long resetButtonPressed;
  bool resetButtonState;
  bool apModeActive;
  bool isPluggedIn;
  float batteryVoltage;
  int batteryPercent;
  String powerSource;
  void handleApiBattery();
  
  void setupRoutes();
  void startAPMode();
  void handleRoot();
  void handleScan();
  void handleSave();
  void handleApiStatus();
  void handleApiInit();
  void handleApiSensors();
  void handleApiSave();
  void handleApiReset();
  void handleApiDisconnect();
  void sendCorsHeader();
  void loadCredentials();
  void saveCredentials();
  bool connectToWiFi();
};

#endif
