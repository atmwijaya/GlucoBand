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

  // 1. Inisialisasi WiFi & Web Server PALING AWAL
  // Agar sinyal WiFi AP (GlucoBand-Setup) langsung memancar segera setelah board menyala,
  // tanpa menunggu atau terhalang oleh proses deteksi sensor I2C.
  wifiConfig.begin();

  // 2. Inisialisasi Jalur I2C
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
  // Tangani server HTTP & manajemen koneksi WiFi
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

// Read MAX30105
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

// Light control LED NIR AS726X
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

// Read MLX90614
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

// Read AS726X 5sec
void readAS726X() {
  if (!asOk) return;

  if (!fingerPresent) {
    spectralR = 0;
    spectralS = 0;
    spectralT = 0;
    spectralU = 0;
    spectralV = 0;
    spectralW = 0;
    return;
  }

  asSensor.takeMeasurements();

  spectralR = asSensor.getCalibratedR();
  spectralS = asSensor.getCalibratedS();
  spectralT = asSensor.getCalibratedT();
  spectralU = asSensor.getCalibratedU();
  spectralV = asSensor.getCalibratedV();
  spectralW = asSensor.getCalibratedW();
}

void printSerialData() {
  Serial.println("\n========== SENSOR DATA ==========");
  Serial.print("MAX30105 IR   : "); Serial.println(irValue);
  Serial.print("Finger Status : "); Serial.println(fingerPresent ? "TERDETEKSI" : "TIDAK ADA");

  if (fingerPresent) {
    Serial.print("BPM           : ");
    if (bpmAverage > 0) Serial.println(bpmAverage);
    else Serial.println("Menghitung...");

    Serial.print("Suhu Objek    : ");
    if (mlxOk && !isnan(objectTemp)) {
      Serial.print(objectTemp, 1);
      Serial.println(" C");
    } else {
      Serial.println("N/A");
    }

    if (asOk) {
      Serial.println("--- Spektrum NIR (R,S,T,U,V,W) ---");
      // Murni angka CSV sebaris tanpa embel-embel teks di depannya
      Serial.printf("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n", 
                    spectralR, spectralS, spectralT, 
                    spectralU, spectralV, spectralW);
    }
  } else {
    Serial.println("Sensor AS726X standby (menunggu jari).");
  }
  Serial.println("=================================");
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

    display.setTextSize(1);

    if (oledPage == 0) {
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
      display.setCursor(0, 0);
      display.print("R:"); display.print(spectralR, 1);
      display.setCursor(0, 11);
      display.print("S:"); display.print(spectralS, 1);
      display.setCursor(0, 22);
      display.print("T:"); display.print(spectralT, 1);
      display.setCursor(66, 0);
      display.print("U:"); display.print(spectralU, 1);
      display.setCursor(66, 11);
      display.print("V:"); display.print(spectralV, 1);
      display.setCursor(66, 22);
      display.print("W:"); display.print(spectralW, 1);
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