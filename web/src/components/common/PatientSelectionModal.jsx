import { useState, useEffect } from 'react'
import { FaSearch, FaTimes } from 'react-icons/fa'
import apiClient from '../../api/axios'

export default function PatientSelectionModal({ isOpen, onClose, onSelect }) {
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
          <h2 className="text-lg font-bold">Pilih Pasien</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600"><FaTimes /></button>
        </div>
        <div className="relative mb-4">
          <FaSearch className="absolute left-3 top-3 text-gray-400" />
          <input
            type="text" placeholder="Cari pasien..." value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30"
          />
        </div>
        <div className="max-h-64 overflow-y-auto space-y-2">
          {loading ? (
            <p className="text-center text-gray-400 py-4">Memuat...</p>
          ) : filtered.length === 0 ? (
            <p className="text-center text-gray-400 py-4">Tidak ada pasien</p>
          ) : (
            filtered.map(patient => (
              <div
                key={patient.id}
                onClick={() => onSelect(patient)}
                className="flex justify-between items-center p-3 rounded-lg border border-lineGray hover:bg-blue-50 cursor-pointer transition"
              >
                <div>
                  <p className="font-medium">{patient.name}</p>
                  <p className="text-xs text-textSecondary">{patient.age} th • BMI {patient.bmi}</p>
                </div>
                <span className={`text-xs font-bold px-2 py-1 rounded-full ${
                  (patient.latest_glucose ?? 0) > 200 ? 'bg-red-100 text-red-700' :
                  (patient.latest_glucose ?? 0) < 70 ? 'bg-amber-100 text-amber-700' :
                  'bg-green-100 text-green-700'
                }`}>
                  {patient.latest_glucose ?? '-'} mg/dL
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}