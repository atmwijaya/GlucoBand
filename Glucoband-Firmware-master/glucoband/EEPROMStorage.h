#ifndef EEPROM_STORAGE_H
#define EEPROM_STORAGE_H
#include <Arduino.h>
#include <Wire.h>
#define EEPROM_I2C_ADDR 0x50
#define EEPROM_PAGE_SIZE 128
#define EEPROM_TOTAL_BYTES 65536
#define EEPROM_MAGIC 0x474C5543
#define EEPROM_HEADER_OFFSET 0x0000
#define EEPROM_DATA_OFFSET 128
#define EEPROM_MAX_RECORDS 2700

struct __attribute__((packed)) OfflineRecord {
  uint32_t timestampMillis;
  uint16_t bpm;
  int16_t  tempScaled;
  uint16_t nir_R;
  uint16_t nir_S;
  uint16_t nir_T;
  uint16_t nir_U;
  uint16_t nir_V;
  uint16_t nir_W;
  uint16_t glucoseEst;
  uint16_t checksum;
};

struct __attribute__((packed)) FIFOHeader {
  uint32_t magic;
  uint16_t head;
  uint16_t tail;
  uint16_t count;
  uint16_t maxCapacity;
  uint8_t  reserved[116];
};

class EEPROMStorage {
public:
  EEPROMStorage(uint8_t i2cAddr = EEPROM_I2C_ADDR);
  bool begin(TwoWire &wire = Wire);
  bool isAvailable() const { return _available; }
  bool enqueue(const OfflineRecord &record);
  bool peek(OfflineRecord &record);
  bool dequeue();
  uint16_t getCount() const { return _header.count; }
  void clear();
  static uint16_t calculateChecksum(const OfflineRecord &rec);

private:
  uint8_t _i2cAddr;
  TwoWire *_wire;
  bool _available;
  FIFOHeader _header;
  bool readHeader();
  bool saveHeader();
  bool writeBytes(uint16_t memAddress, const uint8_t *data, size_t length);
  bool readBytes(uint16_t memAddress, uint8_t *data, size_t length);
};
#endif