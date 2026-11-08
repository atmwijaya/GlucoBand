#ifndef WIFICONFIG_H
#define WIFICONFIG_H

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ESPmDNS.h>

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
  void checkResetButton();
  void clearCredentials();
  
private:
  WebServer server;
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
  void sendCorsHeader();
  void loadCredentials();
  void saveCredentials();
  bool connectToWiFi();
};

#endif
