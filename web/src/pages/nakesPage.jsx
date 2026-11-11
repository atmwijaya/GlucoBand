import { useState, useEffect } from 'react'
import {
  FaUserMd, FaPhoneAlt, FaPlus, FaTrash, FaEdit,
  FaSearch, FaUsers, FaUserCheck, FaWhatsapp
} from 'react-icons/fa'
import {
  getTenagaMedis, createTenagaMedis, updateTenagaMedis,
  deleteTenagaMedis
} from '../api/tenagaMedisApi'
import apiClient from '../api/axios'
import ReusableModal from '../components/common/modal'
import LoadingSkeleton from '../components/common/loading'
import { onlyDigitsKeyDown, filterDigits } from '../utils/inputValidators'

export default function NakesPage() {
  const [staffList, setStaffList] = useState([])
  const [allPatients, setAllPatients] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')

  // State untuk Modal Tambah / Edit Tenaga Medis
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [isEditing, setIsEditing] = useState(false)
  const [currentId, setCurrentId] = useState(null)
  const [formData, setFormData] = useState({
    name: '',
    phone_number: '',
    specialization: 'Dokter Umum',
    patient_ids: []
  })
  const [formErrors, setFormErrors] = useState({})

  // State untuk Modal Kelola Pasien Terlayani
  const [isAssignModalOpen, setIsAssignModalOpen] = useState(false)
  const [selectedStaff, setSelectedStaff] = useState(null)
  const [selectedPatientIds, setSelectedPatientIds] = useState([])

  // Modal Notifikasi / Konfirmasi
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const [staffToDelete, setStaffToDelete] = useState(null)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    setLoading(true)
    try {
      const [staffRes, patientRes] = await Promise.all([
        getTenagaMedis(),
        apiClient.get('/patients')
      ])
      setStaffList(staffRes.data || [])
      setAllPatients(patientRes.data || [])
    } catch (err) {
      console.error('Gagal mengambil data:', err)
      setModal({
        isOpen: true,
        title: 'Error',
        message: 'Gagal memuat data tenaga medis dan pasien.',
        type: 'error'
      })
    } finally {
      setLoading(false)
    }
  }

  const handleOpenAdd = () => {
    setIsEditing(false)
    setCurrentId(null)
    setFormData({
      name: '',
      phone_number: '',
      specialization: 'Dokter Umum',
      patient_ids: []
    })
    setFormErrors({})
    setIsFormOpen(true)
  }

  const handleOpenEdit = (staff) => {
    setIsEditing(true)
    setCurrentId(staff.id)
    setFormData({
      name: staff.name,
      phone_number: staff.phone_number,
      specialization: staff.specialization,
      patient_ids: (staff.patients || []).map(p => p.id)
    })
    setFormErrors({})
    setIsFormOpen(true)
  }

  const handleSaveForm = async (e) => {
    e.preventDefault()
    const errors = {}
    if (!formData.name.trim()) {
      errors.name = 'Nama tenaga medis wajib diisi.'
    }
    if (!formData.phone_number.trim()) {
      errors.phone_number = 'Nomor telepon wajib diisi.'
    } else if (formData.phone_number.length < 8) {
      errors.phone_number = 'Nomor telepon minimal 8 digit angka.'
    }

    if (Object.keys(errors).length > 0) {
      setFormErrors(errors)
      return
    }

    setFormErrors({})
    try {
      if (isEditing) {
        await updateTenagaMedis(currentId, formData)
        setModal({
          isOpen: true,
          title: 'Berhasil',
          message: 'Data tenaga medis berhasil diperbarui.',
          type: 'success'
        })
      } else {
        await createTenagaMedis(formData)
        setModal({
          isOpen: true,
          title: 'Berhasil',
          message: 'Tenaga medis baru berhasil ditambahkan.',
          type: 'success'
        })
      }
      setIsFormOpen(false)
      fetchData()
    } catch (err) {
      setModal({
        isOpen: true,
        title: 'Gagal',
        message: err.response?.data?.msg || 'Terjadi kesalahan saat menyimpan data.',
        type: 'error'
      })
    }
  }

  const handleOpenAssign = (staff) => {
    setSelectedStaff(staff)
    setSelectedPatientIds((staff.patients || []).map(p => p.id))
    setIsAssignModalOpen(true)
  }

  const handleTogglePatientAssign = (patientId) => {
    setSelectedPatientIds(prev =>
      prev.includes(patientId) ? prev.filter(id => id !== patientId) : [...prev, patientId]
    )
  }

  const handleSaveAssignment = async () => {
    if (!selectedStaff) return
    try {
      await updateTenagaMedis(selectedStaff.id, {
        patient_ids: selectedPatientIds
      })
      setModal({
        isOpen: true,
        title: 'Berhasil',
        message: `Daftar pasien untuk ${selectedStaff.name} berhasil diperbarui.`,
        type: 'success'
      })
      setIsAssignModalOpen(false)
      fetchData()
    } catch {
      setModal({
        isOpen: true,
        title: 'Gagal',
        message: 'Gagal memperbarui penugasan pasien.',
        type: 'error'
      })
    }
  }

  const handleDelete = async () => {
    if (!staffToDelete) return
    try {
      await deleteTenagaMedis(staffToDelete.id)
      setModal({
        isOpen: true,
        title: 'Berhasil',
        message: `Tenaga medis "${staffToDelete.name}" telah dihapus.`,
        type: 'success'
      })
      fetchData()
    } catch {
      setModal({
        isOpen: true,
        title: 'Gagal',
        message: 'Terjadi kesalahan saat menghapus data tenaga medis.',
        type: 'error'
      })
    } finally {
      setStaffToDelete(null)
    }
  }

  const filteredStaff = staffList.filter(s =>
    s.name?.toLowerCase().includes(search.toLowerCase()) ||
    s.specialization?.toLowerCase().includes(search.toLowerCase()) ||
    (s.patients || []).some(p => p.name?.toLowerCase().includes(search.toLowerCase()))
  )

  const totalPatientsServed = staffList.reduce((acc, s) => acc + (s.patient_count || 0), 0)

  return (
    <div className="space-y-6">
      {/* Header Bar */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-darkNavy">Daftar Tenaga Medis</h1>
          <p className="text-sm text-textSecondary mt-1">
            Kelola data dokter/tenaga medis dan penugasan pasien yang dilayaninya. Nomor tenaga medis otomatis menjadi nomor darurat pasien pada aplikasi mobile.
          </p>
        </div>
        <button
          onClick={handleOpenAdd}
          className="flex items-center gap-2 px-4 py-2.5 bg-primaryBlue text-white font-medium rounded-lg hover:bg-blue-600 transition shadow-sm"
        >
          <FaPlus /> Tambah Tenaga Medis
        </button>
      </div>

      {/* Stats Counter Bar */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-100 flex items-center gap-4">
          <div className="w-12 h-12 rounded-lg bg-blue-50 text-primaryBlue flex items-center justify-center text-xl">
            <FaUserMd />
          </div>
          <div>
            <p className="text-xs text-textSecondary font-medium">Total Tenaga Medis</p>
            <p className="text-xl font-bold text-darkNavy">{staffList.length}</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-100 flex items-center gap-4">
          <div className="w-12 h-12 rounded-lg bg-emerald-50 text-emerald-600 flex items-center justify-center text-xl">
            <FaUserCheck />
          </div>
          <div>
            <p className="text-xs text-textSecondary font-medium">Pasien Terlayani</p>
            <p className="text-xl font-bold text-darkNavy">{totalPatientsServed} Pasien</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-100 flex items-center gap-4">
          <div className="w-12 h-12 rounded-lg bg-purple-50 text-purple-600 flex items-center justify-center text-xl">
            <FaUsers />
          </div>
          <div>
            <p className="text-xs text-textSecondary font-medium">Total Pasien Terdaftar</p>
            <p className="text-xl font-bold text-darkNavy">{allPatients.length} Pasien</p>
          </div>
        </div>
      </div>

      {/* Main Content Box */}
      <div className="bg-white rounded-xl shadow-sm p-6">
        {/* Search Bar */}
        <div className="relative mb-6">
          <FaSearch className="absolute left-3.5 top-3.5 text-gray-400" />
          <input
            type="text"
            placeholder="Cari berdasarkan nama dokter, spesialisasi, atau nama pasien..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 text-sm"
          />
        </div>

        {loading ? (
          <LoadingSkeleton rows={4} />
        ) : filteredStaff.length === 0 ? (
          <div className="text-center py-12">
            <FaUserMd className="mx-auto text-4xl text-slate-300 mb-3" />
            <p className="text-slate-600 font-medium">Belum ada data tenaga medis.</p>
            <p className="text-xs text-slate-400 mt-1">Klik tombol "+ Tambah Tenaga Medis" di atas untuk menambahkan.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {filteredStaff.map((staff) => (
              <div
                key={staff.id}
                className="border border-slate-200 rounded-xl p-5 hover:border-primaryBlue/40 hover:shadow-md transition bg-gradient-to-br from-white to-slate-50/40 flex flex-col justify-between"
              >
                <div>
                  {/* Doctor Info Header */}
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div className="flex items-center gap-3">
                      <div className="w-11 h-11 rounded-full bg-primaryBlue/10 text-primaryBlue flex items-center justify-center text-xl font-bold flex-shrink-0">
                        <FaUserMd />
                      </div>
                      <div>
                        <h3 className="font-bold text-darkNavy text-base leading-tight">{staff.name}</h3>
                        <span className="text-xs text-slate-500 font-medium">{staff.specialization}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleOpenEdit(staff)}
                        title="Edit Data Tenaga Medis"
                        className="p-2 text-slate-500 hover:text-primaryBlue hover:bg-blue-50 rounded-lg transition"
                      >
                        <FaEdit />
                      </button>
                      <button
                        onClick={() => {
                          setStaffToDelete(staff)
                          setModal({
                            isOpen: true,
                            title: 'Konfirmasi Hapus',
                            message: `Apakah Anda yakin ingin menghapus tenaga medis "${staff.name}"? Pasien yang dilayani akan dialihkan ke status belum ditentukan.`,
                            type: 'confirm'
                          })
                        }}
                        title="Hapus Tenaga Medis"
                        className="p-2 text-slate-500 hover:text-red-600 hover:bg-red-50 rounded-lg transition"
                      >
                        <FaTrash />
                      </button>
                    </div>
                  </div>

                  {/* Phone / Emergency Number Badge */}
                  <div className="flex items-center gap-2 mb-4 bg-blue-50/70 border border-blue-100 rounded-lg px-3 py-2 text-sm">
                    <FaPhoneAlt className="text-primaryBlue text-xs" />
                    <span className="text-slate-600 font-medium text-xs">Nomor Darurat Mobile:</span>
                    <span className="font-bold text-darkNavy text-xs ml-auto tracking-wide">{staff.phone_number}</span>
                    <a
                      href={`https://wa.me/${staff.phone_number.replace(/^0/, '62')}`}
                      target="_blank"
                      rel="noreferrer"
                      title="Hubungi WhatsApp"
                      className="text-emerald-600 hover:text-emerald-700 ml-1 text-sm"
                    >
                      <FaWhatsapp />
                    </a>
                  </div>

                  {/* Patients Served Section */}
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-xs font-bold text-slate-700 uppercase tracking-wider">
                        Pasien yang Dilayani ({staff.patient_count || 0})
                      </span>
                      <button
                        onClick={() => handleOpenAssign(staff)}
                        className="text-xs text-primaryBlue hover:underline font-semibold"
                      >
                        + Atur Pasien
                      </button>
                    </div>

                    {(!staff.patients || staff.patients.length === 0) ? (
                      <p className="text-xs text-slate-400 italic py-2">
                        Belum ada pasien yang ditugaskan ke dokter ini.
                      </p>
                    ) : (
                      <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto pr-1">
                        {staff.patients.map(p => (
                          <span
                            key={p.id}
                            className="inline-flex items-center gap-1 text-xs bg-slate-100 text-slate-700 px-2.5 py-1 rounded-full font-medium border border-slate-200"
                          >
                            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                            {p.name}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </div>

                {/* Bottom Action */}
                <div className="pt-4 mt-4 border-t border-slate-100 flex justify-end">
                  <button
                    onClick={() => handleOpenAssign(staff)}
                    className="text-xs font-semibold px-3 py-1.5 bg-slate-100 hover:bg-primaryBlue hover:text-white text-slate-700 rounded-lg transition"
                  >
                    Kelola Penugasan Pasien
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal Tambah / Edit Tenaga Medis */}
      {isFormOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-md w-full p-6 animate-scale-up">
            <h2 className="text-xl font-bold text-darkNavy mb-4">
              {isEditing ? 'Edit Data Tenaga Medis' : 'Tambah Tenaga Medis Baru'}
            </h2>
            <form onSubmit={handleSaveForm} noValidate className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Nama Tenaga Medis (Lengkap dengan Gelar) <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  placeholder="Contoh: dr. H. Rahmat Hidayat, Sp.PD"
                  value={formData.name}
                  onChange={e => {
                    const val = e.target.value
                    setFormData(prev => ({ ...prev, name: val }))
                    if (val.trim()) setFormErrors(prev => ({ ...prev, name: '' }))
                  }}
                  className={`w-full px-3.5 py-2.5 border rounded-lg text-sm focus:outline-none transition ${
                    formErrors.name
                      ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                      : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
                  }`}
                />
                {formErrors.name && (
                  <p className="text-xs text-red-500 mt-1 font-medium">{formErrors.name}</p>
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Nomor Telepon <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  inputMode="numeric"
                  placeholder="Contoh: 081234567890"
                  value={formData.phone_number}
                  onKeyDown={onlyDigitsKeyDown}
                  onChange={e => {
                    const val = filterDigits(e.target.value)
                    setFormData(prev => ({ ...prev, phone_number: val }))
                    if (val.trim()) setFormErrors(prev => ({ ...prev, phone_number: '' }))
                  }}
                  className={`w-full px-3.5 py-2.5 border rounded-lg text-sm focus:outline-none transition ${
                    formErrors.phone_number
                      ? 'border-red-500 bg-red-50/20 focus:ring-2 focus:ring-red-200'
                      : 'border-lineGray focus:ring-2 focus:ring-primaryBlue/30'
                  }`}
                />
                {formErrors.phone_number && (
                  <p className="text-xs text-red-500 mt-1 font-medium">{formErrors.phone_number}</p>
                )}
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-700 mb-1">
                  Spesialisasi / Jabatan
                </label>
                <input
                  type="text"
                  placeholder="Contoh: Dokter Spesialis Penyakit Dalam / Edukator Diabetes"
                  value={formData.specialization}
                  onChange={e => setFormData({ ...formData, specialization: e.target.value })}
                  className="w-full px-3.5 py-2.5 border border-lineGray rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsFormOpen(false)}
                  className="px-4 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 transition"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-primaryBlue text-white text-sm font-semibold rounded-lg hover:bg-blue-600 transition shadow-sm"
                >
                  {isEditing ? 'Simpan Perubahan' : 'Tambah Tenaga Medis'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Kelola Penugasan Pasien */}
      {isAssignModalOpen && selectedStaff && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl shadow-xl max-w-lg w-full p-6 animate-scale-up">
            <h2 className="text-xl font-bold text-darkNavy mb-1">
              Atur Pasien untuk {selectedStaff.name}
            </h2>
            <p className="text-xs text-textSecondary mb-4">
              Pilih pasien-pasien yang akan berada di bawah pengawasan dokter ini. Pasien yang sama juga dapat dilayani oleh tenaga medis yang sama.
            </p>

            <div className="border border-slate-200 rounded-lg max-h-60 overflow-y-auto divide-y divide-slate-100 mb-5">
              {allPatients.length === 0 ? (
                <p className="text-sm text-slate-400 p-4 text-center">Belum ada pasien terdaftar.</p>
              ) : (
                allPatients.map(patient => {
                  const isChecked = selectedPatientIds.includes(patient.id)
                  return (
                    <label
                      key={patient.id}
                      className={`flex items-center gap-3 p-3 cursor-pointer hover:bg-slate-50 transition ${
                        isChecked ? 'bg-blue-50/50' : ''
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={isChecked}
                        onChange={() => handleTogglePatientAssign(patient.id)}
                        className="w-4 h-4 text-primaryBlue rounded border-gray-300 focus:ring-primaryBlue"
                      />
                      <div className="flex-1 text-sm">
                        <span className="font-semibold text-slate-800">{patient.name}</span>
                        <div className="text-xs text-slate-400">
                          {patient.age ? `${patient.age} tahun` : ''} • {patient.gender === 'L' ? 'Laki-laki' : 'Perempuan'} • {patient.email}
                        </div>
                      </div>
                      {patient.medical_staff_name && patient.medical_staff_id !== selectedStaff.id && (
                        <span className="text-[10px] bg-slate-100 text-slate-500 px-2 py-0.5 rounded">
                          Saat ini: {patient.medical_staff_name}
                        </span>
                      )}
                    </label>
                  )
                })
              )}
            </div>

            <div className="flex items-center justify-between pt-2 border-t border-slate-100">
              <span className="text-xs font-semibold text-slate-600">
                {selectedPatientIds.length} pasien terpilih
              </span>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setIsAssignModalOpen(false)}
                  className="px-4 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 transition"
                >
                  Batal
                </button>
                <button
                  type="button"
                  onClick={handleSaveAssignment}
                  className="px-4 py-2 bg-primaryBlue text-white text-sm font-semibold rounded-lg hover:bg-blue-600 transition shadow-sm"
                >
                  Simpan Penugasan
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modal Reusable untuk Notifikasi / Konfirmasi Hapus */}
      <ReusableModal
        isOpen={modal.isOpen}
        onClose={() => setModal({ ...modal, isOpen: false })}
        onConfirm={handleDelete}
        title={modal.title}
        message={modal.message}
        type={modal.type}
      />
    </div>
  )
}
