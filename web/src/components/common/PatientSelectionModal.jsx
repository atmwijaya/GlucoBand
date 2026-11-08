import { useState, useEffect } from 'react'
import { FaSearch, FaTimes } from 'react-icons/fa'
import apiClient from '../../api/axios'

export default function PatientSelectionModal({ isOpen, onClose, onSelect, onlinePatientIds = [] }) {
  const [patients, setPatients] = useState([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (isOpen) {
      setLoading(true)
      apiClient.get('/patients')
        .then(({ data }) => setPatients(data))
        .catch(console.error)
        .finally(() => setLoading(false))
    }
  }, [isOpen])

  if (!isOpen) return null

  const filtered = patients.filter(p => p.name?.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg p-6">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h2 className="text-lg font-bold text-slate-800">Pilih Pasien untuk Monitoring</h2>
            <p className="text-xs text-slate-500">Pasien bertanda hijau sedang aktif terhubung ke aplikasi GlucoBand.</p>
          </div>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><FaTimes /></button>
        </div>
        <div className="relative mb-4">
          <FaSearch className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text" placeholder="Cari nama pasien..." value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
          />
        </div>
        <div className="max-h-72 overflow-y-auto space-y-2">
          {loading ? (
            <p className="text-center text-gray-400 py-6 text-sm">Memuat data pasien...</p>
          ) : filtered.length === 0 ? (
            <p className="text-center text-gray-400 py-6 text-sm">Tidak ada pasien yang sesuai</p>
          ) : (
            filtered.map(patient => {
              const isOnline = onlinePatientIds.map(Number).includes(Number(patient.id))
              return (
                <div
                  key={patient.id}
                  onClick={() => onSelect(patient)}
                  className={`flex justify-between items-center p-3 rounded-xl border transition cursor-pointer ${
                    isOnline
                      ? 'border-emerald-200 bg-emerald-50/40 hover:bg-emerald-50'
                      : 'border-slate-200 bg-white hover:bg-slate-50'
                  }`}
                >
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-emerald-500 animate-pulse' : 'bg-slate-300'}`} />
                      <p className="font-bold text-sm text-slate-800">{patient.name}</p>
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        isOnline ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-500'
                      }`}>
                        {isOnline ? 'Terhubung' : 'Offline'}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500 mt-1">
                      {patient.age} th • BMI {patient.bmi || '--'}
                    </p>
                  </div>

                  <span className={`text-xs font-semibold px-2.5 py-1 rounded-lg ${
                    isOnline ? 'bg-emerald-600 text-white' : 'bg-slate-100 text-slate-600'
                  }`}>
                    {isOnline ? 'Pilih (Online)' : 'Pilih'}
                  </span>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
