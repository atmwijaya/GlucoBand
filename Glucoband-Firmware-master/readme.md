# Glucosense ESP32 Firmware

## Project Overview
- ESP32 firmware for glucose and heart-rate monitoring.
- Uses MAX30102 for heart-rate signal and AS726X for spectral data.
- Shows device status and readings on a 128x64 I2C OLED.
- Provides WiFi setup through Access Point mode and a local web page.
- Sends data to a remote API and requests glucose prediction from an XGBoost endpoint.

## Main Features
- FreeRTOS multi-task architecture for sensor reading, display update, and network handling.
- Startup animation and finger placement screen on OLED.
- WiFi credential storage using non-volatile preferences.
- Auto-retry WiFi reconnect with credential reset after repeated failures.
- Long-press reset button support to clear saved WiFi credentials.
- HTTPS requests for:
	- Glucose prediction: `POST /api/xgb/predict`
	- Sensor update: `PATCH /api/sensors/update`

## Hardware Requirements
- ESP32 development board.
- MAX30102 sensor module.
- AS726X spectral sensor module.
- OLED display SSD1306 128x64 (I2C, address `0x3C`).
- Push button on GPIO 13 for WiFi reset.
- Stable 3.3V power supply for all modules.

## Pin Configuration
- I2C bus `Wire` (OLED + AS726X):
	- SDA: GPIO 22
	- SCL: GPIO 21
- I2C bus `Wire1` (MAX30102):
	- SDA: GPIO 26
	- SCL: GPIO 25
- Reset button:
	- GPIO 13 with `INPUT_PULLUP`
	- Active LOW

## Software Dependencies
- Arduino framework for ESP32.
- Required libraries:
	- `WiFi` (ESP32 core)
	- `WebServer` (ESP32 core)
	- `Preferences` (ESP32 core)
	- `HTTPClient` (ESP32 core)
	- `WiFiClientSecure` (ESP32 core)
	- `Wire`
	- `Adafruit GFX`
	- `Adafruit SSD1306`
	- `SparkFun MAX3010x` (for MAX30102)
	- `heartRate` helper used by MAX3010x examples
	- `SparkFun AS726X`

## Project Structure
- `glucosense.ino`
	- Main firmware entry.
	- Task creation and shared data handling.
- `WiFiConfig.h` and `WiFiConfig.cpp`
	- WiFi provisioning, AP web page, credential persistence, and API communication.
- `startup.h` and `startup.cpp`
	- OLED startup animation and finger prompt drawing.
- `readme.md`
	- Project documentation.

## Build And Upload
1. Open the project folder in Arduino IDE or PlatformIO.
2. Select an ESP32 board profile that matches your hardware.
3. Install all required libraries listed above.
4. Connect the board through USB.
5. Compile the sketch.
6. Upload firmware to the ESP32.
7. Open Serial Monitor at `115200` baud.

## First Time WiFi Setup
1. Power on the device.
2. Connect your phone or laptop to WiFi AP `Glucosense-Setup`.
3. Open browser and go to the AP IP shown on OLED or default ESP32 AP gateway.
4. Select your WiFi SSID from scanned networks.
5. Enter WiFi password.
6. Save and wait for automatic restart.
7. Confirm status changes to connected on Serial Monitor and OLED.

## Runtime Behavior
- OLED shows:
	- Device status at startup.
	- WiFi status label and value.
	- BPM and glucose when finger is detected.
- MAX30102 task:
	- Samples IR signal.
	- Detects beats and updates BPM.
- AS726X task:
	- Reads spectral channels `R,S,T,U,V,W` when finger is present.
- WiFi task:
	- Calls prediction endpoint with spectral values.
	- Updates glucose value when changed.
	- Sends combined glucose and heart-rate data to backend.

## WiFi Recovery And Reset
- Auto reconnect tries periodically if disconnected.
- After multiple failed connection attempts, saved credentials are cleared.
- Manual reset:
	- Hold button on GPIO 13 for 5 seconds.
	- Device clears WiFi credentials and restarts.

## API Notes
- Base API endpoint is fixed to `https://api.glucosense.id` in firmware.
- TLS certificate validation is bypassed with `client.setInsecure()`.
- Update this behavior for production-grade security if needed.

## Troubleshooting
- If OLED is blank:
	- Check power and I2C address `0x3C`.
	- Verify SDA and SCL wiring.
- If WiFi setup page does not load:
	- Confirm AP `Glucosense-Setup` is visible.
	- Reboot device and retry scan.
- If BPM stays low or unavailable:
	- Ensure finger placement is stable on MAX30102.
	- Improve ambient light shielding.
- If glucose prediction fails:
	- Verify internet connectivity.
	- Check API endpoint availability.
	- Inspect Serial Monitor for HTTP error codes.

## Development Notes
- Shared data between tasks is protected with FreeRTOS mutexes.
- Two I2C buses are used to reduce sensor bus contention.
- Data is only sent when new measurable changes are detected.
