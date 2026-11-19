#ifndef EEPROM_STORAGE_H
#define EEPROM_STORAGE_H

#include <Arduino.h>
#include <Wire.h>

#define EEPROM_I2C_ADDR 0x50
#define EEPROM_PAGE_SIZE 128
#define EEPROM_TOTAL_BYTES 65536
#define EEPROM_MAGIC 0x474C5543 // "GLUC" in hex
#define EEPROM_HEADER_OFFSET 0x0000
#define EEPROM_DATA_OFFSET 128
#define EEPROM_MAX_RECORDS 2700

// Struktur data satu rekaman pengukuran offline (tepat 24 byte)
struct __attribute__((packed)) OfflineRecord {
  uint32_t timestampMillis; // Nilai millis() saat pengukuran terjadi (4 byte)
  uint16_t bpm;             // Detak jantung rata-rata (2 byte)
  int16_t  tempScaled;      // Suhu tubuh * 100, misal 36.65 C -> 3665 (2 byte)
  uint16_t nir_R;           // Spektral AS726X channel R * 10 (2 byte)
  uint16_t nir_S;           // Spektral AS726X channel S * 10 (2 byte)
  uint16_t nir_T;           // Spektral AS726X channel T * 10 (2 byte)
  uint16_t nir_U;           // Spektral AS726X channel U * 10 (2 byte)
  uint16_t nir_V;           // Spektral AS726X channel V * 10 (2 byte)
  uint16_t nir_W;           // Spektral AS726X channel W * 10 (2 byte)
  uint16_t glucoseEst;      // Hasil estimasi glukosa lokal * 10 (2 byte)
  uint16_t checksum;        // Checksum validasi integritas data (2 byte)
};

// Struktur header ring buffer FIFO (tepat 128 byte = 1 halaman pertama EEPROM)
struct __attribute__((packed)) FIFOHeader {
  uint32_t magic;           // 0x474C5543
  uint16_t head;            // Indeks tulis berikutnya
  uint16_t tail;            // Indeks baca antrean terlama
  uint16_t count;           // Total data belum terkirim
  uint16_t maxCapacity;     // Kapasitas maksimum (2700)
  uint8_t  reserved[116];   // Padding agar pas 128 byte
};

class EEPROMStorage {
public:
  EEPROMStorage(uint8_t i2cAddr = EEPROM_I2C_ADDR);

  bool begin(TwoWire &wire = Wire);
  bool isAvailable() const { return _available; }

  // Operasi Antrean FIFO
  bool enqueue(const OfflineRecord &record);
  bool peek(OfflineRecord &record);
  bool dequeue();
  uint16_t getCount() const { return _header.count; }
  void clear();

  // Helper kalkulasi checksum
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

#endif // EEPROM_STORAGE_H
