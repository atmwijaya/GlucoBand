import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { FaSave, FaExclamationCircle } from 'react-icons/fa';

export default function Settings() {
  const [emergencyContact, setEmergencyContact] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    fetchEmergencyContact();
  }, []);

  const fetchEmergencyContact = async () => {
    try {
      // It uses public access or jwt token? The GET doesn't require JWT based on our backend code.
      const response = await axios.get('http://localhost:5000/api/settings/emergency_contact');
      setEmergencyContact(response.data.setting_value);
    } catch (err) {
      if (err.response && err.response.status === 404) {
        setEmergencyContact(''); // not set yet
      } else {
        setError('Gagal memuat kontak darurat');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    setMessage('');
    setError('');

    try {
      const token = sessionStorage.getItem('token');
      await axios.put('http://localhost:5000/api/settings/emergency_contact', 
        { setting_value: emergencyContact },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      setMessage('Kontak darurat berhasil disimpan');
    } catch (err) {
      setError(err.response?.data?.msg || 'Gagal menyimpan kontak darurat');
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="p-6 bg-slate-50 min-h-screen">
      <h1 className="text-2xl font-bold text-slate-800 mb-6">Pengaturan Sistem</h1>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-slate-100 max-w-2xl">
        <h2 className="text-lg font-semibold text-slate-700 mb-4 border-b pb-2">Kontak Darurat</h2>
        
        {message && (
          <div className="mb-4 p-3 bg-green-50 text-green-600 rounded-lg text-sm border border-green-100 flex items-center gap-2">
            <FaExclamationCircle /> {message}
          </div>
        )}
        
        {error && (
          <div className="mb-4 p-3 bg-red-50 text-red-600 rounded-lg text-sm border border-red-100 flex items-center gap-2">
            <FaExclamationCircle /> {error}
          </div>
        )}

        <form onSubmit={handleSave}>
          <div className="mb-4">
            <label className="block text-sm font-medium text-slate-600 mb-2">
              Nomor Telepon Darurat (Tenaga Medis)
            </label>
            <p className="text-xs text-slate-500 mb-3">
              Nomor ini akan dihubungi oleh pasien saat menekan tombol darurat di aplikasi GlucoBand.
            </p>
            <input
              type="text"
              value={emergencyContact}
              onChange={(e) => setEmergencyContact(e.target.value)}
              placeholder="Contoh: 119 atau 08123456789"
              disabled={isLoading}
              className="w-full px-4 py-2 border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/20 focus:border-primaryBlue transition-all"
              required
            />
          </div>

          <div className="flex justify-end">
            <button
              type="submit"
              disabled={isSaving || isLoading}
              className="px-6 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-700 transition flex items-center gap-2 disabled:opacity-50"
            >
              <FaSave />
              {isSaving ? 'Menyimpan...' : 'Simpan'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
