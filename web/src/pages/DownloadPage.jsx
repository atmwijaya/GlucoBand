import { useState } from 'react'
import { FaAndroid, FaDownload, FaCheckCircle } from 'react-icons/fa'
import logoImg from '../assets/android-chrome-512x512.png'

export default function DownloadPage() {
  const [hasDownloaded, setHasDownloaded] = useState(false)
  const apkDownloadUrl = '/download/glucoband.apk'

  const handleDownload = () => {
    setHasDownloaded(true)
    const link = document.createElement('a')
    link.href = apkDownloadUrl
    link.setAttribute('download', 'glucoband.apk')
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col font-sans">
      {/* Header */}
      <header className="bg-white border-b border-slate-200">
        <div className="max-w-4xl mx-auto px-6 h-16 flex items-center">
          <div className="flex items-center gap-3">
            <img
              src={logoImg}
              alt="GlucoBand Logo"
              className="w-9 h-9 object-contain rounded-lg"
            />
            <span className="text-xl font-bold text-slate-900 tracking-tight">
              GlucoBand
            </span>
          </div>
        </div>
      </header>

      {/* Konten Utama */}
      <main className="flex-1 max-w-2xl mx-auto w-full px-6 py-12 flex flex-col justify-center">
        {/* Kartu Unduh */}
        <div className="bg-white rounded-xl border border-slate-200 p-8 shadow-sm text-center">
          <div className="w-20 h-20 mx-auto mb-5 rounded-2xl bg-slate-100 p-3 flex items-center justify-center border border-slate-200">
            <img
              src={logoImg}
              alt="GlucoBand"
              className="w-full h-full object-contain"
            />
          </div>

          <h1 className="text-2xl font-bold text-slate-900 mb-2">
            Unduh GlucoBand untuk Android
          </h1>
          <p className="text-sm text-slate-600 mb-8 max-w-md mx-auto leading-relaxed">
            Aplikasi pemantauan kadar glukosa darah dan riwayat kesehatan untuk pengguna perangkat gelang pintar GlucoBand.
          </p>

          {/* Tombol Unduh Utama */}
          <button
            onClick={handleDownload}
            className="w-full sm:w-auto inline-flex items-center justify-center gap-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold px-8 py-3.5 rounded-lg transition shadow-sm cursor-pointer"
          >
            <FaAndroid className="text-xl" />
            <span>Unduh APK (v1.0.2)</span>
            <FaDownload className="text-sm opacity-80" />
          </button>

          {/* Keterangan Berkas */}
          <div className="mt-4 text-xs text-slate-500 flex items-center justify-center gap-4">
            <span>Ukuran: <strong>53 MB</strong></span>
            <span>•</span>
            <span>OS: <strong>Android 8.0 ke atas</strong></span>
            <span>•</span>
            <span>Format: <strong>.apk</strong></span>
          </div>

          {/* Notifikasi setelah tombol diklik */}
          {hasDownloaded && (
            <div className="mt-6 p-3 bg-green-50 border border-green-200 rounded-lg text-xs text-green-800 flex items-center justify-center gap-2 text-left">
              <FaCheckCircle className="text-green-600 shrink-0 text-sm" />
              <span>
                Unduhan sedang diproses. Silakan cek panel notifikasi ponsel atau folder <strong>Download</strong> Anda.
              </span>
            </div>
          )}
        </div>

        {/* Petunjuk Instalasi Singkat */}
        <div className="mt-8 bg-white rounded-xl border border-slate-200 p-6 shadow-sm">
          <h2 className="text-sm font-bold text-slate-900 mb-4 uppercase tracking-wide text-slate-500">
            Cara Memasang di Ponsel
          </h2>

          <ol className="space-y-4 text-sm text-slate-700">
            <li className="flex items-start gap-3">
              <span className="w-6 h-6 rounded-full bg-slate-100 text-slate-700 font-bold flex items-center justify-center shrink-0 text-xs">
                1
              </span>
              <div>
                <strong>Unduh APK</strong>
                <p className="text-xs text-slate-500 mt-0.5">
                  Klik tombol unduh di atas dan tunggu file <code>glucoband.apk</code> selesai terunduh.
                </p>
              </div>
            </li>

            <li className="flex items-start gap-3">
              <span className="w-6 h-6 rounded-full bg-slate-100 text-slate-700 font-bold flex items-center justify-center shrink-0 text-xs">
                2
              </span>
              <div>
                <strong>Buka Berkas</strong>
                <p className="text-xs text-slate-500 mt-0.5">
                  Buka file hasil unduhan melalui bilah notifikasi atau melalui aplikasi <strong>Pengelola File</strong> &gt; folder <strong>Download</strong>.
                </p>
              </div>
            </li>

            <li className="flex items-start gap-3">
              <span className="w-6 h-6 rounded-full bg-slate-100 text-slate-700 font-bold flex items-center justify-center shrink-0 text-xs">
                3
              </span>
              <div>
                <strong>Konfirmasi Pemasangan</strong>
                <p className="text-xs text-slate-500 mt-0.5">
                  Jika muncul pemberitahuan keamanan (Play Protect / Sumber Tidak Dikenal), klik <strong>Detail Selengkapnya</strong> lalu pilih <strong>Tetap Instal</strong>.
                </p>
              </div>
            </li>
          </ol>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-200 py-6 text-center text-xs text-slate-500">
        © 2026 GlucoBand
      </footer>
    </div>
  )
}
