import { useState, useEffect, useMemo, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { io } from 'socket.io-client'
import {
  FaBell, FaExclamationTriangle, FaArrowUp, FaArrowDown,
  FaSearch, FaTimes, FaSyncAlt, FaHeartbeat, FaUser,
  FaClock, FaChevronRight, FaHospitalUser, FaFilter
} from 'react-icons/fa'
import apiClient from '../api/axios'
import LoadingSkeleton from '../components/common/loading'

export default function NotificationPage() {
  const navigate = useNavigate()
  const [notifs, setNotifs] = useState([])
  const [loading, setLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [filterType, setFilterType] = useState('all') // 'all' | 'hiperglikemia' | 'hipoglikemia'
  const [searchQuery, setSearchQuery] = useState('')
  const [sortBy, setSortBy] = useState('newest') // 'newest' | 'highest' | 'lowest'
  const [isSocketLive, setIsSocketLive] = useState(false)
  const socketRef = useRef(null)

  // 1. Ambil data notifikasi dari API
  const fetchNotifications = async (silent = false) => {
    if (!silent) setIsRefreshing(true)
    try {
      const { data } = await apiClient.get('/notifications?limit=100')
      if (Array.isArray(data)) {
        setNotifs(data)
      }
    } catch (err) {
      console.error('Gagal memuat notifikasi:', err)
    } finally {
      setLoading(false)
      setIsRefreshing(false)
    }
  }

  useEffect(() => {
    fetchNotifications()
  }, [])

  // 2. Real-time Socket.IO Listener untuk Notifikasi Baru
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

    socket.on('connect', () => {
      setIsSocketLive(true)
    })

    socket.on('disconnect', () => {
      setIsSocketLive(false)
    })

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
        // Hindari duplikasi jika id sudah ada
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

  // 3. Kalkulasi Metrik Ringkasan untuk Card di Atas
  const metrics = useMemo(() => {
    const total = notifs.length
    let hiperCount = 0
    let hipoCount = 0
    const uniquePatients = new Set()

    notifs.forEach((n) => {
      const gVal = Number(n.glucose_value) || 0
      const typeStr = (n.type || '').toLowerCase()

      if (typeStr.includes('hiper') || gVal > 200) {
        hiperCount++
      } else if (typeStr.includes('hipo') || (gVal < 70 && gVal > 0)) {
        hipoCount++
      }
      if (n.patient_id) uniquePatients.add(n.patient_id)
    })

    return {
      total,
      hiperCount,
      hipoCount,
      uniquePatientsCount: uniquePatients.size
    }
  }, [notifs])

  // 4. Filter & Sorting Notifikasi
  const filteredNotifs = useMemo(() => {
    return notifs
      .filter((n) => {
        const gVal = Number(n.glucose_value) || 0
        const typeStr = (n.type || '').toLowerCase()
        const isHiper = typeStr.includes('hiper') || gVal > 200
        const isHipo = typeStr.includes('hipo') || (gVal < 70 && gVal > 0)

        // Filter Tipe
        if (filterType === 'hiperglikemia' && !isHiper) return false
        if (filterType === 'hipoglikemia' && !isHipo) return false

        // Search Query
        if (searchQuery.trim()) {
          const q = searchQuery.toLowerCase().trim()
          const pName = (n.patient_name || '').toLowerCase()
          const pId = String(n.patient_id || '')
          const gStr = String(n.glucose_value || '')
          return pName.includes(q) || pId.includes(q) || gStr.includes(q)
        }

        return true
      })
      .sort((a, b) => {
        if (sortBy === 'highest') {
          return (Number(b.glucose_value) || 0) - (Number(a.glucose_value) || 0)
        }
        if (sortBy === 'lowest') {
          return (Number(a.glucose_value) || 0) - (Number(b.glucose_value) || 0)
        }
        // default newest
        return new Date(b.created_at || 0) - new Date(a.created_at || 0)
      })
  }, [notifs, filterType, searchQuery, sortBy])

  // 5. Navigasi Cepat ke Halaman Monitoring Pasien
  const handleOpenPatientMonitoring = (notif) => {
    if (notif.patient_id) {
      sessionStorage.setItem('glucoband_paired_patient_id', String(notif.patient_id))
      navigate('/admin/monitoring', {
        state: {
          patientId: notif.patient_id,
          patientName: notif.patient_name
        }
      })
    }
  }

  // Format Waktu Relatif
  const formatTimeAgo = (isoString) => {
    if (!isoString) return '-'
    try {
      const date = new Date(isoString)
      const now = new Date()
      const diffSec = Math.floor((now - date) / 1000)
      if (diffSec < 45) return 'Baru saja'
      if (diffSec < 3600) return `${Math.floor(diffSec / 60)} menit yang lalu`
      if (diffSec < 86400) return `${Math.floor(diffSec / 3600)} jam yang lalu`
      return date.toLocaleDateString('id-ID', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    } catch {
      return isoString
    }
  }

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto space-y-6">
        <div className="h-8 w-64 bg-slate-200 rounded animate-pulse" />
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-28 bg-slate-200 rounded-xl animate-pulse" />
          ))}
        </div>
        <LoadingSkeleton rows={6} />
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* HEADER UTAMA */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
              Peringatan Klinis Glukosa
            </h1>
            <span
              className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                isSocketLive
                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                  : 'bg-slate-100 text-slate-600 border border-slate-200'
              }`}
            >
              <span
                className={`w-2 h-2 rounded-full ${
                  isSocketLive ? 'bg-emerald-500 animate-pulse' : 'bg-slate-400'
                }`}
              />
              {isSocketLive ? 'Live Streaming' : 'Offline'}
            </span>
          </div>
          <p className="text-sm text-slate-500 mt-1">
            Pemantauan insiden glukosa kritis pasien secara terpusat untuk tindakan medis cepat.
          </p>
        </div>

        <button
          onClick={() => fetchNotifications(false)}
          disabled={isRefreshing}
          className="inline-flex items-center justify-center gap-2 px-4 py-2.5 text-xs font-semibold rounded-lg bg-white border border-slate-200 text-slate-700 hover:bg-slate-50 shadow-sm transition active:scale-95 disabled:opacity-60"
        >
          <FaSyncAlt className={`text-slate-500 ${isRefreshing ? 'animate-spin' : ''}`} />
          Segarkan Data
        </button>
      </div>

      {/* METRIC CARDS DI ATAS (INTERAKTIF SEBAGAI QUICK FILTER) */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Total Peringatan */}
        <div
          onClick={() => setFilterType('all')}
          className={`cursor-pointer bg-white p-5 rounded-xl border transition-all duration-200 ${
            filterType === 'all'
              ? 'border-indigo-600 shadow-md ring-2 ring-indigo-500/20'
              : 'border-slate-200 hover:border-slate-300 shadow-sm'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Total Peringatan
            </span>
            <div className="w-9 h-9 rounded-lg bg-indigo-50 text-indigo-600 flex items-center justify-center">
              <FaBell className="text-sm" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-extrabold text-slate-900">{metrics.total}</span>
            <span className="text-xs text-slate-500 font-medium">kejadian</span>
          </div>
          <div className="mt-2 text-xs text-slate-400 flex items-center justify-between">
            <span>Semua riwayat terdata</span>
            {filterType === 'all' && (
              <span className="text-indigo-600 font-bold">Filter Aktif</span>
            )}
          </div>
        </div>

        {/* Card 2: Hiperglikemia */}
        <div
          onClick={() => setFilterType('hiperglikemia')}
          className={`cursor-pointer bg-white p-5 rounded-xl border transition-all duration-200 ${
            filterType === 'hiperglikemia'
              ? 'border-rose-600 shadow-md ring-2 ring-rose-500/20'
              : 'border-slate-200 hover:border-rose-300 shadow-sm'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-rose-600 uppercase tracking-wider flex items-center gap-1.5">
              <FaArrowUp className="text-xs" /> Hiperglikemia
            </span>
            <div className="w-9 h-9 rounded-lg bg-rose-50 text-rose-600 flex items-center justify-center">
              <FaExclamationTriangle className="text-sm" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-extrabold text-rose-600">{metrics.hiperCount}</span>
            <span className="text-xs text-slate-500 font-medium">&gt; 200 mg/dL</span>
          </div>
          <div className="mt-2 text-xs text-slate-400 flex items-center justify-between">
            <span>Risiko krisis hiperglikemik</span>
            {filterType === 'hiperglikemia' && (
              <span className="text-rose-600 font-bold">Filter Aktif</span>
            )}
          </div>
        </div>

        {/* Card 3: Hipoglikemia */}
        <div
          onClick={() => setFilterType('hipoglikemia')}
          className={`cursor-pointer bg-white p-5 rounded-xl border transition-all duration-200 ${
            filterType === 'hipoglikemia'
              ? 'border-amber-500 shadow-md ring-2 ring-amber-500/20'
              : 'border-slate-200 hover:border-amber-300 shadow-sm'
          }`}
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-amber-600 uppercase tracking-wider flex items-center gap-1.5">
              <FaArrowDown className="text-xs" /> Hipoglikemia
            </span>
            <div className="w-9 h-9 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center">
              <FaExclamationTriangle className="text-sm" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-extrabold text-amber-600">{metrics.hipoCount}</span>
            <span className="text-xs text-slate-500 font-medium">&lt; 70 mg/dL</span>
          </div>
          <div className="mt-2 text-xs text-slate-400 flex items-center justify-between">
            <span>Risiko syok &amp; penurunan kesadaran</span>
            {filterType === 'hipoglikemia' && (
              <span className="text-amber-600 font-bold">Filter Aktif</span>
            )}
          </div>
        </div>

        {/* Card 4: Pasien Berbeda */}
        <div
          onClick={() => {
            setFilterType('all')
            setSearchQuery('')
          }}
          className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm transition hover:border-slate-300 cursor-pointer"
        >
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wider">
              Pasien Terdampak
            </span>
            <div className="w-9 h-9 rounded-lg bg-violet-50 text-violet-600 flex items-center justify-center">
              <FaHospitalUser className="text-sm" />
            </div>
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-3xl font-extrabold text-slate-900">{metrics.uniquePatientsCount}</span>
            <span className="text-xs text-slate-500 font-medium">individu</span>
          </div>
          <div className="mt-2 text-xs text-slate-400 flex items-center justify-between">
            <span>Memerlukan tindak lanjut</span>
            <span className="text-slate-400 font-medium">Klik untuk reset</span>
          </div>
        </div>
      </div>

      {/* FILTER & SEARCH TOOLBAR */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        {/* Tab Filter Kategori */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 md:pb-0">
          <button
            onClick={() => setFilterType('all')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition ${
              filterType === 'all'
                ? 'bg-slate-900 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            Semua ({metrics.total})
          </button>
          <button
            onClick={() => setFilterType('hiperglikemia')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition inline-flex items-center gap-1.5 ${
              filterType === 'hiperglikemia'
                ? 'bg-rose-600 text-white shadow-sm'
                : 'bg-rose-50 text-rose-700 hover:bg-rose-100'
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-rose-500" />
            Hiperglikemia ({metrics.hiperCount})
          </button>
          <button
            onClick={() => setFilterType('hipoglikemia')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition inline-flex items-center gap-1.5 ${
              filterType === 'hipoglikemia'
                ? 'bg-amber-600 text-white shadow-sm'
                : 'bg-amber-50 text-amber-700 hover:bg-amber-100'
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />
            Hipoglikemia ({metrics.hipoCount})
          </button>
        </div>

        {/* Search & Sort Controls */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2.5">
          {/* Input Search */}
          <div className="relative flex-1 sm:w-64">
            <FaSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xs" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Cari pasien / nilai gula..."
              className="w-full pl-8 pr-8 py-1.5 text-xs rounded-lg border border-slate-200 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
              >
                <FaTimes className="text-xs" />
              </button>
            )}
          </div>

          {/* Dropdown Sorting */}
          <div className="flex items-center gap-1.5 text-xs text-slate-500">
            <FaFilter className="text-slate-400" />
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="py-1.5 px-2 rounded-lg border border-slate-200 text-xs text-slate-700 bg-white focus:outline-none focus:border-indigo-500"
            >
              <option value="newest">Waktu Terbaru</option>
              <option value="highest">Gula Tertinggi</option>
              <option value="lowest">Gula Terendah</option>
            </select>
          </div>
        </div>
      </div>

      {/* DAFTAR KARTU NOTIFIKASI INTERAKTIF */}
      <div className="space-y-3">
        {filteredNotifs.length === 0 ? (
          <div className="bg-white rounded-xl border border-slate-200 p-12 text-center shadow-sm">
            <div className="w-14 h-14 rounded-full bg-slate-50 text-slate-400 flex items-center justify-center mx-auto mb-3">
              <FaBell className="text-xl" />
            </div>
            <h3 className="text-base font-bold text-slate-800">
              Tidak Ada Notifikasi yang Cocok
            </h3>
            <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
              {searchQuery
                ? `Tidak ditemukan hasil pencarian untuk "${searchQuery}". Coba kata kunci lain.`
                : 'Belum ada kejadian glukosa kritis yang tercatat pada kategori ini.'}
            </p>
            {(filterType !== 'all' || searchQuery) && (
              <button
                onClick={() => {
                  setFilterType('all')
                  setSearchQuery('')
                }}
                className="mt-4 px-4 py-1.5 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition"
              >
                Reset Semua Filter
              </button>
            )}
          </div>
        ) : (
          filteredNotifs.map((notif) => {
            const gVal = Number(notif.glucose_value) || 0
            const typeStr = (notif.type || '').toLowerCase()
            const isHiper = typeStr.includes('hiper') || gVal > 200

            return (
              <div
                key={notif.id}
                className={`bg-white rounded-xl border p-4 sm:p-5 shadow-sm transition hover:shadow-md flex flex-col md:flex-row md:items-center md:justify-between gap-4 ${
                  isHiper
                    ? 'border-l-4 border-l-rose-500 border-slate-200'
                    : 'border-l-4 border-l-amber-500 border-slate-200'
                } ${notif.isNewLive ? 'bg-amber-50/20' : ''}`}
              >
                {/* Kolom Info Pasien & Status */}
                <div className="flex items-start gap-3.5">
                  <div
                    className={`w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ${
                      isHiper
                        ? 'bg-rose-50 text-rose-600 border border-rose-100'
                        : 'bg-amber-50 text-amber-600 border border-amber-100'
                    }`}
                  >
                    {isHiper ? (
                      <FaArrowUp className="text-lg" />
                    ) : (
                      <FaArrowDown className="text-lg" />
                    )}
                  </div>

                  <div className="space-y-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-bold text-slate-900 text-sm sm:text-base">
                        {notif.patient_name || `Pasien #${notif.patient_id}`}
                      </span>

                      {notif.patient_id && (
                        <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-slate-100 text-slate-600">
                          ID: #{notif.patient_id}
                        </span>
                      )}

                      <span
                        className={`px-2.5 py-0.5 rounded-full text-xs font-bold ${
                          isHiper
                            ? 'bg-rose-100 text-rose-800'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {isHiper ? 'Hiperglikemia' : 'Hipoglikemia'}
                      </span>

                      {notif.isNewLive && (
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-600 text-white animate-pulse">
                          BARU
                        </span>
                      )}
                    </div>

                    {/* Catatan Klinis / Pesan */}
                    <p className="text-xs text-slate-600 leading-relaxed">
                      {notif.message || (
                        isHiper
                          ? 'Kadar glukosa melebihi ambang 200 mg/dL. Evaluasi kepatuhan terapi insulin / hidrasi pasien.'
                          : 'Kadar glukosa di bawah 70 mg/dL. Berikan sumber glukosa cepat serap untuk mencegah syok.'
                      )}
                    </p>

                    <div className="flex items-center gap-3 text-[11px] text-slate-400 pt-1">
                      <span className="flex items-center gap-1">
                        <FaClock className="text-[10px]" />
                        {formatTimeAgo(notif.created_at)}
                      </span>
                      <span>•</span>
                      <span>{new Date(notif.created_at).toLocaleString('id-ID')}</span>
                    </div>
                  </div>
                </div>

                {/* Kolom Glukosa & Aksi Medis */}
                <div className="flex items-center justify-between md:justify-end gap-5 border-t md:border-t-0 pt-3 md:pt-0 border-slate-100">
                  <div className="text-left md:text-right">
                    <div className="flex items-baseline md:justify-end gap-1">
                      <span
                        className={`text-2xl sm:text-3xl font-extrabold ${
                          isHiper ? 'text-rose-600' : 'text-amber-600'
                        }`}
                      >
                        {gVal.toFixed(0)}
                      </span>
                      <span className="text-xs font-semibold text-slate-400">mg/dL</span>
                    </div>
                    <span className="text-[11px] text-slate-400 font-medium block">
                      Estimasi Non-Invasif
                    </span>
                  </div>

                  {notif.patient_id && (
                    <button
                      onClick={() => handleOpenPatientMonitoring(notif)}
                      className="inline-flex items-center gap-2 px-3.5 py-2 text-xs font-bold rounded-lg bg-indigo-50 text-indigo-700 hover:bg-indigo-600 hover:text-white transition shadow-sm active:scale-95 group"
                    >
                      <FaHeartbeat className="text-sm group-hover:scale-110 transition" />
                      <span>Buka Monitoring</span>
                      <FaChevronRight className="text-[10px] opacity-70" />
                    </button>
                  )}
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
