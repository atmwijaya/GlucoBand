import { useState, useEffect, useRef } from 'react'
import { io } from 'socket.io-client'
import { FaUser, FaChartLine, FaHistory, FaChevronDown, FaChevronUp, FaSearch, FaChevronRight } from 'react-icons/fa'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts'
import apiClient from '../../api/axios'
import PatientSelectionModal from '../../components/common/PatientSelectionModal'
import CircularGauge from '../../components/common/CircularGauge'
import RecommendationForm from '../../components/common/recommendationForm'
import ReusableModal from '../../components/common/Modal'

export default function RealtimeMonitorPage() {
  const [selectedPatient, setSelectedPatient] = useState(null)
  const [showPatientModal, setShowPatientModal] = useState(false)
  const [glucoseData, setGlucoseData] = useState({ glucose_estimated: 0, heartRate: 0, spo2: 0, skinTemp: 0 })
  const [history, setHistory] = useState([])
  const [predictionHistory, setPredictionHistory] = useState([])
  const [activeTab, setActiveTab] = useState('realtime')
  const [expandedHistoryId, setExpandedHistoryId] = useState(null)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const intervalRef = useRef(null)
  const selectedPatientRef = useRef(null)

  // State for initial patient list view
  const [patientsList, setPatientsList] = useState([])
  const [searchPatient, setSearchPatient] = useState('')
  const [loadingPatients, setLoadingPatients] = useState(false)
  const [expandedPatientId, setExpandedPatientId] = useState(null)
  const [patientPredictionHistory, setPatientPredictionHistory] = useState({})

  useEffect(() => {
    selectedPatientRef.current = selectedPatient
  }, [selectedPatient])

  useEffect(() => {
    const SOCKET_URL = import.meta.env.VITE_API_BASE_URL ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '') : 'http://localhost:5000'
    const socket = io(SOCKET_URL)

    socket.on('new_prediction_trend', (data) => {
      data.isNew = true
      
      const currentPatient = selectedPatientRef.current
      if (currentPatient && currentPatient.id === data.patient_id) {
        setPredictionHistory(prev => {
          if (!prev.find(p => p.id === data.id)) return [data, ...prev]
          return prev
        })
      }

      setPatientPredictionHistory(prev => {
        const pHistory = prev[data.patient_id] || []
        if (!pHistory.find(p => p.id === data.id)) {
          return { ...prev, [data.patient_id]: [data, ...pHistory] }
        }
        return prev
      })

      setTimeout(() => {
        setPredictionHistory(prev => prev.map(p => p.id === data.id ? { ...p, isNew: false } : p))
        setPatientPredictionHistory(prev => {
            const pHistory = prev[data.patient_id] || []
            return {
                ...prev,
                [data.patient_id]: pHistory.map(p => p.id === data.id ? { ...p, isNew: false } : p)
            }
        })
      }, 5000)
    })

    return () => socket.disconnect()
  }, [])

  useEffect(() => {
    if (!selectedPatient) {
      setLoadingPatients(true)
      apiClient.get('/patients')
        .then(({ data }) => setPatientsList(data))
        .catch(console.error)
        .finally(() => setLoadingPatients(false))
    }
  }, [selectedPatient])

  const fetchHistoryForPatientList = async (patientId) => {
    if (expandedPatientId === patientId) {
      setExpandedPatientId(null)
      return
    }
    setExpandedPatientId(patientId)
    if (!patientPredictionHistory[patientId]) {
      try {
        const res = await apiClient.get(`/predictions/trend/${patientId}/history`)
        setPatientPredictionHistory(prev => ({ ...prev, [patientId]: res.data }))
      } catch (err) {
        console.error('Gagal memuat riwayat:', err)
      }
    }
  }

  const fetchPredictionHistory = async (patientId) => {
    try {
      const res = await apiClient.get(`/predictions/trend/${patientId}/history`)
      setPredictionHistory(res.data)
    } catch (err) {
      console.error('Gagal memuat riwayat prediksi:', err)
    }
  }

  const fetchMonitoringData = async (patientId) => {
    if (!patientId) return
    try {
      const [liveRes, historyRes] = await Promise.all([
        apiClient.get(`/patients/${patientId}/latest`),
        apiClient.get(`/patients/${patientId}/measurements?limit=20`)
      ])
      setGlucoseData(liveRes.data)
      setHistory(historyRes.data.reverse())
    } catch (err) {
      console.error('Gagal memuat data monitoring:', err)
    }
  }

  useEffect(() => {
    if (selectedPatient) {
      fetchMonitoringData(selectedPatient.id)
      fetchPredictionHistory(selectedPatient.id)
      intervalRef.current = setInterval(() => fetchMonitoringData(selectedPatient.id), 5000)
    }
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [selectedPatient])

  const chartData = history.map(h => ({
    time: new Date(h.measured_at || h.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
    glucose: h.glucose_estimated ?? h.glucose_level
  }))

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <div className="flex items-center gap-3 text-xl md:text-2xl font-bold">
          <span 
            className={`cursor-pointer hover:text-primaryBlue transition flex items-center gap-2 ${selectedPatient ? 'text-slate-500' : 'text-darkNavy'}`}
            onClick={() => setSelectedPatient(null)}
            title="Kembali ke Daftar Pasien"
          >
            Monitoring
          </span>
          {selectedPatient && (
            <>
              <FaChevronRight className="text-slate-400 text-sm md:text-base mt-0.5" />
              <span className="text-darkNavy">{selectedPatient.name}</span>
            </>
          )}
        </div>
        <button
          onClick={() => setShowPatientModal(true)}
          className="flex items-center gap-2 px-4 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition"
        >
          <FaUser /> {selectedPatient ? 'Ganti Pasien' : 'Pilih Pasien'}
        </button>
      </div>

      {!selectedPatient ? (
        <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-bold text-slate-800">Daftar Pasien</h2>
            <div className="relative w-64">
              <FaSearch className="absolute left-3 top-3 text-gray-400" />
              <input
                type="text" placeholder="Cari pasien..." value={searchPatient}
                onChange={e => setSearchPatient(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 text-sm"
              />
            </div>
          </div>
          
          {loadingPatients ? (
            <p className="text-center text-gray-400 py-12">Memuat daftar pasien...</p>
          ) : (
            <div className="space-y-4">
              {patientsList.filter(p => p.name?.toLowerCase().includes(searchPatient.toLowerCase())).map(patient => (
                <div key={patient.id} className="border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                  <div className="p-4 bg-white flex justify-between items-center hover:bg-slate-50 transition">
                    <div>
                      <p className="font-bold text-slate-800 text-lg">{patient.name}</p>
                      <p className="text-sm text-slate-500 mt-1">Usia: {patient.age} th • BMI: {patient.bmi} • Risiko: <span className={patient.risk_level === 'high' ? 'text-red-500 font-medium' : patient.risk_level === 'moderate' ? 'text-amber-500 font-medium' : 'text-green-500 font-medium'}>{patient.risk_level === 'high' ? 'Tinggi' : patient.risk_level === 'moderate' ? 'Sedang' : 'Rendah'}</span></p>
                    </div>
                    <div className="flex items-center gap-3">
                      <button 
                        onClick={() => fetchHistoryForPatientList(patient.id)}
                        className="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 rounded-lg hover:bg-slate-200 transition flex items-center gap-2"
                      >
                        <FaHistory /> Riwayat Prediksi
                        {expandedPatientId === patient.id ? <FaChevronUp /> : <FaChevronDown />}
                      </button>
                      <button 
                        onClick={() => setSelectedPatient(patient)}
                        className="px-4 py-2 text-sm font-medium text-white bg-primaryBlue rounded-lg hover:bg-blue-600 transition flex items-center gap-2 shadow-sm"
                      >
                        <FaChartLine /> Monitoring
                      </button>
                    </div>
                  </div>
                  
                  {expandedPatientId === patient.id && (
                    <div className="p-5 bg-slate-50 border-t border-slate-200">
                       {!patientPredictionHistory[patient.id] ? (
                          <p className="text-sm text-slate-500 text-center py-4">Memuat riwayat...</p>
                       ) : patientPredictionHistory[patient.id].length === 0 ? (
                          <p className="text-sm text-slate-500 text-center py-4">Belum ada riwayat prediksi LSTM untuk pasien ini.</p>
                       ) : (
                          <div className="space-y-4 max-h-80 overflow-y-auto pr-2">
                            {patientPredictionHistory[patient.id].map(hist => (
                              <div key={hist.id} className={`bg-white p-4 rounded-xl border shadow-sm transition-colors duration-1000 ${hist.isNew ? 'border-primaryBlue/60 bg-blue-50/50' : 'border-slate-200'}`}>
                                <p className="text-sm font-semibold text-slate-800 mb-3 border-b border-slate-100 pb-2">
                                  Prediksi pada {new Date(hist.created_at).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' })}
                                </p>
                                <div className="grid grid-cols-3 md:grid-cols-6 gap-3">
                                  {hist.predicted_values && hist.predicted_values.map((val, idx) => (
                                    <div key={idx} className="bg-slate-50 p-2 rounded-lg text-center border border-slate-100 flex flex-col items-center justify-center">
                                      <p className="text-[11px] text-slate-500 font-medium mb-1">{val.timestamp ? new Date(val.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : `+${idx + 1} Jam`}</p>
                                      <p className="font-bold text-sm text-primaryBlue">{val.glucose ? Math.round(val.glucose) : Math.round(val)}</p>
                                      <p className="text-[10px] text-slate-400 mt-0.5">mg/dL</p>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            ))}
                          </div>
                       )}
                    </div>
                  )}
                </div>
              ))}
              {patientsList.length === 0 && !loadingPatients && (
                <p className="text-center text-gray-400 py-12">Tidak ada data pasien.</p>
              )}
            </div>
          )}
        </div>
      ) : (
        <>
          <div className="bg-white rounded-xl shadow-sm p-6 mb-6 border border-slate-100">
            <h3 className="text-lg font-semibold mb-3">Informasi Pasien</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <div><span className="text-textSecondary">Nama:</span> <p className="font-medium">{selectedPatient.name}</p></div>
              <div><span className="text-textSecondary">Usia:</span> <p className="font-medium">{selectedPatient.age} tahun</p></div>
              <div><span className="text-textSecondary">BMI:</span> <p className="font-medium">{selectedPatient.bmi}</p></div>
              <div><span className="text-textSecondary">Risiko:</span> <p className={`font-medium ${selectedPatient.risk_level === 'high' ? 'text-errorRed' : 'text-successGreen'}`}>
                {selectedPatient.risk_level === 'high' ? 'Tinggi' : selectedPatient.risk_level === 'moderate' ? 'Sedang' : 'Rendah'}
              </p></div>
            </div>
          </div>

          <div className="flex border-b border-gray-200 mb-6">
            <button
              onClick={() => setActiveTab('realtime')}
              className={`py-2 px-6 font-medium text-sm flex items-center gap-2 border-b-2 transition ${
                activeTab === 'realtime'
                  ? 'border-primaryBlue text-primaryBlue'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              <FaChartLine /> Real-time
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`py-2 px-6 font-medium text-sm flex items-center gap-2 border-b-2 transition ${
                activeTab === 'history'
                  ? 'border-primaryBlue text-primaryBlue'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              <FaHistory /> Riwayat Prediksi Tren
            </button>
          </div>

          {activeTab === 'realtime' ? (
            <>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-6 mb-8">
                <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
                  <CircularGauge value={glucoseData.glucose_estimated} maxValue={400} label="Glukosa" unit="mg/dL" />
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
                  <CircularGauge value={glucoseData.heartRate ?? 0} maxValue={200} label="Heart Rate" unit="BPM" />
                </div>
                <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
                  <CircularGauge value={glucoseData.skinTemp ?? 0} maxValue={45} label="Suhu Kulit" unit="°C" />
                </div>
              </div>

              <div className="bg-white rounded-xl shadow-sm p-6 mb-8">
                <h3 className="text-lg font-semibold mb-4">Tren Glukosa (20 data terakhir)</h3>
                <ResponsiveContainer width="100%" height={300}>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                    <XAxis dataKey="time" tick={{ fontSize: 11 }} />
                    <YAxis domain={[0, 400]} tick={{ fontSize: 12 }} />
                    <Tooltip />
                    <ReferenceLine y={200} stroke="#EF4444" strokeDasharray="5 5" label="Hiper" />
                    <ReferenceLine y={70} stroke="#F59E0B" strokeDasharray="5 5" label="Hipo" />
                    <Line type="monotone" dataKey="glucose" stroke="#3B82F6" strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>

              <RecommendationForm
                patientId={selectedPatient.id}
              />
            </>
          ) : (
            <div className="space-y-4">
              {predictionHistory.length === 0 ? (
                <p className="text-gray-500 text-center py-8 bg-white rounded-xl shadow-sm">Belum ada riwayat prediksi tren untuk pasien ini.</p>
              ) : (
                predictionHistory.map(hist => (
                  <div key={hist.id} className={`bg-white rounded-xl shadow-sm border overflow-hidden transition-colors duration-1000 ${hist.isNew ? 'border-primaryBlue/60 bg-blue-50/50' : 'border-slate-100'}`}>
                    <div 
                      className="p-4 flex justify-between items-center cursor-pointer hover:bg-slate-50 transition"
                      onClick={() => setExpandedHistoryId(expandedHistoryId === hist.id ? null : hist.id)}
                    >
                      <div>
                        <p className="font-semibold text-slate-800">Prediksi pada {new Date(hist.created_at).toLocaleString('id-ID')}</p>
                        <p className="text-sm text-slate-500">Horizon: {hist.horizon_hours} jam ke depan</p>
                      </div>
                      {expandedHistoryId === hist.id ? <FaChevronUp className="text-slate-400" /> : <FaChevronDown className="text-slate-400" />}
                    </div>
                    
                    {expandedHistoryId === hist.id && (
                      <div className="p-4 border-t border-slate-100 bg-slate-50">
                        <h4 className="text-sm font-medium text-slate-700 mb-3">Hasil Prediksi (Glukosa mg/dL):</h4>
                        <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
                          {hist.predicted_values && hist.predicted_values.map((val, idx) => (
                            <div key={idx} className="bg-white p-3 rounded-lg border border-slate-200 text-center shadow-sm flex flex-col items-center justify-center">
                              <p className="text-xs text-slate-500 font-medium mb-1">{val.timestamp ? new Date(val.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : `+${idx + 1} Jam`}</p>
                              <p className="font-bold text-lg text-primaryBlue">{val.glucose ? Math.round(val.glucose) : Math.round(val)}</p>
                              <p className="text-xs text-slate-400 mt-0.5">mg/dL</p>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ))
              )}
            </div>
          )}
        </>
      )}

      <PatientSelectionModal isOpen={showPatientModal} onClose={() => setShowPatientModal(false)} onSelect={setSelectedPatient} />
      <ReusableModal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}