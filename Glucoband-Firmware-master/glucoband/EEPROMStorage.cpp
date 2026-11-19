#include "EEPROMStorage.h"

EEPROMStorage::EEPROMStorage(uint8_t i2cAddr) 
  : _i2cAddr(i2cAddr), _wire(&Wire), _available(false) {
  memset(&_header, 0, sizeof(FIFOHeader));
}

bool EEPROMStorage::begin(TwoWire &wire) {
  _wire = &wire;

  // Tes komunikasi I2C dengan AT24C512
  _wire->beginTransmission(_i2cAddr);
  if (_wire->endTransmission() != 0) {
    Serial.println("[EEPROM] AT24C512 tidak terdeteksi pada bus I2C (0x50).");
    _available = false;
    return false;
  }

  _available = true;
  Serial.println("[EEPROM] AT24C512 64KB terdeteksi aktif.");

  // Baca header FIFO di halaman 0 (0x0000)
  if (!readHeader() || _header.magic != EEPROM_MAGIC) {
    Serial.println("[EEPROM] Format FIFO baru terdeteksi. Melakukan inisialisasi header...");
    _header.magic = EEPROM_MAGIC;
    _header.head = 0;
    _header.tail = 0;
    _header.count = 0;
    _header.maxCapacity = EEPROM_MAX_RECORDS;
    memset(_header.reserved, 0, sizeof(_header.reserved));

    if (!saveHeader()) {
      Serial.println("[EEPROM] Gagal menyimpan inisialisasi header.");
      return false;
    }
  }

  Serial.printf("[EEPROM] Buffer FIFO Siap: %u data tersimpan dari kapasitas %u.\n", 
                _header.count, _header.maxCapacity);
  return true;
}

uint16_t EEPROMStorage::calculateChecksum(const OfflineRecord &rec) {
  uint16_t sum = 0xAA55;
  const uint8_t *ptr = reinterpret_cast<const uint8_t*>(&rec);
  // Hitung sampai sebelum field checksum (22 byte)
  size_t len = sizeof(OfflineRecord) - sizeof(uint16_t);
  for (size_t i = 0; i < len; i++) {
    sum = (sum << 1) ^ ptr[i];
  }
  return sum;
}

bool EEPROMStorage::readHeader() {
  return readBytes(EEPROM_HEADER_OFFSET, reinterpret_cast<uint8_t*>(&_header), sizeof(FIFOHeader));
}

bool EEPROMStorage::saveHeader() {
  return writeBytes(EEPROM_HEADER_OFFSET, reinterpret_cast<const uint8_t*>(&_header), sizeof(FIFOHeader));
}

bool EEPROMStorage::enqueue(const OfflineRecord &record) {
  if (!_available) return false;

  OfflineRecord recCopy = record;
  recCopy.checksum = calculateChecksum(recCopy);

  // Jika memori penuh, geser tail (overwrite data paling usang secara aman)
  if (_header.count >= _header.maxCapacity) {
    _header.tail = (_header.tail + 1) % _header.maxCapacity;
  } else {
    _header.count++;
  }

  uint16_t writeAddr = EEPROM_DATA_OFFSET + (_header.head * sizeof(OfflineRecord));
  if (!writeBytes(writeAddr, reinterpret_cast<const uint8_t*>(&recCopy), sizeof(OfflineRecord))) {
    Serial.println("[EEPROM] Gagal menulis rekaman data ke slot memori.");
    return false;
  }

  _header.head = (_header.head + 1) % _header.maxCapacity;
  saveHeader();

  Serial.printf("[EEPROM] Enqueue sukses: slot %u. Total antrean offline: %u\n", 
                _header.head, _header.count);
  return true;
}

bool EEPROMStorage::peek(OfflineRecord &record) {
  if (!_available || _header.count == 0) return false;

  uint16_t readAddr = EEPROM_DATA_OFFSET + (_header.tail * sizeof(OfflineRecord));
  if (!readBytes(readAddr, reinterpret_cast<uint8_t*>(&record), sizeof(OfflineRecord))) {
    return false;
  }

  // Verifikasi checksum
  if (record.checksum != calculateChecksum(record)) {
    Serial.printf("[EEPROM] Peringatan: Checksum corrupt pada slot tail %u!\n", _header.tail);
    return false;
  }

  return true;
}

bool EEPROMStorage::dequeue() {
  if (!_available || _header.count == 0) return false;

  _header.tail = (_header.tail + 1) % _header.maxCapacity;
  _header.count--;
  saveHeader();

  Serial.printf("[EEPROM] Dequeue sukses. Sisa antrean offline: %u\n", _header.count);
  return true;
}

void EEPROMStorage::clear() {
  if (!_available) return;
  _header.head = 0;
  _header.tail = 0;
  _header.count = 0;
  saveHeader();
  Serial.println("[EEPROM] Antrean FIFO dikosongkan.");
}

bool EEPROMStorage::writeBytes(uint16_t memAddress, const uint8_t *data, size_t length) {
  if (!_available) return false;

  size_t bytesWritten = 0;
  while (bytesWritten < length) {
    uint16_t currentAddr = memAddress + bytesWritten;
    // Hitung sisa kapasitas pada halaman EEPROM aktif (page boundary 128 byte)
    size_t pageOffset = currentAddr % EEPROM_PAGE_SIZE;
    size_t chunk = EEPROM_PAGE_SIZE - pageOffset;
    if (chunk > (length - bytesWritten)) {
      chunk = length - bytesWritten;
    }
    // Batasi transmisi Wire maksimal 30 byte per burst agar tidak overflow I2C RX/TX buffer
    if (chunk > 28) chunk = 28;

    _wire->beginTransmission(_i2cAddr);
    _wire->write((uint8_t)((currentAddr >> 8) & 0xFF)); // MSB
    _wire->write((uint8_t)(currentAddr & 0xFF));        // LSB

    for (size_t i = 0; i < chunk; i++) {
      _wire->write(data[bytesWritten + i]);
    }

    if (_wire->endTransmission() != 0) {
      return false;
    }

    // Waktu internal write cycle EEPROM AT24C512 (maks 5ms)
    delay(5);
    bytesWritten += chunk;
  }

  return true;
}

bool EEPROMStorage::readBytes(uint16_t memAddress, uint8_t *data, size_t length) {
  if (!_available) return false;

  size_t bytesRead = 0;
  while (bytesRead < length) {
    size_t chunk = length - bytesRead;
    if (chunk > 28) chunk = 28; // Batas Wire read buffer

    uint16_t currentAddr = memAddress + bytesRead;

    _wire->beginTransmission(_i2cAddr);
    _wire->write((uint8_t)((currentAddr >> 8) & 0xFF)); // MSB
    _wire->write((uint8_t)(currentAddr & 0xFF));        // LSB
    if (_wire->endTransmission(false) != 0) { // Repeated start
      return false;
    }

    uint8_t received = _wire->requestFrom(_i2cAddr, (uint8_t)chunk);
    if (received != chunk) {
      return false;
    }

    for (size_t i = 0; i < chunk; i++) {
      if (_wire->available()) {
        data[bytesRead + i] = _wire->read();
      }
    }

    bytesRead += chunk;
  }

  return true;
}
