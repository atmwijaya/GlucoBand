import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import apiClient from '../api/axios'
import ReusableModal from '../components/common/modal'
import {
  onlyDigitsKeyDown,
  filterDigits,
  onlyDecimalsKeyDown,
  filterDecimals
} from '../utils/inputValidators'

export default function EditPasien() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState({
    name: '', email: '', age: '', gender: 'L', weight_kg: '', height_cm: '',
    blood_pressure_sys: '', blood_pressure_dia: '', diabetes_history: 0, smoking_history: 0,
    tenaga_medis_id: ''
  })
  const [errors, setErrors] = useState({})
  const [staffOptions, setStaffOptions] = useState([])
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [fetchLoading, setFetchLoading] = useState(true)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })

  useEffect(() => {
    Promise.all([
      apiClient.get(`/patients/${id}`),
      apiClient.get('/tenaga-medis').catch(() => ({ data: [] }))
    ])
      .then(([patientRes, staffRes]) => {
        const data = patientRes.data
        setForm({
          name: data.name || '',
          email: data.email || '',
          age: data.age !== null && data.age !== undefined ? String(data.age) : '',
          gender: data.gender || 'L',
          weight_kg: data.weight_kg !== null && data.weight_kg !== undefined ? String(data.weight_kg) : '',
          height_cm: data.height_cm !== null && data.height_cm !== undefined ? String(data.height_cm) : '',
          blood_pressure_sys: data.blood_pressure_sys !== null && data.blood_pressure_sys !== undefined ? String(data.blood_pressure_sys) : '',
          blood_pressure_dia: data.blood_pressure_dia !== null && data.blood_pressure_dia !== undefined ? String(data.blood_pressure_dia) : '',
          diabetes_history: data.diabetes_history || 0,
          smoking_history: data.smoking_history || 0,
          tenaga_medis_id: data.tenaga_medis_id || data.medical_staff_id || ''
        })
        setStaffOptions(staffRes.data || [])
      })
      .catch(() => setModal({ isOpen: true, title: 'Error', message: 'Gagal memuat data pasien.', type: 'error' }))
      .finally(() => setFetchLoading(false))
  }, [id])

  const handleChange = (e) => {
    const { name, value, type: inputType, checked } = e.target
    setForm(prev => ({ ...prev, [name]: inputType === 'checkbox' ? (checked ? 1 : 0) : value }))
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }))
    }
  }

  const handleNumericChange = (fieldName, rawValue, isDecimal = false) => {
    const cleanValue = isDecimal ? filterDecimals(rawValue) : filterDigits(rawValue)
    setForm(prev => ({ ...prev, [fieldName]: cleanValue }))
    if (errors[fieldName]) {
      setErrors(prev => ({ ...prev, [fieldName]: '' }))
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    const newErrors = {}

    if (!form.name.trim()) newErrors.name = 'Nama lengkap wajib diisi.'
    if (!form.email.trim()) {
      newErrors.email = 'Email wajib diisi.'
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
      newErrors.email = 'Format email tidak valid.'
    }
    if (!form.age || !String(form.age).trim()) {
      newErrors.age = 'Usia wajib diisi.'
    }

    if (password) {
      if (password.length < 6) {
        newErrors.password = 'Password minimal 6 karakter.'
      }
      if (password !== confirmPassword) {
        newErrors.confirmPassword = 'Password dan konfirmasi tidak cocok.'
      }
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }

    setErrors({})
    setLoading(true)
    try {
      const payload = { ...form }
      if (password) {
        payload.password = password
      }
      await apiClient.put(`/patients/${id}`, payload)
      setModal({ isOpen: true, title: 'Berhasil', message: 'Data pasien berhasil diperbarui.', type: 'success' })
    } catch {
      setModal({ isOpen: true, title: 'Gagal', message: 'Terjadi kesalahan saat memperbarui data.', type: 'error' })
    } finally {
      setLoading(false)
    }
  }

  if (fetchLoading) return <div className="text-center py-12 text-gray-400">Memuat data...</div>

  return (
    <div className="max-w-2xl mx-auto">
      <h1 className="text-2xl font-bold text-darkNavy mb-6">Edit Data Pasien</h1>
      <form onSubmit={handleSubmit} noValidate className="bg-white rounded-xl shadow-sm p-6 space-y-5">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {/* Nama */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Nama Lengkap <span className="text-red-500">*</span>
            </label>
            <input
              name="name"
              value={form.name}
              onChange={handleChange}
              placeholder="Contoh: Anisa Anastasya"
              className={`w-full px-4 py-2.5 border rounded-lg focus:outline-none transition ${
                errors.name
                  ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                  : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
              }`}
            />
            {errors.name && (
              <p className="text-xs text-red-500 mt-1 font-medium">{errors.name}</p>
            )}
          </div>

          {/* Email */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Email <span className="text-red-500">*</span>
            </label>
            <input
              type="email"
              name="email"
              value={form.email}
              onChange={handleChange}
              placeholder="pasien@gmail.com"
              className={`w-full px-4 py-2.5 border rounded-lg focus:outline-none transition ${
                errors.email
                  ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                  : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
              }`}
            />
            {errors.email && (
              <p className="text-xs text-red-500 mt-1 font-medium">{errors.email}</p>
            )}
          </div>

          {/* Password Baru */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Password Baru (kosongkan jika tidak diubah)
            </label>
            <input
              type="password"
              value={password}
              onChange={e => {
                setPassword(e.target.value)
                if (errors.password) setErrors(prev => ({ ...prev, password: '' }))
              }}
              placeholder="Minimal 6 karakter"
              className={`w-full px-4 py-2.5 border rounded-lg focus:outline-none transition ${
                errors.password
                  ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                  : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
              }`}
            />
            {errors.password && (
              <p className="text-xs text-red-500 mt-1 font-medium">{errors.password}</p>
            )}
          </div>

          {/* Konfirmasi Password */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Konfirmasi Password
            </label>
            <input
              type="password"
              value={confirmPassword}
              onChange={e => {
                setConfirmPassword(e.target.value)
                if (errors.confirmPassword) setErrors(prev => ({ ...prev, confirmPassword: '' }))
              }}
              placeholder="Ketik ulang password baru"
              className={`w-full px-4 py-2.5 border rounded-lg focus:outline-none transition ${
                errors.confirmPassword
                  ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                  : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
              }`}
            />
            {errors.confirmPassword && (
              <p className="text-xs text-red-500 mt-1 font-medium">{errors.confirmPassword}</p>
            )}
          </div>

          {/* Usia (Hanya Angka) */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Usia (Tahun) <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              inputMode="numeric"
              name="age"
              value={form.age}
              onKeyDown={onlyDigitsKeyDown}
              onChange={e => handleNumericChange('age', e.target.value, false)}
              placeholder="Contoh: 25"
              className={`w-full px-4 py-2.5 border rounded-lg focus:outline-none transition ${
                errors.age
                  ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                  : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
              }`}
            />
            {errors.age && (
              <p className="text-xs text-red-500 mt-1 font-medium">{errors.age}</p>
            )}
          </div>

          {/* Jenis Kelamin */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">Jenis Kelamin</label>
            <select
              name="gender"
              value={form.gender}
              onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 bg-white"
            >
              <option value="L">Laki-laki</option>
              <option value="P">Perempuan</option>
            </select>
          </div>

          {/* Berat Badan (Hanya Angka / Desimal) */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">Berat Badan (kg)</label>
            <input
              type="text"
              inputMode="decimal"
              name="weight_kg"
              value={form.weight_kg}
              onKeyDown={e => onlyDecimalsKeyDown(e, form.weight_kg)}
              onChange={e => handleNumericChange('weight_kg', e.target.value, true)}
              placeholder="Contoh: 65.5"
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
            />
          </div>

          {/* Tinggi Badan (Hanya Angka / Desimal) */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">Tinggi Badan (cm)</label>
            <input
              type="text"
              inputMode="decimal"
              name="height_cm"
              value={form.height_cm}
              onKeyDown={e => onlyDecimalsKeyDown(e, form.height_cm)}
              onChange={e => handleNumericChange('height_cm', e.target.value, true)}
              placeholder="Contoh: 170.0"
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
            />
          </div>

          {/* Sistolik (Hanya Angka) */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">Tekanan Darah Sistolik (mmHg)</label>
            <input
              type="text"
              inputMode="numeric"
              name="blood_pressure_sys"
              value={form.blood_pressure_sys}
              onKeyDown={onlyDigitsKeyDown}
              onChange={e => handleNumericChange('blood_pressure_sys', e.target.value, false)}
              placeholder="Contoh: 120"
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
            />
          </div>

          {/* Diastolik (Hanya Angka) */}
          <div>
            <label className="block text-sm font-medium mb-1.5 text-slate-700">Tekanan Darah Diastolik (mmHg)</label>
            <input
              type="text"
              inputMode="numeric"
              name="blood_pressure_dia"
              value={form.blood_pressure_dia}
              onKeyDown={onlyDigitsKeyDown}
              onChange={e => handleNumericChange('blood_pressure_dia', e.target.value, false)}
              placeholder="Contoh: 80"
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
            />
          </div>

          {/* Tenaga Medis Penanggung Jawab */}
          <div className="md:col-span-2">
            <label className="block text-sm font-medium mb-1.5 text-slate-700">
              Tenaga Medis Penanggung Jawab
            </label>
            <select
              name="tenaga_medis_id"
              value={form.tenaga_medis_id || ''}
              onChange={handleChange}
              className="w-full px-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 bg-white"
            >
              <option value="">-- Belum Ditentukan (Gunakan Nomor Darurat Umum 119) --</option>
              {staffOptions.map(s => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.specialization}) - Telp: {s.phone_number}
                </option>
              ))}
            </select>
            <p className="text-xs text-slate-400 mt-1">
              Nomor kontak tenaga medis yang dipilih akan menjadi nomor darurat dan WhatsApp yang muncul pada aplikasi mobile pasien ini.
            </p>
          </div>
        </div>

        {/* Checkbox */}
        <div className="flex gap-6">
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              name="diabetes_history"
              checked={form.diabetes_history === 1}
              onChange={handleChange}
              className="w-4 h-4 text-primaryBlue rounded"
            />
            <span className="text-sm text-slate-700">Riwayat Diabetes</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              name="smoking_history"
              checked={form.smoking_history === 1}
              onChange={handleChange}
              className="w-4 h-4 text-primaryBlue rounded"
            />
            <span className="text-sm text-slate-700">Riwayat Merokok</span>
          </label>
        </div>

        {/* Tombol */}
        <div className="flex gap-3 pt-4 border-t border-slate-100">
          <button
            type="button"
            onClick={() => navigate(-1)}
            className="px-6 py-2.5 border border-lineGray rounded-lg text-textSecondary hover:bg-gray-50 transition"
          >
            Batal
          </button>
          <button
            type="submit"
            disabled={loading}
            className="px-6 py-2.5 bg-primaryBlue text-white font-medium rounded-lg hover:bg-blue-600 transition disabled:opacity-50 shadow-sm"
          >
            {loading ? 'Menyimpan...' : 'Simpan Perubahan'}
          </button>
        </div>
      </form>
      <ReusableModal
        isOpen={modal.isOpen}
        onClose={() => {
          setModal({ ...modal, isOpen: false })
          if (modal.type === 'success') navigate('/admin/data-pasien')
        }}
        title={modal.title}
        message={modal.message}
        type={modal.type}
      />
    </div>
  )
}
