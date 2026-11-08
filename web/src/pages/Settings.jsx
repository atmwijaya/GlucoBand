import React, { useState, useEffect } from 'react';
import apiClient from '../api/axios';
import {
  FaSave, FaExclamationCircle, FaCheckCircle, FaMicrochip,
  FaDesktop, FaInfoCircle, FaExternalLinkAlt, FaTools
} from 'react-icons/fa';
import { Link } from 'react-router-dom';

export default function Settings() {
  // 1. Pengaturan Kontak Darurat (Server Database)
  const [emergencyContact, setEmergencyContact] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  // 2. Pengaturan Mode Pengembang Per-Device (Tersimpan Lokal di Browser Perangkat Ini)
  const [devModeEnabled, setDevModeEnabled] = useState(
    () => localStorage.getItem('glucoband_dev_mode_enabled') === 'true'
  );
  const [defaultEspIp, setDefaultEspIp] = useState(
    () => localStorage.getItem('glucoband_esp_ip') || '192.168.4.1'
  );
  const [devMessage, setDevMessage] = useState('');

  useEffect(() => {
    fetchEmergencyContact();
  }, []);

  const fetchEmergencyContact = async () => {
    try {
      const response = await apiClient.get('/settings/emergency_contact');
      setEmergencyContact(response.data.setting_value || '');
    } catch (err) {
      if (err.response && err.response.status === 404) {
        setEmergencyContact('');
      } else {
        setError('Gagal memuat kontak darurat');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSaveContact = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    setMessage('');
    setError('');

    try {
      await apiClient.put('/settings/emergency_contact', { setting_value: emergencyContact });
      setMessage('Kontak darurat berhasil disimpan ke server');
      setTimeout(() => setMessage(''), 4000);
    } catch (err) {
      setError(err.response?.data?.msg || 'Gagal menyimpan kontak darurat');
    } finally {
      setIsSaving(false);
    }
  };

  // Toggle Mode Development (Per-Device)
  const handleToggleDevMode = (newVal) => {
    setDevModeEnabled(newVal);
    localStorage.setItem('glucoband_dev_mode_enabled', newVal ? 'true' : 'false');

    // Jika dimatikan, otomatis reset mode koneksi monitoring ke 'online'
    if (!newVal) {
      localStorage.setItem('glucoband_conn_mode', 'online');
    }

    setDevMessage(
      newVal
        ? 'Mode Development AKTIF pada perangkat ini. Menu Monitoring kini membuka opsi Direct IP ESP32.'
        : 'Mode Development DINONAKTIFKAN. Menu Monitoring kini hanya berjalan pada Mode Normal/Online Cloud.'
    );
    setTimeout(() => setDevMessage(''), 4500);
  };

  const handleSaveEspIp = (e) => {
    e.preventDefault();
    const cleanIp = defaultEspIp.trim() || '192.168.4.1';
    setDefaultEspIp(cleanIp);
    localStorage.setItem('glucoband_esp_ip', cleanIp);
    setDevMessage(`Alamat IP ESP32 default diperbarui ke ${cleanIp}`);
    setTimeout(() => setDevMessage(''), 3500);
  };

  return (
    <div className="p-6 bg-slate-50 min-h-screen max-w-4xl mx-auto space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-800">Pengaturan Sistem & Perangkat</h1>
        <p className="text-sm text-slate-500 mt-1">
          Kelola preferensi sistem klinis server dan konfigurasi hardware khusus perangkat ini.
        </p>
      </div>

      {/* KARTU 1: MODE PENGEMBANG / DIRECT IP HARDWARE (PER-DEVICE) */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 pb-4 mb-4">
          <div className="flex items-center gap-3">
            <div className={`p-2.5 rounded-xl ${devModeEnabled ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-500'}`}>
              <FaMicrochip size={20} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-lg font-bold text-slate-800">Mode Pengembang</h2>
                <span className="px-2 py-0.5 text-[11px] font-bold bg-amber-100 text-amber-800 rounded-full flex items-center gap-1">
                  <FaDesktop size={10} /> Khusus Perangkat Ini
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-0.5">
                Aktifkan mode pengembang untuk melakukan pemeliharaan sistem.
              </p>
            </div>
          </div>

          {/* Toggle Switch On/Off */}
          <div className="flex items-center gap-3">
            <span className={`text-xs font-bold ${devModeEnabled ? 'text-indigo-600' : 'text-slate-400'}`}>
              {devModeEnabled ? 'AKTIF' : 'NONAKTIF'}
            </span>
            <button
              type="button"
              onClick={() => handleToggleDevMode(!devModeEnabled)}
              className={`relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                devModeEnabled ? 'bg-indigo-600' : 'bg-slate-300'
              }`}
            >
              <span
                className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out ${
                  devModeEnabled ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
          </div>
        </div>

        {devMessage && (
          <div className="mb-4 p-2.5 bg-slate-100 border border-slate-200 text-slate-700 rounded-lg text-xs flex items-center gap-2">
            <FaCheckCircle className="text-emerald-600 flex-shrink-0" size={13} />
            <span>{devMessage}</span>
          </div>
        )}

        {devModeEnabled && (
          <div className="pt-2">
            <form onSubmit={handleSaveEspIp} className="flex flex-wrap items-center gap-2.5">
              <label className="text-xs font-semibold text-slate-600 whitespace-nowrap">
                Default IP ESP32:
              </label>
              <input
                type="text"
                value={defaultEspIp}
                onChange={(e) => setDefaultEspIp(e.target.value)}
                placeholder="192.168.4.1"
                className="w-36 px-2.5 py-1 text-xs bg-slate-50 border border-slate-300 rounded-lg font-mono focus:outline-none focus:border-slate-500"
              />
              <button
                type="submit"
                className="px-3 py-1 bg-slate-800 hover:bg-slate-900 text-white text-xs font-medium rounded-lg transition"
              >
                Simpan IP
              </button>
            </form>
          </div>
        )}
      </div>

      {/* KARTU 2: KONTAK DARURAT PASIEN (SERVER DATABASE) */}
      <div className="bg-white p-6 rounded-2xl shadow-sm border border-slate-200">
        <h2 className="text-lg font-bold text-slate-800 mb-1 border-b border-slate-100 pb-3">
          Kontak Darurat Tenaga Medis
        </h2>
        <p className="text-xs text-slate-500 mb-4">
          Nomor ini tersimpan di server database pusat dan akan dihubungi oleh pasien saat menekan tombol SOS/darurat di aplikasi mobile GlucoBand.
        </p>

        {message && (
          <div className="mb-4 p-3 bg-green-50 text-green-700 rounded-xl text-xs border border-green-200 flex items-center gap-2">
            <FaCheckCircle className="text-green-600" /> {message}
          </div>
        )}

        {error && (
          <div className="mb-4 p-3 bg-red-50 text-red-700 rounded-xl text-xs border border-red-200 flex items-center gap-2">
            <FaExclamationCircle className="text-red-600" /> {error}
          </div>
        )}

        <form onSubmit={handleSaveContact}>
          <div className="mb-4">
            <label className="block text-xs font-bold text-slate-700 mb-1">
              Nomor Telepon / Hotline Darurat:
            </label>
            <input
              type="text"
              value={emergencyContact}
              onChange={(e) => setEmergencyContact(e.target.value)}
              placeholder="Contoh: 119 atau 08123456789"
              disabled={isLoading}
              className="w-full max-w-md px-3.5 py-2 text-sm border border-slate-300 rounded-xl focus:outline-none focus:ring-2 focus:ring-primaryBlue/20 focus:border-primaryBlue transition"
              required
            />
          </div>

          <button
            type="submit"
            disabled={isSaving || isLoading}
            className="px-5 py-2 bg-primaryBlue text-white text-xs font-bold rounded-xl hover:bg-blue-600 transition flex items-center gap-2 disabled:opacity-50 shadow-sm"
          >
            <FaSave />
            {isSaving ? 'Menyimpan...' : 'Simpan ke Server'}
          </button>
        </form>
      </div>
    </div>
  );
}
