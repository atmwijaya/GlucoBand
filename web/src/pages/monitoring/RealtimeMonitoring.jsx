import { useState, useEffect, useRef } from 'react'
import { io } from 'socket.io-client'
import {
  FaUser, FaChartLine, FaHistory, FaChevronDown, FaChevronUp, FaSearch,
  FaChevronRight, FaHeart, FaWifi, FaSave, FaCheckCircle, FaExclamationTriangle,
  FaHandPaper, FaSyncAlt, FaBroadcastTower, FaBell, FaCloud, FaMicrochip,
  FaSignOutAlt, FaRedoAlt, FaPlug
} from 'react-icons/fa'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from 'recharts'
import apiClient from '../../api/axios'
import PatientSelectionModal from '../../components/common/PatientSelectionModal'
import CircularGauge from '../../components/common/circularGauge'
import RecommendationForm from '../../components/common/recommendationForm'
import ReusableModal from '../../components/common/modal'

export default function RealtimeMonitorPage() {
  // 1. Identifikasi User / Pasien yang Login
  const loggedUser = (() => {
    try {
      return JSON.parse(sessionStorage.getItem('user')) || {}
    } catch {
      return {}
    }
  })()
  const isPatientLogin = loggedUser.role === 'pasien'

  const [selectedPatient, setSelectedPatient] = useState(isPatientLogin ? loggedUser : null)
  const [showPatientModal, setShowPatientModal] = useState(false)
  const [glucoseData, setGlucoseData] = useState({
    glucose_estimated: 0,
    heartRate: 0,
    spo2: 0,
    skinTemp: 0,
    fingerPresent: false,
    rateCount: 0,
    isMeasuring: false
  })
  const [history, setHistory] = useState([])
  const [predictionHistory, setPredictionHistory] = useState([])
  const [activeTab, setActiveTab] = useState('realtime')
  const [expandedHistoryId, setExpandedHistoryId] = useState(null)
  const [modal, setModal] = useState({ isOpen: false, title: '', message: '', type: 'info' })
  const intervalRef = useRef(null)
  const selectedPatientRef = useRef(null)

  // 2. Dual Mode: 'online' (Production Cloud) atau 'direct' (Development Direct IP)
  // Per-Device Check: Hanya aktif jika diaktifkan di Pengaturan (/admin/settings) browser perangkat ini
  const isDevModeEnabled = localStorage.getItem('glucoband_dev_mode_enabled') === 'true'

  const [connectionMode, setConnectionMode] = useState(() => {
    const isDev = localStorage.getItem('glucoband_dev_mode_enabled') === 'true'
    if (!isDev) return 'online'
    return localStorage.getItem('glucoband_conn_mode') || 'online'
  })
  const [isSocketConnected, setIsSocketConnected] = useState(false)
  const [realtimeAlert, setRealtimeAlert] = useState({ show: false, message: '', time: '' })

  // Pastikan jika mode dev nonaktif di browser ini, paksa mode tetap 'online'
  useEffect(() => {
    if (!isDevModeEnabled && connectionMode !== 'online') {
      if (espPollRef.current) clearInterval(espPollRef.current)
      setConnectionMode('online')
      localStorage.setItem('glucoband_conn_mode', 'online')
    }
  }, [isDevModeEnabled, connectionMode])

  // 3. Konfigurasi Direct IP ESP32 (Mode Development)
  const [espIp, setEspIp] = useState(() => localStorage.getItem('glucoband_esp_ip') || '192.168.4.1')
  const [isEspConnected, setIsEspConnected] = useState(false)
  const [isSavingLive, setIsSavingLive] = useState(false)
  const espPollRef = useRef(null)
  const socketRef = useRef(null)

  // 3b. Isolasi Pasangan Hardware Mode Dev (Hanya 1 pasien yang dipasangkan dengan ESP32 fisik ini)
  const [pairedDevPatientId, setPairedDevPatientId] = useState(() => {
    const stored = sessionStorage.getItem('glucoband_paired_patient_id')
    return stored ? Number(stored) : null
  })
  const pairedDevPatientRef = useRef(pairedDevPatientId)
  useEffect(() => {
    pairedDevPatientRef.current = pairedDevPatientId
  }, [pairedDevPatientId])

  const togglePairDevPatient = (patientId) => {
    const pId = Number(patientId)
    if (pairedDevPatientId === pId) {
      setPairedDevPatientId(null)
      sessionStorage.removeItem('glucoband_paired_patient_id')
    } else {
      setPairedDevPatientId(pId)
      sessionStorage.setItem('glucoband_paired_patient_id', String(pId))
    }
  }

  // 3c. Tracking Pasien Online (Dari Socket.IO & Endpoint REST API /patients/online)
  const [onlinePatientIds, setOnlinePatientIds] = useState([])

  // State for initial patient list view (khusus tenaga medis)
  const [patientsList, setPatientsList] = useState([])
  const [searchPatient, setSearchPatient] = useState('')
  const [loadingPatients, setLoadingPatients] = useState(false)
  const [expandedPatientId, setExpandedPatientId] = useState(null)
  const [patientPredictionHistory, setPatientPredictionHistory] = useState({})

  useEffect(() => {
    selectedPatientRef.current = selectedPatient
  }, [selectedPatient])

  // Pasien login otomatis dipilih
  useEffect(() => {
    if (isPatientLogin && (!selectedPatient || selectedPatient.id !== loggedUser.id)) {
      setSelectedPatient(loggedUser)
    }
  }, [isPatientLogin, loggedUser])

  // Polling status pasien online secara berkala dari backend
  const fetchOnlinePatients = async () => {
    try {
      const res = await apiClient.get('/patients/online')
      if (Array.isArray(res.data)) {
        setOnlinePatientIds(res.data.map(Number))
      }
    } catch (err) {
      // Abaikan jika token belum siap
    }
  }

  useEffect(() => {
    fetchOnlinePatients()
    const pollInterval = setInterval(fetchOnlinePatients, 6000)
    return () => clearInterval(pollInterval)
  }, [])

  // Simpan preferensi mode ke localStorage
  const switchToOnlineMode = () => {
    if (espPollRef.current) clearInterval(espPollRef.current)
    setConnectionMode('online')
    localStorage.setItem('glucoband_conn_mode', 'online')
    if (selectedPatient) {
      fetchMonitoringData(selectedPatient.id)
    }
  }

  const switchToDirectMode = () => {
    setConnectionMode('direct')
    localStorage.setItem('glucoband_conn_mode', 'direct')
    pollEspHardware()
  }

  // 4. WebSocket (Socket.IO) Real-time Listener (Telemedicine / Mode Online)
  useEffect(() => {
    const SOCKET_URL = import.meta.env.VITE_API_BASE_URL
      ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '')
      : 'http://localhost:5000'
    const socket = io(SOCKET_URL, {
      reconnectionAttempts: 15,
      reconnectionDelay: 1500,
      timeout: 5000
    })
    socketRef.current = socket

    socket.on('connect', () => {
      setIsSocketConnected(true)
      socket.emit('get_online_patients')

      // Jika user yang sedang login adalah pasien, emit join dengan token
      const token = sessionStorage.getItem('token')
      if (token && isPatientLogin) {
        socket.emit('join', { token })
      }
    })

    socket.on('disconnect', () => {
      setIsSocketConnected(false)
    })

    socket.on('connect_error', () => {
      setIsSocketConnected(false)
    })

    // Mendengarkan siaran daftar ID pasien yang online dari backend
    socket.on('online_patients_list', (ids) => {
      if (Array.isArray(ids)) {
        setOnlinePatientIds(ids.map(Number))
      }
    })

    // A. Event Pengukuran Baru (Pasien selesai mengukur -> Ter-push seketika)
    socket.on('new_measurement', (data) => {
      if (connectionMode !== 'online') return

      const currentPatient = selectedPatientRef.current
      if (currentPatient && Number(currentPatient.id) === Number(data.patient_id)) {
        const heartRateVal = Number(data.ppg_heart_rate ?? data.heartRate ?? data.bpm) || 0
        const skinTempVal = Number(data.skin_temp_celsius ?? data.skinTemp ?? data.temperature) || 0
        const glucoseVal = Number(data.glucose_estimated ?? data.glucose) || 0

        setGlucoseData({
          glucose_estimated: glucoseVal,
          heartRate: heartRateVal,
          skinTemp: skinTempVal,
          spo2: data.ppg_spo2 || 98,
          fingerPresent: true,
          rateCount: 8,
          isMeasuring: false
        })

        // Tambahkan ke grafik garis
        setHistory(prev => {
          const newPoint = {
            id: data.id,
            created_at: data.created_at || new Date().toISOString(),
            glucose_estimated: glucoseVal
          }
          const updated = [...prev, newPoint]
          return updated.slice(-20)
        })

        setRealtimeAlert({
          show: true,
          message: `Data Pengukuran Diterima: ${glucoseVal} mg/dL • ${heartRateVal} BPM • ${skinTempVal}°C`,
          time: new Date().toLocaleTimeString('id-ID')
        })

        setTimeout(() => {
          setRealtimeAlert(prev => ({ ...prev, show: false }))
        }, 7000)
      }
    })

    // B. Event Live Sensor Stream (Streaming denyut nadi saat jari pasien menempel)
    socket.on('live_sensor_stream', (data) => {
      if (connectionMode !== 'online') return

      const currentPatient = selectedPatientRef.current
      if (currentPatient && Number(currentPatient.id) === Number(data.patient_id)) {
        const fingerPresent = Boolean(data.finger_present)
        const bpmAverage = Number(data.bpm) || 0
        const rateCount = Number(data.rate_count) || 0
        const objectTemp = data.temperature != null ? Number(data.temperature) : 36.5
        const isMeasuring = fingerPresent && bpmAverage === 0

        setGlucoseData(prev => ({
          ...prev,
          heartRate: bpmAverage,
          skinTemp: fingerPresent ? objectTemp : prev.skinTemp,
          fingerPresent,
          rateCount,
          isMeasuring
        }))
      }
    })

    // C. Event Prediksi Tren LSTM Real-time
    socket.on('new_prediction_trend', (data) => {
      data.isNew = true

      const currentPatient = selectedPatientRef.current
      if (currentPatient && Number(currentPatient.id) === Number(data.patient_id)) {
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
  }, [connectionMode])

  // Load daftar pasien jika user adalah tenaga medis dan belum memilih pasien
  useEffect(() => {
    if (!selectedPatient && !isPatientLogin) {
      setLoadingPatients(true)
      apiClient.get('/patients')
        .then(({ data }) => setPatientsList(data))
        .catch(console.error)
        .finally(() => setLoadingPatients(false))
    }
  }, [selectedPatient, isPatientLogin])

  // 5. Polling Database Cloud Backend (Mode Online)
  const fetchMonitoringData = async (patientId) => {
    if (!patientId || connectionMode === 'direct') return
    try {
      const [liveRes, historyRes] = await Promise.all([
        apiClient.get(`/patients/${patientId}/latest`).catch(() => ({ data: null })),
        apiClient.get(`/patients/${patientId}/measurements?limit=20`).catch(() => ({ data: [] }))
      ])

      if (liveRes.data) {
        const raw = liveRes.data
        const heartRateVal = Number(raw.ppg_heart_rate ?? raw.heartRate ?? raw.bpm) || 0
        const skinTempVal = Number(raw.skin_temp_celsius ?? raw.skinTemp ?? raw.temperature) || 0
        const glucoseVal = Number(raw.glucose_estimated ?? raw.glucose) || 0

        // Catatan: Data dari database adalah riwayat terakhir, BUKAN jari aktif yang sedang menempel saat ini
        setGlucoseData({
          glucose_estimated: glucoseVal,
          heartRate: heartRateVal,
          skinTemp: skinTempVal,
          spo2: raw.ppg_spo2 || 98,
          fingerPresent: false,
          rateCount: 0,
          isMeasuring: false
        })
      }

      if (Array.isArray(historyRes.data)) {
        setHistory([...historyRes.data].reverse())
      }
    } catch (err) {
      console.error('Gagal memuat data monitoring:', err)
    }
  }

  // 6. Polling Direct Hardware ESP32 (Mode Development)
  const pollEspHardware = async () => {
    if (connectionMode !== 'direct') return
    try {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 1200)

      const response = await fetch(`http://${espIp}/api/sensors`, {
        signal: controller.signal
      })
      clearTimeout(timeoutId)

      if (response.ok) {
        const data = await response.json()
        setIsEspConnected(true)

        // HANYA streaming sensor fisik ke pasien jika pasien ini dipasangkan dengan ESP32 lokal ini
        const currentPatient = selectedPatientRef.current
        const currentPairedId = pairedDevPatientRef.current
        const isPaired = currentPatient && (isPatientLogin || currentPairedId === Number(currentPatient.id))

        if (isPaired) {
          const fingerPresent = Boolean(data.finger_present)
          const bpmAverage = Number(data.bpm) || 0
          const rateCount = Number(data.rate_count) || 0
          const objectTemp = data.temperature != null ? Number(data.temperature) : 36.5
          const isMeasuring = fingerPresent && bpmAverage === 0

          // Estimasi glukosa dari 6 kanal spektrometer AS726X
          let liveGlucose = 110
          if (data.nir) {
            const { r = 10, s = 12, t = 10, u = 8, v = 6, w = 4 } = data.nir
            liveGlucose = Math.round(72.0 + (r * 1.6 + s * 2.1 + t * 1.4 + u * 0.9 + v * 0.6 + w * 0.4))
          }

          setGlucoseData({
            glucose_estimated: fingerPresent ? liveGlucose : 0,
            heartRate: bpmAverage,
            skinTemp: fingerPresent ? objectTemp : 0,
            spo2: fingerPresent ? 98 : 0,
            fingerPresent,
            rateCount,
            isMeasuring
          })
        }
      } else {
        setIsEspConnected(false)
      }
    } catch {
      setIsEspConnected(false)
    }
  }

  useEffect(() => {
    if (connectionMode === 'direct') {
      pollEspHardware()
      espPollRef.current = setInterval(pollEspHardware, 600)
    } else {
      if (espPollRef.current) clearInterval(espPollRef.current)
    }
    return () => {
      if (espPollRef.current) clearInterval(espPollRef.current)
    }
  }, [connectionMode, espIp])

  useEffect(() => {
    if (selectedPatient && connectionMode === 'online') {
      fetchMonitoringData(selectedPatient.id)
      fetchPredictionHistory(selectedPatient.id)
      intervalRef.current = setInterval(() => fetchMonitoringData(selectedPatient.id), 5000)
    }
    return () => { if (intervalRef.current) clearInterval(intervalRef.current) }
  }, [selectedPatient, connectionMode])

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

  // Simpan data live ESP32 ke database pasien (Mode Development)
  const saveLiveMeasurementToDb = async () => {
    if (!selectedPatient) {
      setModal({ isOpen: true, title: 'Pilih Pasien', message: 'Silakan pilih pasien terlebih dahulu sebelum mencatat data rekam medis.', type: 'warning' })
      return
    }
    if (!glucoseData.fingerPresent || glucoseData.heartRate === 0) {
      setModal({ isOpen: true, title: 'Data Belum Stabil', message: 'Tunggu hingga detak jantung (BPM) stabil dan jari terdeteksi pada sensor GlucoBand.', type: 'warning' })
      return
    }

    setIsSavingLive(true)
    try {
      await apiClient.post('/measurements', {
        patient_id: selectedPatient.id,
        glucose_estimated: glucoseData.glucose_estimated,
        ppg_heart_rate: glucoseData.heartRate,
        skin_temp_celsius: glucoseData.skinTemp,
        ppg_spo2: 98,
        created_at: new Date().toISOString(),
        source: 'hardware_live_dev'
      })

      setModal({
        isOpen: true,
        title: 'Berhasil Disimpan',
        message: `Data pengukuran BPM (${glucoseData.heartRate} BPM) dan Glukosa (${glucoseData.glucose_estimated} mg/dL) berhasil dicatat ke rekam medis ${selectedPatient.name}.`,
        type: 'success'
      })
      fetchMonitoringData(selectedPatient.id)
    } catch (err) {
      setModal({ isOpen: true, title: 'Gagal Menyimpan', message: err.response?.data?.msg || 'Gagal menyimpan pengukuran ke server.', type: 'error' })
    } finally {
      setIsSavingLive(false)
    }
  }

  const chartData = history.map(h => ({
    time: new Date(h.created_at || h.measured_at || h.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }),
    glucose: Number(h.glucose_estimated ?? h.glucose_level ?? 0)
  }))

  const getBpmStatus = (bpm) => {
    if (!bpm || bpm === 0) return { label: 'Tidak Ada Sinyal', color: 'text-slate-400', bg: 'bg-slate-100' }
    if (bpm >= 60 && bpm <= 100) return { label: 'Normal (Istirahat)', color: 'text-emerald-600', bg: 'bg-emerald-50' }
    if (bpm < 60) return { label: 'Bradikardia (Rendah)', color: 'text-amber-600', bg: 'bg-amber-50' }
    return { label: 'Takikardia (Tinggi)', color: 'text-rose-600', bg: 'bg-rose-50' }
  }

  const bpmStatus = getBpmStatus(glucoseData.heartRate)

  // Evaluasi apakah pasien yang sedang dibuka aktif akunnya dan terhubung
  const isPatientOnlineInCloud = Boolean(
    selectedPatient && onlinePatientIds.map(Number).includes(Number(selectedPatient.id))
  )

  const isPatientPairedInDev = Boolean(
    selectedPatient && connectionMode === 'direct' && isEspConnected && (isPatientLogin || pairedDevPatientId === Number(selectedPatient.id))
  )

  const isPatientConnected = isPatientLogin
    ? (connectionMode === 'direct' ? isEspConnected : isSocketConnected)
    : (connectionMode === 'direct' ? isPatientPairedInDev : isPatientOnlineInCloud)

  const handleSelectPatient = (patient) => {
    setSelectedPatient(patient)
    setGlucoseData({
      glucose_estimated: 0,
      heartRate: 0,
      spo2: 0,
      skinTemp: 0,
      fingerPresent: false,
      rateCount: 0,
      isMeasuring: false
    })
  }

  // Status koneksi keseluruhan
  const isOnlineActive = connectionMode === 'online' && isSocketConnected
  const isOnlineOfflineFallback = connectionMode === 'online' && !isSocketConnected
  const isDirectActive = connectionMode === 'direct' && isEspConnected
  const isDirectOfflineFallback = connectionMode === 'direct' && !isEspConnected

  return (
    <div className="p-4 md:p-6 max-w-7xl mx-auto">
      {/* Real-time Notification Banner saat data baru masuk dari pasien */}
      {realtimeAlert.show && (
        <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 px-4 py-2.5 rounded-lg mb-4 flex items-center justify-between text-xs">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span className="font-semibold">{realtimeAlert.message}</span>
            <span className="text-emerald-600">({realtimeAlert.time})</span>
          </div>
          <button
            onClick={() => setRealtimeAlert(prev => ({ ...prev, show: false }))}
            className="text-emerald-600 hover:text-emerald-900 text-sm font-bold ml-2"
          >
            ×
          </button>
        </div>
      )}

      {/* Top Header & Patient Context */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <div className="flex items-center gap-2 text-xl md:text-2xl font-bold text-darkNavy">
            <span
              className={`cursor-pointer hover:text-primaryBlue transition flex items-center gap-2 ${selectedPatient && !isPatientLogin ? 'text-slate-500' : 'text-darkNavy'}`}
              onClick={() => { if (!isPatientLogin) setSelectedPatient(null) }}
              title={isPatientLogin ? 'Monitoring Pasien' : 'Kembali ke Daftar Pasien'}
            >
              Real-time Monitoring
            </span>
            {selectedPatient && (
              <>
                <FaChevronRight className="text-slate-400 text-sm mt-0.5" />
                <span className="text-primaryBlue">{selectedPatient.name}</span>
                {isPatientLogin && (
                  <span className="ml-2 px-2.5 py-0.5 text-xs font-semibold bg-blue-100 text-primaryBlue rounded-full">
                    Akun Anda
                  </span>
                )}
              </>
            )}
          </div>
          <p className="text-sm text-textSecondary mt-1">
            {isPatientLogin
              ? 'Pemantauan denyut jantung BPM dan estimasi glukosa mandiri GlucoBand'
              : 'Pemantauan denyut jantung, suhu kulit, dan tren glukosa pasien secara klinis'}
          </p>
        </div>

        {/* CONTROLS: MODE SWITCHER (HANYA AKTIF JIKA MODE DEV ON DI PENGATURAN DEVICE INI) & PILIH PASIEN */}
        <div className="flex flex-wrap items-center gap-3">
          {isDevModeEnabled && (
            <div className="inline-flex rounded-lg border border-slate-200 bg-slate-100 p-0.5 text-xs">
              <button
                onClick={switchToOnlineMode}
                className={`px-3 py-1 rounded-md font-medium transition ${
                  connectionMode === 'online'
                    ? 'bg-white text-slate-800 shadow-sm font-semibold'
                    : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                Online Cloud
              </button>
              <button
                onClick={switchToDirectMode}
                className={`px-3 py-1 rounded-md font-medium transition ${
                  connectionMode === 'direct'
                    ? 'bg-white text-slate-800 shadow-sm font-semibold'
                    : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                Direct IP (Dev)
              </button>
            </div>
          )}

          {!isPatientLogin && (
            <button
              onClick={() => setShowPatientModal(true)}
              className="flex items-center gap-2 px-4 py-2 bg-primaryBlue text-white text-sm font-semibold rounded-lg hover:bg-blue-600 transition shadow-sm"
            >
              <FaUser size={14} /> {selectedPatient ? 'Ganti Pasien' : 'Pilih Pasien'}
            </button>
          )}
        </div>
      </div>

      {/* FALLBACK STATUS JIKA OFFLINE */}
      {isOnlineOfflineFallback && (
        <div className="bg-amber-50 border border-amber-200 text-amber-900 px-4 py-2.5 rounded-lg mb-4 flex flex-col sm:flex-row items-center justify-between gap-2 text-xs">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-amber-500 flex-shrink-0" />
            <span>Koneksi server realtime terputus. Menampilkan data tersimpan terakhir di memori.</span>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                if (socketRef.current) socketRef.current.connect()
                if (selectedPatient) fetchMonitoringData(selectedPatient.id)
              }}
              className="font-semibold text-amber-800 hover:underline flex items-center gap-1"
            >
              <FaRedoAlt size={11} /> Hubungkan Ulang
            </button>
            {isDevModeEnabled && (
              <>
                <span className="text-amber-300">|</span>
                <button
                  onClick={switchToDirectMode}
                  className="font-semibold text-amber-800 hover:underline"
                >
                  Gunakan Direct IP
                </button>
              </>
            )}
          </div>
        </div>
      )}

      {/* TOOLBAR DEV DIRECT IP */}
      {isDevModeEnabled && connectionMode === 'direct' && (
        <div className="bg-slate-100 border border-slate-300/80 text-slate-800 px-3.5 py-2 rounded-lg mb-4 flex flex-wrap items-center justify-between gap-3 text-xs">
          <div className="flex flex-wrap items-center gap-3">
            <span className="font-semibold text-slate-600">Dev Direct IP:</span>
            <div className="flex items-center gap-1.5 font-mono">
              <input
                type="text"
                value={espIp}
                onChange={(e) => {
                  setEspIp(e.target.value)
                  localStorage.setItem('glucoband_esp_ip', e.target.value)
                }}
                className="px-2 py-0.5 bg-white border border-slate-300 rounded text-xs w-28 focus:outline-none focus:border-slate-500"
                placeholder="192.168.4.1"
              />
              <button
                onClick={pollEspHardware}
                className="px-2 py-0.5 bg-white hover:bg-slate-50 border border-slate-300 rounded text-slate-600 font-sans"
                title="Cek Sambungan IP"
              >
                Cek
              </button>
            </div>

            <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-medium ${
              isEspConnected ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
            }`}>
              <span className={`w-1.5 h-1.5 rounded-full ${isEspConnected ? 'bg-emerald-500' : 'bg-amber-500'}`} />
              {isEspConnected ? 'ESP Terhubung' : 'ESP Belum Terdeteksi'}
            </span>

            {/* Tombol Khusus Pasangkan Hardware ke Pasien Tertentu */}
            {selectedPatient && !isPatientLogin && (
              <button
                onClick={() => togglePairDevPatient(selectedPatient.id)}
                className={`px-2 py-0.5 rounded text-[11px] font-medium border transition ${
                  pairedDevPatientId === Number(selectedPatient.id)
                    ? 'bg-emerald-100 border-emerald-300 text-emerald-800'
                    : 'bg-white border-slate-300 text-slate-600 hover:bg-slate-50'
                }`}
                title={pairedDevPatientId === Number(selectedPatient.id) ? 'Klik untuk melepas hardware dari pasien ini' : 'Klik untuk mengaitkan hardware lokal hanya ke pasien ini'}
              >
                {pairedDevPatientId === Number(selectedPatient.id)
                  ? '✓ Dipasangkan ke Pasien Ini'
                  : '+ Pasangkan ke Pasien Ini'}
              </button>
            )}

            {isPatientConnected && glucoseData.fingerPresent && (
              <span className="text-slate-600 text-[11px]">
                {glucoseData.isMeasuring
                  ? `Menganalisis (${glucoseData.rateCount}/8 detak)...`
                  : `Nadi: ${glucoseData.heartRate} BPM`}
              </span>
            )}
          </div>

          <div className="flex items-center gap-2">
            {selectedPatient && (
              <button
                onClick={saveLiveMeasurementToDb}
                disabled={!isPatientConnected || isSavingLive || !glucoseData.fingerPresent || glucoseData.heartRate === 0}
                className="px-2.5 py-1 bg-slate-800 hover:bg-slate-900 disabled:opacity-40 disabled:cursor-not-allowed text-white rounded font-medium text-xs transition"
                title={!isPatientConnected ? 'Pengukuran tidak dapat dilakukan karena perangkat/akun pasien tidak terhubung' : ''}
              >
                {isSavingLive ? 'Menyimpan...' : 'Catat Pengukuran'}
              </button>
            )}
            <button
              onClick={switchToOnlineMode}
              className="px-2.5 py-1 bg-white hover:bg-slate-50 border border-slate-300 text-slate-700 rounded text-xs transition"
            >
              Keluar ke Online
            </button>
          </div>
        </div>
      )}

      {/* View Konten: Daftar Pasien ATAU Dashboard Monitoring Pasien */}
      {!selectedPatient && !isPatientLogin ? (
        <div className="bg-white rounded-xl shadow-sm p-6 mb-6">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-bold text-slate-800">Pilih Pasien untuk Memulai Monitoring</h2>
            <div className="relative w-64">
              <FaSearch className="absolute left-3 top-3 text-gray-400" />
              <input
                type="text"
                placeholder="Cari nama pasien..."
                value={searchPatient}
                onChange={e => setSearchPatient(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-lineGray rounded-lg focus:outline-none focus:ring-2 focus:ring-primaryBlue/30 text-sm"
              />
            </div>
          </div>

          {loadingPatients ? (
            <p className="text-center text-gray-400 py-12">Memuat daftar pasien...</p>
          ) : (
            <div className="space-y-4">
              {patientsList.filter(p => p.name?.toLowerCase().includes(searchPatient.toLowerCase())).map(patient => {
                const isOnline = onlinePatientIds.map(Number).includes(Number(patient.id))
                return (
                  <div key={patient.id} className="border border-slate-200 rounded-xl overflow-hidden shadow-sm hover:border-primaryBlue/40 transition">
                    <div className="p-4 bg-white flex justify-between items-center hover:bg-slate-50 transition">
                      <div>
                        <div className="flex items-center gap-2">
                          <span className={`w-2.5 h-2.5 rounded-full ${isOnline ? 'bg-emerald-500 animate-pulse' : 'bg-slate-300'}`} />
                          <p className="font-bold text-slate-800 text-lg">{patient.name}</p>
                          <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full ${
                            isOnline ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-500'
                          }`}>
                            {isOnline ? '● Online' : '○ Offline'}
                          </span>
                        </div>
                        <p className="text-sm text-slate-500 mt-1">
                          Usia: {patient.age} th • BMI: {patient.bmi} • Risiko:{' '}
                          <span className={patient.risk_level === 'high' ? 'text-red-500 font-semibold' : patient.risk_level === 'moderate' ? 'text-amber-500 font-semibold' : 'text-green-500 font-semibold'}>
                            {patient.risk_level === 'high' ? 'Tinggi' : patient.risk_level === 'moderate' ? 'Sedang' : 'Rendah'}
                          </span>
                        </p>
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
                          onClick={() => handleSelectPatient(patient)}
                          className={`px-4 py-2 text-sm font-medium rounded-lg transition flex items-center gap-2 shadow-sm ${
                            isOnline ? 'bg-emerald-600 hover:bg-emerald-700 text-white' : 'bg-primaryBlue hover:bg-blue-600 text-white'
                          }`}
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
                                      <p className="text-[11px] text-slate-500 font-medium mb-1">
                                        {val.timestamp ? new Date(val.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : `+${idx + 1} Jam`}
                                      </p>
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
                )
              })}
              {patientsList.length === 0 && !loadingPatients && (
                <p className="text-center text-gray-400 py-12">Tidak ada data pasien yang terdaftar.</p>
              )}
            </div>
          )}
        </div>
      ) : (
        <>
          {/* Kartu Informasi Pasien yang Dipilih */}
          <div className="bg-white rounded-xl shadow-sm p-5 mb-6 border border-slate-100">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 pb-3 mb-3">
              <h3 className="text-base font-bold text-darkNavy flex items-center gap-2">
                <FaUser className="text-primaryBlue" /> Data Pasien
              </h3>
              <div className="flex items-center gap-2">
                <span className={`w-2 h-2 rounded-full ${isPatientConnected ? 'bg-emerald-500 animate-pulse' : 'bg-slate-400'}`} />
                <span className={`text-xs font-semibold px-2.5 py-0.5 rounded-full border ${
                  isPatientConnected
                    ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                    : 'bg-slate-100 text-slate-600 border-slate-200'
                }`}>
                  {connectionMode === 'online'
                    ? (isPatientConnected ? 'Pasien Terhubung' : 'Pasien Tidak Terhubung')
                    : (isPatientConnected ? `Terhubung (${espIp})` : (isEspConnected ? 'Belum Dipasangkan ke Pasien Ini' : 'ESP Terputus'))}
                </span>
              </div>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <div><span className="text-textSecondary text-xs">Nama Lengkap:</span> <p className="font-semibold text-slate-800">{selectedPatient.name}</p></div>
              <div><span className="text-textSecondary text-xs">Usia Pasien:</span> <p className="font-semibold text-slate-800">{selectedPatient.age || '--'} tahun</p></div>
              <div><span className="text-textSecondary text-xs">Indeks Massa Tubuh (BMI):</span> <p className="font-semibold text-slate-800">{selectedPatient.bmi || '--'}</p></div>
              <div>
                <span className="text-textSecondary text-xs">Tingkat Risiko Diabetes:</span>
                <p className={`font-bold ${selectedPatient.risk_level === 'high' ? 'text-rose-600' : selectedPatient.risk_level === 'moderate' ? 'text-amber-500' : 'text-emerald-600'}`}>
                  {selectedPatient.risk_level === 'high' ? 'Tinggi' : selectedPatient.risk_level === 'moderate' ? 'Sedang' : 'Rendah / Normal'}
                </p>
              </div>
            </div>
          </div>

          {/* Banner Status Jika Pasien Belum Terhubung */}
          {!isPatientConnected && (
            <div className="bg-slate-50 border border-slate-200 text-slate-700 px-4 py-3 rounded-xl mb-6 flex items-start gap-3 text-xs">
              <FaExclamationTriangle className="text-amber-500 mt-0.5 flex-shrink-0" size={15} />
              <div>
                <p className="font-bold text-slate-800">
                  {connectionMode === 'direct'
                    ? 'Hardware ESP32 Belum Dipasangkan ke Pasien Ini'
                    : 'Akun Pasien Sedang Tidak Terhubung (Offline)'}
                </p>
                <p className="text-slate-500 mt-0.5">
                  {connectionMode === 'direct'
                    ? 'Pengukuran live dinonaktifkan untuk mencegah pencampuran data. Klik "+ Pasangkan ke Pasien Ini" pada toolbar atas untuk mengaitkan alat hanya ke pasien ini.'
                    : 'Pengukuran real-time dinonaktifkan hingga pasien mengaktifkan aplikasi GlucoBand di perangkat mereka. Anda tetap dapat meninjau grafik riwayat rekam medis sebelumnya di bawah.'}
                </p>
              </div>
            </div>
          )}

          {/* Tab Navigasi Real-time & Riwayat */}
          <div className="flex border-b border-gray-200 mb-6">
            <button
              onClick={() => setActiveTab('realtime')}
              className={`py-2 px-6 font-semibold text-sm flex items-center gap-2 border-b-2 transition ${
                activeTab === 'realtime'
                  ? 'border-primaryBlue text-primaryBlue'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              <FaChartLine /> Pemantauan Real-time (BPM & Glukosa)
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`py-2 px-6 font-semibold text-sm flex items-center gap-2 border-b-2 transition ${
                activeTab === 'history'
                  ? 'border-primaryBlue text-primaryBlue'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              }`}
            >
              <FaHistory /> Riwayat Prediksi Tren (LSTM)
            </button>
          </div>

          {activeTab === 'realtime' ? (
            <>
              {/* TIGA GAUGE SENSOR UTAMA: GLUKOSA, HEART RATE (BPM), SUHU KULIT */}
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                {/* 1. GAUGE GLUKOSA */}
                <div className="bg-white rounded-xl shadow-sm p-6 flex flex-col items-center justify-between border border-slate-100 hover:shadow-md transition">
                  <div className="w-full flex justify-between items-center mb-2">
                    <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Kadar Glukosa</span>
                    <span className="text-xs px-2 py-0.5 rounded font-bold bg-blue-50 text-primaryBlue">NIR AS726X</span>
                  </div>
                  <CircularGauge
                    value={isPatientConnected ? glucoseData.glucose_estimated : 0}
                    maxValue={400}
                    label="Glukosa Darah"
                    unit="mg/dL"
                    type="glucose"
                    disabled={!isPatientConnected}
                  />
                  <div className="w-full text-center mt-3 pt-3 border-t border-slate-100">
                    <span className="text-xs text-slate-500">
                      Status:{' '}
                      {!isPatientConnected ? (
                        <strong className="text-slate-400">Perangkat Tidak Terhubung</strong>
                      ) : (
                        <strong className={glucoseData.glucose_estimated > 200 ? 'text-rose-600' : glucoseData.glucose_estimated < 70 && glucoseData.glucose_estimated > 0 ? 'text-amber-500' : 'text-emerald-600'}>
                          {glucoseData.glucose_estimated > 200 ? 'Hiperglikemia' : glucoseData.glucose_estimated < 70 && glucoseData.glucose_estimated > 0 ? 'Hipoglikemia' : glucoseData.glucose_estimated === 0 ? 'Menunggu Sensor' : 'Normal'}
                        </strong>
                      )}
                    </span>
                  </div>
                </div>

                {/* 2. GAUGE DETAK JANTUNG BPM (Sesuai glucoband.ino & MAX30105) */}
                <div className="bg-white rounded-xl shadow-sm p-6 flex flex-col items-center justify-between border border-slate-100 hover:shadow-md transition relative overflow-hidden">
                  <div className="w-full flex justify-between items-center mb-2">
                    <span className="text-xs font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1.5">
                      <FaHeart className={`text-rose-500 ${isPatientConnected && glucoseData.heartRate > 0 ? 'animate-pulse' : ''}`} />
                      Denyut Jantung (BPM)
                    </span>
                    <span className="text-xs px-2 py-0.5 rounded font-bold bg-rose-50 text-rose-600">MAX30105</span>
                  </div>

                  <CircularGauge
                    value={isPatientConnected ? glucoseData.heartRate : 0}
                    maxValue={200}
                    label="Detak Nadi"
                    unit="BPM"
                    type="heartRate"
                    isMeasuring={isPatientConnected && glucoseData.isMeasuring}
                    disabled={!isPatientConnected}
                  />

                  <div className="w-full text-center mt-3 pt-3 border-t border-slate-100">
                    {!isPatientConnected ? (
                      <div className="flex flex-col items-center">
                        <span className="text-xs font-bold text-slate-400">
                          Perangkat Tidak Terhubung
                        </span>
                        <span className="text-[11px] text-slate-400 mt-0.5">
                          {connectionMode === 'online' ? 'Menunggu pasien aktif' : 'Pasangkan hardware terlebih dahulu'}
                        </span>
                      </div>
                    ) : glucoseData.isMeasuring ? (
                      <span className="text-xs font-semibold text-amber-600 animate-pulse">
                        Menganalisis Nadi ({glucoseData.rateCount}/8 detak)...
                      </span>
                    ) : (
                      <div className="flex flex-col items-center">
                        <span className={`text-xs font-bold ${bpmStatus.color}`}>
                          {bpmStatus.label}
                        </span>
                        <span className="text-[11px] text-slate-400 mt-0.5">
                          {connectionMode === 'online'
                            ? (glucoseData.heartRate > 0 ? 'Tersinkronisasi Cloud' : 'Menunggu Sinyal Pasien')
                            : (glucoseData.fingerPresent ? 'Buffer 8 Detak (OLED OK)' : 'Tempelkan Jari')}
                        </span>
                      </div>
                    )}
                  </div>
                </div>

                {/* 3. GAUGE SUHU KULIT */}
                <div className="bg-white rounded-xl shadow-sm p-6 flex flex-col items-center justify-between border border-slate-100 hover:shadow-md transition">
                  <div className="w-full flex justify-between items-center mb-2">
                    <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Suhu Kulit</span>
                    <span className="text-xs px-2 py-0.5 rounded font-bold bg-amber-50 text-amber-600">MLX90614</span>
                  </div>
                  <CircularGauge
                    value={isPatientConnected ? glucoseData.skinTemp : 0}
                    maxValue={45}
                    label="Suhu Inframerah"
                    unit="°C"
                    type="temp"
                    disabled={!isPatientConnected}
                  />
                  <div className="w-full text-center mt-3 pt-3 border-t border-slate-100">
                    <span className="text-xs text-slate-500">
                      Kondisi:{' '}
                      {!isPatientConnected ? (
                        <strong className="text-slate-400">Perangkat Tidak Terhubung</strong>
                      ) : (
                        <strong className={glucoseData.skinTemp >= 36 && glucoseData.skinTemp <= 37.5 ? 'text-emerald-600' : 'text-amber-500'}>
                          {glucoseData.skinTemp >= 36 && glucoseData.skinTemp <= 37.5 ? 'Suhu Normal' : 'Di Luar Kisaran Standar'}
                        </strong>
                      )}
                    </span>
                  </div>
                </div>
              </div>

              {/* Grafik Tren Glukosa Terkini */}
              <div className="bg-white rounded-xl shadow-sm p-6 mb-8 border border-slate-100">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-base font-bold text-slate-800">
                    Tren Glukosa Pasien (20 Pengukuran Terakhir)
                  </h3>
                  <span className="text-xs text-slate-400">Target Normal: 70 - 200 mg/dL</span>
                </div>
                {chartData.length === 0 ? (
                  <p className="text-center text-slate-400 py-16 text-sm">Belum ada riwayat pengukuran yang tercatat.</p>
                ) : (
                  <ResponsiveContainer width="100%" height={280}>
                    <LineChart data={chartData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                      <XAxis dataKey="time" tick={{ fontSize: 11 }} />
                      <YAxis domain={[0, 400]} tick={{ fontSize: 12 }} />
                      <Tooltip />
                      <ReferenceLine y={200} stroke="#EF4444" strokeDasharray="5 5" label={{ value: 'Batas Hiper (200)', fill: '#EF4444', fontSize: 10 }} />
                      <ReferenceLine y={70} stroke="#F59E0B" strokeDasharray="5 5" label={{ value: 'Batas Hipo (70)', fill: '#F59E0B', fontSize: 10 }} />
                      <Line type="monotone" dataKey="glucose" stroke="#3B82F6" strokeWidth={2.5} dot={{ r: 3, fill: '#3B82F6' }} activeDot={{ r: 5 }} />
                    </LineChart>
                  </ResponsiveContainer>
                )}
              </div>

              {/* Form Rekomendasi Medis (Hanya untuk tenaga medis) */}
              {!isPatientLogin && (
                <RecommendationForm
                  patientId={selectedPatient.id}
                />
              )}
            </>
          ) : (
            /* TAB RIWAYAT PREDIKSI TREN LSTM */
            <div className="space-y-4">
              {predictionHistory.length === 0 ? (
                <p className="text-gray-500 text-center py-12 bg-white rounded-xl shadow-sm">
                  Belum ada riwayat prediksi tren untuk pasien ini.
                </p>
              ) : (
                predictionHistory.map(hist => (
                  <div
                    key={hist.id}
                    className={`bg-white rounded-xl shadow-sm border overflow-hidden transition-colors duration-1000 ${
                      hist.isNew ? 'border-primaryBlue/60 bg-blue-50/50' : 'border-slate-100'
                    }`}
                  >
                    <div
                      className="p-4 flex justify-between items-center cursor-pointer hover:bg-slate-50 transition"
                      onClick={() => setExpandedHistoryId(expandedHistoryId === hist.id ? null : hist.id)}
                    >
                      <div>
                        <p className="font-semibold text-slate-800 text-sm md:text-base">
                          Prediksi pada {new Date(hist.created_at).toLocaleString('id-ID')}
                        </p>
                        <p className="text-xs text-slate-500 mt-0.5">
                          Horizon Waktu: {hist.horizon_hours} jam ke depan • Model LSTM
                        </p>
                      </div>
                      {expandedHistoryId === hist.id ? <FaChevronUp className="text-slate-400" /> : <FaChevronDown className="text-slate-400" />}
                    </div>

                    {expandedHistoryId === hist.id && (
                      <div className="p-4 border-t border-slate-100 bg-slate-50">
                        <h4 className="text-xs font-bold text-slate-600 uppercase tracking-wider mb-3">
                          Hasil Prediksi Glukosa (mg/dL):
                        </h4>
                        <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
                          {hist.predicted_values && hist.predicted_values.map((val, idx) => (
                            <div key={idx} className="bg-white p-3 rounded-lg border border-slate-200 text-center shadow-sm flex flex-col items-center justify-center">
                              <p className="text-[11px] text-slate-500 font-medium mb-1">
                                {val.timestamp ? new Date(val.timestamp).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : `+${idx + 1} Jam`}
                              </p>
                              <p className="font-bold text-base text-primaryBlue">
                                {val.glucose ? Math.round(val.glucose) : Math.round(val)}
                              </p>
                              <p className="text-[10px] text-slate-400 mt-0.5">mg/dL</p>
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

      {/* Modal Pemilihan Pasien */}
      <PatientSelectionModal
        isOpen={showPatientModal}
        onClose={() => setShowPatientModal(false)}
        onlinePatientIds={onlinePatientIds}
        onSelect={(p) => {
          handleSelectPatient(p)
          setShowPatientModal(false)
        }}
      />

      <ReusableModal
        isOpen={modal.isOpen}
        onClose={() => setModal({ ...modal, isOpen: false })}
        title={modal.title}
        message={modal.message}
        type={modal.type}
      />
    </div>
  )
}
