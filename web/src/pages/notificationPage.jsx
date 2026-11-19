import { useState, useEffect, useMemo, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { io } from 'socket.io-client'
import {
  FaBell,
  FaExclamationTriangle,
  FaArrowUp,
  FaArrowDown,
  FaClock
} from 'react-icons/fa'
import apiClient from '../api/axios'
import LoadingSkeleton from '../components/common/loading'

export default function NotificationPage() {
  const navigate = useNavigate()
  const [notifs, setNotifs] = useState([])
  const [loading, setLoading] = useState(true)
  const [filterType, setFilterType] = useState('all') // 'all' | 'hiperglikemia' | 'hipoglikemia'
  const socketRef = useRef(null)

  // 1. Ambil data riwayat notifikasi dari API backend
  const fetchNotifications = async () => {
    try {
      const { data } = await apiClient.get('/notifications?limit=100')
      if (Array.isArray(data)) {
        setNotifs(data)
      }
    } catch (err) {
      console.error('Gagal memuat notifikasi:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchNotifications()
  }, [])

  // 2. Real-time Socket.IO Listener untuk Notifikasi Masuk
  useEffect(() => {
    const SOCKET_URL = import.meta.env.VITE_API_BASE_URL
      ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '')
      : 'http://localhost:5000'

    const socket = io(SOCKET_URL, {
      reconnectionAttempts: 10,
      reconnectionDelay: 2000,
      timeout: 5000
    })
    socketRef.current = socket

    const handleIncomingAlert = (payload) => {
      if (!payload) return
      const newNotif = {
        id: payload.id || Date.now(),
        patient_id: payload.patient_id,
        patient_name: payload.patient_name || `Pasien #${payload.patient_id || '?'}`,
        type: (payload.type || payload.status || 'alert').toLowerCase(),
        glucose_value: payload.glucose_value || payload.glucose || 0,
        message: payload.message,
        created_at: payload.created_at || new Date().toISOString(),
        isNewLive: true
      }

      setNotifs((prev) => {
        if (prev.some((n) => n.id === newNotif.id)) return prev
        return [newNotif, ...prev]
      })
    }

    socket.on('new_notification', handleIncomingAlert)
    socket.on('glucose_alert', handleIncomingAlert)

    return () => {
      socket.disconnect()
    }
  }, [])

  // 3. Kalkulasi Metrik Ringkasan (Top Cards)
  const metrics = useMemo(() => {
    const total = notifs.length
    let hiperCount = 0
    let hipoCount = 0

    notifs.forEach((n) => {
      const gVal = Number(n.glucose_value) || 0
      const typeStr = (n.type || '').toLowerCase()

      if (typeStr.includes('hiper') || gVal > 200) {
        hiperCount++
      } else if (typeStr.includes('hipo') || (gVal < 70 && gVal > 0)) {
        hipoCount++
      }
    })

    return { total, hiperCount, hipoCount }
  }, [notifs])

  // 4. Filter Notifikasi berdasarkan tab yang dipilih
  const filteredNotifs = useMemo(() => {
    return notifs.filter((n) => {
      const gVal = Number(n.glucose_value) || 0
      const typeStr = (n.type || '').toLowerCase()
      const isHiper = typeStr.includes('hiper') || gVal > 200
      const isHipo = typeStr.includes('hipo') || (gVal < 70 && gVal > 0)

      if (filterType === 'hiperglikemia') return isHiper
      if (filterType === 'hipoglikemia') return isHipo
      return true
    })
  }, [notifs, filterType])

  // 5. Aksi "Buka Monitoring" yang langsung meng-inspect spesifik per-pasien
  const handleOpenMonitoring = (notif) => {
    if (notif.patient_id) {
      sessionStorage.setItem('glucoband_paired_patient_id', String(notif.patient_id))
      navigate('/admin/monitoring', {
        state: {
          patientId: notif.patient_id,
          patient: {
            id: notif.patient_id,
            name: notif.patient_name
          }
        }
      })
    } else {
      navigate('/admin/monitoring')
    }
  }

  // Format Tanggal: "13 Nov 2026, 13.11 WIB"
  const formatDateTime = (isoString) => {
    if (!isoString) return '-'
    try {
      const d = new Date(isoString)
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des']
      const day = d.getDate()
      const month = months[d.getMonth()]
      const year = d.getFullYear()
      const hours = String(d.getHours()).padStart(2, '0')
      const minutes = String(d.getMinutes()).padStart(2, '0')
      return `${day} ${month} ${year}, ${hours}.${minutes} WIB`
    } catch {
      return isoString
    }
  }

  if (loading) {
    return (
      <div className="space-y-6">
        <div className="h-8 w-64 bg-slate-200 rounded animate-pulse" />
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-28 bg-slate-200 rounded-2xl animate-pulse" />
          ))}
        </div>
        <LoadingSkeleton rows={5} />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* HEADER UTAMA */}
      <div className="flex items-center gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">
            Notifikasi
          </h1>
          <p className="text-xs text-slate-500 mt-0.5">
            Daftar otomatis deteksi kondisi glukosa abnormal pasien (Hiperglikemia &amp; Hipoglikemia) yang terpantau secara real-time.
          </p>
        </div>
      </div>

      {/* 3 CARD RINGKASAN DI ATAS */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Card 1: TOTAL PERINGATAN */}
        <div
          onClick={() => setFilterType('all')}
          className={`bg-white rounded-2xl border p-5 shadow-sm flex items-center justify-between cursor-pointer transition hover:shadow-md ${
            filterType === 'all'
              ? 'border-indigo-400 ring-2 ring-indigo-500/20'
              : 'border-slate-100 hover:border-slate-200'
          }`}
        >
          <div>
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
              TOTAL PERINGATAN
            </span>
            <div className="text-3xl font-bold text-slate-900 mt-1">
              {metrics.total}
            </div>
            <span className="text-xs text-slate-400 mt-1 block">
              Tercatat dalam sistem
            </span>
          </div>
          <div className="w-12 h-12 rounded-xl bg-blue-50 text-blue-500 flex items-center justify-center">
            <FaBell className="text-lg" />
          </div>
        </div>

        {/* Card 2: HIPERGLIKEMIA */}
        <div
          onClick={() => setFilterType('hiperglikemia')}
          className={`bg-white rounded-2xl border p-5 shadow-sm flex items-center justify-between cursor-pointer transition hover:shadow-md ${
            filterType === 'hiperglikemia'
              ? 'border-rose-400 ring-2 ring-rose-500/20'
              : 'border-slate-100 hover:border-rose-200'
          }`}
        >
          <div>
            <span className="text-[11px] font-bold text-rose-500 uppercase tracking-wider block">
              HIPERGLIKEMIA
            </span>
            <div className="text-3xl font-bold text-rose-600 mt-1">
              {metrics.hiperCount}
            </div>
            <span className="text-xs text-rose-400 mt-1 block">
              Kadar &gt; 200 mg/dL
            </span>
          </div>
          <div className="w-12 h-12 rounded-xl bg-rose-50 text-rose-500 flex items-center justify-center">
            <FaArrowUp className="text-lg" />
          </div>
        </div>

        {/* Card 3: HIPOGLIKEMIA */}
        <div
          onClick={() => setFilterType('hipoglikemia')}
          className={`bg-white rounded-2xl border p-5 shadow-sm flex items-center justify-between cursor-pointer transition hover:shadow-md ${
            filterType === 'hipoglikemia'
              ? 'border-amber-400 ring-2 ring-amber-500/20'
              : 'border-slate-100 hover:border-amber-200'
          }`}
        >
          <div>
            <span className="text-[11px] font-bold text-amber-500 uppercase tracking-wider block">
              HIPOGLIKEMIA
            </span>
            <div className="text-3xl font-bold text-amber-500 mt-1">
              {metrics.hipoCount}
            </div>
            <span className="text-xs text-amber-400 mt-1 block">
              Kadar &lt; 70 mg/dL
            </span>
          </div>
          <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-500 flex items-center justify-center">
            <FaArrowDown className="text-lg" />
          </div>
        </div>
      </div>

      {/* FILTER PILLS KATEGORI */}
      <div className="flex items-center gap-3 pt-1">
        <button
          onClick={() => setFilterType('all')}
          className={`px-4 py-1.5 rounded-full text-xs font-semibold transition ${
            filterType === 'all'
              ? 'bg-slate-200 text-slate-800'
              : 'bg-white border border-slate-200 text-slate-500 hover:bg-slate-50'
          }`}
        >
          Semua ({metrics.total})
        </button>

        <button
          onClick={() => setFilterType('hiperglikemia')}
          className={`inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-semibold transition ${
            filterType === 'hiperglikemia'
              ? 'bg-rose-100 text-rose-700 border border-rose-300'
              : 'bg-white border border-slate-200 text-rose-600 hover:bg-rose-50'
          }`}
        >
          <span>↑</span> Hiperglikemia ({metrics.hiperCount})
        </button>

        <button
          onClick={() => setFilterType('hipoglikemia')}
          className={`inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-semibold transition ${
            filterType === 'hipoglikemia'
              ? 'bg-amber-100 text-amber-800 border border-amber-300'
              : 'bg-white border border-slate-200 text-amber-600 hover:bg-amber-50'
          }`}
        >
          <span>↓</span> Hipoglikemia ({metrics.hipoCount})
        </button>
      </div>

      {/* DAFTAR NOTIFIKASI KARTU */}
      <div className="space-y-4">
        {filteredNotifs.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-100 p-12 text-center shadow-sm">
            <div className="w-12 h-12 rounded-full bg-slate-50 text-slate-400 flex items-center justify-center mx-auto mb-3">
              <FaBell className="text-lg" />
            </div>
            <h3 className="text-sm font-bold text-slate-800">
              Tidak Ada Notifikasi
            </h3>
            <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
              Belum ada kejadian glukosa kritis yang tercatat pada kategori ini.
            </p>
          </div>
        ) : (
          filteredNotifs.map((notif) => {
            const gVal = Number(notif.glucose_value) || 0
            const typeStr = (notif.type || '').toLowerCase()
            const isHiper = typeStr.includes('hiper') || gVal > 200

            return (
              <div
                key={notif.id}
                className={`bg-white rounded-2xl border p-5 shadow-sm transition hover:shadow-md ${
                  isHiper
                    ? 'border-l-4 border-l-rose-500 border-slate-100'
                    : 'border-l-4 border-l-amber-500 border-slate-100'
                }`}
              >
                <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                  {/* Sisi Kiri: Ikon, Info Pasien, Pesan, Waktu */}
                  <div className="flex items-start gap-4 flex-1">
                    <div
                      className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ${
                        isHiper
                          ? 'bg-rose-50 text-rose-500'
                          : 'bg-amber-50 text-amber-500'
                      }`}
                    >
                      {isHiper ? (
                        <FaExclamationTriangle className="text-base" />
                      ) : (
                        <FaArrowDown className="text-base" />
                      )}
                    </div>

                    <div className="space-y-1 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-bold text-slate-900 text-base">
                          {notif.patient_name || `Pasien #${notif.patient_id}`}
                        </span>

                        <span
                          className={`px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                            isHiper
                              ? 'bg-rose-100 text-rose-700'
                              : 'bg-amber-100 text-amber-700'
                          }`}
                        >
                          {isHiper ? 'Hiperglikemia' : 'Hipoglikemia'}
                        </span>

                        {notif.isNewLive ? (
                          <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-rose-50 text-rose-600 border border-rose-200">
                            Baru
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-slate-100 text-slate-500">
                            {notif.is_read ? 'Selesai' : 'Ditindaklanjuti'}
                          </span>
                        )}
                      </div>

                      {/* Teks Pesan Medis */}
                      <p className="text-xs text-slate-600 leading-relaxed max-w-3xl">
                        {notif.message || (
                          isHiper
                            ? 'Kadar glukosa darah terdeteksi melebihi ambang batas kritis (> 200 mg/dL). Pasien disarankan memverifikasi dosis insulin dan hidrasi cairan.'
                            : 'Kadar glukosa darah berada di bawah batas normal (< 70 mg/dL). Segera berikan asupan karbohidrat cepat serap (jus buah/tablet glukosa).'
                        )}
                      </p>

                      {/* Baris Waktu */}
                      <div className="flex items-center gap-1.5 text-xs text-slate-400 pt-1">
                        <FaClock className="text-[11px] text-slate-400" />
                        <span>{formatDateTime(notif.created_at)}</span>
                      </div>
                    </div>
                  </div>

                  {/* Sisi Kanan: Kadar Glukosa & Tombol Buka Monitoring Langsung Per-Pasien */}
                  <div className="flex flex-row md:flex-col items-center md:items-end justify-between md:justify-center gap-3 pl-0 md:pl-6 border-t md:border-t-0 pt-3 md:pt-0 border-slate-100 flex-shrink-0">
                    <div className="text-left md:text-right">
                      <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">
                        KADAR GLUKOSA
                      </span>
                      <span
                        className={`text-xl md:text-2xl font-extrabold ${
                          isHiper ? 'text-rose-600' : 'text-amber-500'
                        }`}
                      >
                        {gVal > 0 ? `${gVal.toFixed(1)} mg/dL` : '-'}
                      </span>
                    </div>

                    <button
                      onClick={() => handleOpenMonitoring(notif)}
                      className="px-4 py-2 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold shadow-sm transition active:scale-95"
                    >
                      Buka Monitoring
                    </button>
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
