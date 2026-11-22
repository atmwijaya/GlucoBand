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
  const [filterType, setFilterType] = useState('all') 
  const socketRef = useRef(null)
  const fetchNotifications = async () => {
    try {
      const { data } = await apiClient.get('/notifications?limit=100')
      if (Array.isArray(data)) {
        setNotifs(data)
      } else {
        setNotifs([])
      }
    } catch (err) {
      console.error('Gagal memuat notifikasi:', err)
      setNotifs([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchNotifications()
  }, [])

  useEffect(() => {
    const rawApiUrl = import.meta.env.VITE_API_BASE_URL
    const SOCKET_URL = rawApiUrl && rawApiUrl.startsWith('http')
      ? rawApiUrl.replace(/\/api\/?$/, '')
      : (typeof window !== 'undefined' ? window.location.origin : '')

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
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-24 bg-slate-200 rounded-xl animate-pulse" />
          ))}
        </div>
        <LoadingSkeleton rows={5} />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header Bar */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-darkNavy">Notifikasi</h1>
          <p className="text-sm text-textSecondary mt-1">
            Daftar deteksi kondisi glukosa pasien Hiperglikemia dan Hipoglikemia yang terpantau.
          </p>
        </div>
      </div>

      {/* Stats Counter Bar (3 Kartu Ringkasan Serasi dengan Halaman Tenaga Medis / Pasien) */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        {/* Card 1: Total Peringatan */}
        <div
          onClick={() => setFilterType('all')}
          className={`bg-white p-4 rounded-xl shadow-xs border transition cursor-pointer flex items-center justify-between ${
            filterType === 'all'
              ? 'border-primaryBlue/40 bg-blue-50/20 ring-1 ring-primaryBlue/20'
              : 'border-slate-100 hover:border-slate-200'
          }`}
        >
          <div>
            <p className="text-xs text-textSecondary font-medium uppercase tracking-wider">Total Peringatan</p>
            <p className="text-2xl font-bold text-darkNavy mt-1">{metrics.total}</p>
            <p className="text-[11px] text-slate-400 mt-0.5">Tercatat dalam sistem</p>
          </div>
          <div className="w-11 h-11 rounded-lg bg-blue-50 text-primaryBlue flex items-center justify-center text-lg">
            <FaBell />
          </div>
        </div>

        {/* Card 2: Hiperglikemia */}
        <div
          onClick={() => setFilterType('hiperglikemia')}
          className={`bg-white p-4 rounded-xl shadow-xs border transition cursor-pointer flex items-center justify-between ${
            filterType === 'hiperglikemia'
              ? 'border-rose-400 bg-rose-50/20 ring-1 ring-rose-400/20'
              : 'border-slate-100 hover:border-slate-200'
          }`}
        >
          <div>
            <p className="text-xs text-rose-600 font-semibold uppercase tracking-wider">Hiperglikemia</p>
            <p className="text-2xl font-bold text-rose-600 mt-1">{metrics.hiperCount}</p>
            <p className="text-[11px] text-slate-400 mt-0.5">Kadar &gt; 200 mg/dL</p>
          </div>
          <div className="w-11 h-11 rounded-lg bg-rose-50 text-rose-600 flex items-center justify-center text-lg">
            <FaArrowUp />
          </div>
        </div>

        {/* Card 3: Hipoglikemia */}
        <div
          onClick={() => setFilterType('hipoglikemia')}
          className={`bg-white p-4 rounded-xl shadow-xs border transition cursor-pointer flex items-center justify-between ${
            filterType === 'hipoglikemia'
              ? 'border-amber-400 bg-amber-50/20 ring-1 ring-amber-400/20'
              : 'border-slate-100 hover:border-slate-200'
          }`}
        >
          <div>
            <p className="text-xs text-amber-600 font-semibold uppercase tracking-wider">Hipoglikemia</p>
            <p className="text-2xl font-bold text-amber-600 mt-1">{metrics.hipoCount}</p>
            <p className="text-[11px] text-slate-400 mt-0.5">Kadar &lt; 70 mg/dL</p>
          </div>
          <div className="w-11 h-11 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center text-lg">
            <FaArrowDown />
          </div>
        </div>
      </div>

      {/* Filter Tabs & Content Container */}
      <div className="bg-white rounded-xl shadow-xs border border-slate-100 p-5 sm:p-6">
        {/* Filter Pills */}
        <div className="flex items-center gap-2 pb-5 border-b border-slate-100 overflow-x-auto">
          <button
            onClick={() => setFilterType('all')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
              filterType === 'all'
                ? 'bg-primaryBlue text-white shadow-2xs'
                : 'bg-slate-50 text-slate-600 hover:bg-slate-100 border border-slate-200/70'
            }`}
          >
            Semua ({metrics.total})
          </button>

          <button
            onClick={() => setFilterType('hiperglikemia')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
              filterType === 'hiperglikemia'
                ? 'bg-rose-600 text-white shadow-2xs'
                : 'bg-rose-50 text-rose-700 hover:bg-rose-100/80 border border-rose-200/60'
            }`}
          >
            Hiperglikemia ({metrics.hiperCount})
          </button>

          <button
            onClick={() => setFilterType('hipoglikemia')}
            className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
              filterType === 'hipoglikemia'
                ? 'bg-amber-500 text-white shadow-2xs'
                : 'bg-amber-50 text-amber-700 hover:bg-amber-100/80 border border-amber-200/60'
            }`}
          >
            Hipoglikemia ({metrics.hipoCount})
          </button>
        </div>

        {/* Daftar Notifikasi */}
        <div className="divide-y divide-slate-100">
          {filteredNotifs.length === 0 ? (
            <div className="text-center py-12">
              <FaBell className="mx-auto text-3xl text-slate-300 mb-2" />
              <p className="text-sm font-semibold text-slate-700">Tidak ada notifikasi</p>
              <p className="text-xs text-slate-400 mt-0.5">
                Belum ada data kejadian glukosa kritis pada kategori ini.
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
                  className="py-4 sm:py-5 first:pt-4 last:pb-1 flex flex-col md:flex-row md:items-center justify-between gap-4 transition hover:bg-slate-50/50 -mx-3 px-3 rounded-lg"
                >
                  {/* Info Pasien & Pesan */}
                  <div className="flex items-start gap-3.5 flex-1 min-w-0">
                    <div
                      className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5 ${
                        isHiper ? 'bg-rose-50 text-rose-600' : 'bg-amber-50 text-amber-600'
                      }`}
                    >
                      {isHiper ? (
                        <FaExclamationTriangle className="text-sm" />
                      ) : (
                        <FaArrowDown className="text-sm" />
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-semibold text-darkNavy text-sm">
                          {notif.patient_name || `Pasien #${notif.patient_id}`}
                        </span>

                        <span
                          className={`text-[11px] font-semibold px-2 py-0.5 rounded-md ${
                            isHiper
                              ? 'bg-rose-50 text-rose-700 border border-rose-200'
                              : 'bg-amber-50 text-amber-700 border border-amber-200'
                          }`}
                        >
                          {isHiper ? 'Hiperglikemia' : 'Hipoglikemia'}
                        </span>

                        {notif.isNewLive ? (
                          <span className="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-700 border border-emerald-200">
                            Baru
                          </span>
                        ) : notif.status ? (
                          <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-slate-100 text-slate-500">
                            {notif.status}
                          </span>
                        ) : null}
                      </div>

                      <p className="text-xs text-slate-600 leading-relaxed mt-1">
                        {notif.message || (
                          isHiper
                            ? 'Kadar glukosa darah terdeteksi melebihi ambang batas kritis (> 200 mg/dL). Pasien disarankan memverifikasi dosis insulin dan hidrasi cairan.'
                            : 'Kadar glukosa darah berada di bawah batas normal (< 70 mg/dL). Segera berikan asupan karbohidrat cepat serap (jus buah/tablet glukosa).'
                        )}
                      </p>

                      <div className="flex items-center gap-1.5 text-[11px] text-slate-400 mt-1.5">
                        <FaClock className="text-[10px]" />
                        <span>{formatDateTime(notif.created_at)}</span>
                      </div>
                    </div>
                  </div>

                  {/* Sisi Kanan: Kadar Glukosa & Tombol Buka Monitoring */}
                  <div className="flex md:flex-col items-center md:items-end justify-between md:justify-center gap-2 pl-12 md:pl-4 flex-shrink-0">
                    <div className="text-left md:text-right">
                      <span className="text-[10px] font-medium text-slate-400 uppercase tracking-wider block">
                        Kadar Glukosa
                      </span>
                      <span
                        className={`text-base sm:text-lg font-bold ${
                          isHiper ? 'text-rose-600' : 'text-amber-600'
                        }`}
                      >
                        {gVal > 0 ? `${gVal.toFixed(1)} mg/dL` : '-'}
                      </span>
                    </div>

                    <button
                      onClick={() => handleOpenMonitoring(notif)}
                      className="px-3.5 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 hover:border-slate-300 text-slate-700 text-xs font-semibold shadow-2xs transition active:scale-98"
                    >
                      Buka Monitoring
                    </button>
                  </div>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
