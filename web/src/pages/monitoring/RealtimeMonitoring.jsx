import { useState, useEffect, useRef } from 'react'
import { FaUser } from 'react-icons/fa'
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
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const intervalRef = useRef(null)

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
        <h1 className="text-2xl font-bold text-darkNavy">
          Monitoring {selectedPatient ? `— ${selectedPatient.name}` : ''}
        </h1>
        <button
          onClick={() => setShowPatientModal(true)}
          className="flex items-center gap-2 px-4 py-2 bg-primaryBlue text-white rounded-lg hover:bg-blue-600 transition"
        >
          <FaUser /> {selectedPatient ? 'Ganti Pasien' : 'Pilih Pasien'}
        </button>
      </div>

      {!selectedPatient ? (
        <div className="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">
          <FaUser className="text-5xl mx-auto mb-4" />
          <p className="text-lg">Pilih pasien untuk memulai monitoring real‑time.</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-8">
            <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
              <CircularGauge value={glucoseData.glucose_estimated} maxValue={400} label="Glukosa" unit="mg/dL" />
            </div>
            <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
              <CircularGauge value={glucoseData.heartRate ?? 0} maxValue={200} label="Heart Rate" unit="BPM" />
            </div>
            <div className="bg-white rounded-xl shadow-sm p-6 flex justify-center">
              <CircularGauge value={glucoseData.spo2 ?? 0} maxValue={100} label="SpO2" unit="%" />
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
            onSuccess={() => setModal({ isOpen: true, title: 'Terkirim', message: 'Rekomendasi telah dikirim ke pasien.', type: 'success' })}
          />

          <div className="bg-white rounded-xl shadow-sm p-6 mt-8">
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
        </>
      )}

      <PatientSelectionModal isOpen={showPatientModal} onClose={() => setShowPatientModal(false)} onSelect={setSelectedPatient} />
      <ReusableModal isOpen={modal.isOpen} onClose={() => setModal({ ...modal, isOpen: false })}
        title={modal.title} message={modal.message} type={modal.type} />
    </div>
  )
}