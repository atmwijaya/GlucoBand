/**
 * Utilitas validasi dan sanitasi input agar hanya angka yang dapat diketik.
 */

// Mencegah pengetikan karakter selain angka (0-9) dan tombol navigasi/editing
export const onlyDigitsKeyDown = (e) => {
  const allowedKeys = [
    'Backspace', 'Tab', 'Enter', 'Delete', 'Escape',
    'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
    'Home', 'End'
  ];
  if (allowedKeys.includes(e.key)) return;
  if (e.ctrlKey || e.metaKey) return;
  if (!/^[0-9]$/.test(e.key)) {
    e.preventDefault();
  }
};

// Membersihkan string agar hanya menyisakan digit angka
export const filterDigits = (val) => {
  return String(val ?? '').replace(/\D/g, '');
};

// Mencegah pengetikan selain angka dan maksimal satu tanda titik desimal
export const onlyDecimalsKeyDown = (e, currentValue = '') => {
  const allowedKeys = [
    'Backspace', 'Tab', 'Enter', 'Delete', 'Escape',
    'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
    'Home', 'End'
  ];
  if (allowedKeys.includes(e.key)) return;
  if (e.ctrlKey || e.metaKey) return;

  // Izinkan tanda titik atau koma (desimal) jika belum ada di input
  if (e.key === '.' || e.key === ',') {
    if (String(currentValue).includes('.')) {
      e.preventDefault();
    }
    return;
  }

  if (!/^[0-9]$/.test(e.key)) {
    e.preventDefault();
  }
};

// Membersihkan string desimal (mengubah koma jadi titik, hapus titik ganda)
export const filterDecimals = (val) => {
  return String(val ?? '')
    .replace(/,/g, '.')
    .replace(/[^0-9.]/g, '')
    .replace(/(\..*?)\..*/g, '$1');
};

