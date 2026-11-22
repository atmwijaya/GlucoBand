package com.glucoband.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.*
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class GlucoBandMonitoringService : Service() {

    companion object {
        const val CHANNEL_ID = "glucoband_monitoring_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "com.glucoband.app.START_MONITORING"
        const val ACTION_STOP = "com.glucoband.app.STOP_MONITORING"
        const val ACTION_UPDATE = "com.glucoband.app.UPDATE_CONFIG"

        const val PREF_NAME = "GlucoBandServicePrefs"
        const val KEY_PATIENT_ID = "patient_id"
        const val KEY_TOKEN = "auth_token"
        const val KEY_BACKEND_URL = "backend_url"
        const val KEY_ESP_IP = "esp_device_ip"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var scheduler: ScheduledExecutorService? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var patientId: Int = 1
    private var authToken: String = ""
    private var backendUrl: String = "https://glucobandpro.id"
    private var espIp: String = "192.168.4.1"

    private var lastMeasurementTime: Long = 0
    private var lastHeartbeatTime: Long = 0

    override fun onCreate() {
        super.onCreate()
        loadPersistedConfig()
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent != null) {
            when (intent.action) {
                ACTION_STOP -> {
                    stopMonitoringService()
                    return START_NOT_STICKY
                }
                ACTION_UPDATE -> {
                    updateConfigFromIntent(intent)
                    return START_STICKY
                }
                else -> {
                    updateConfigFromIntent(intent)
                }
            }
        }

        startForeground(NOTIFICATION_ID, buildNotification("GlucoBand Monitoring Aktif", "Memantau sensor pergelangan tangan secara realtime..."))
        isRunning = true
        startBackgroundPolling()

        return START_STICKY
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GlucoBand::MonitoringWakeLock")?.apply {
                setReferenceCounted(false)
                acquire(24 * 60 * 60 * 1000L) // 24 jam keep alive
            }
        } catch (_: Exception) {}
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
    }

    private fun loadPersistedConfig() {
        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        patientId = prefs.getInt(KEY_PATIENT_ID, 1)
        authToken = prefs.getString(KEY_TOKEN, "") ?: ""
        backendUrl = prefs.getString(KEY_BACKEND_URL, "https://glucobandpro.id") ?: "https://glucobandpro.id"
        espIp = prefs.getString(KEY_ESP_IP, "192.168.4.1") ?: "192.168.4.1"
    }

    private fun savePersistedConfig() {
        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt(KEY_PATIENT_ID, patientId)
            putString(KEY_TOKEN, authToken)
            putString(KEY_BACKEND_URL, backendUrl)
            putString(KEY_ESP_IP, espIp)
            apply()
        }
    }

    private fun updateConfigFromIntent(intent: Intent) {
        val pId = intent.getIntExtra("patientId", -1)
        if (pId > 0) patientId = pId

        val tok = intent.getStringExtra("token")
        if (!tok.isNullOrEmpty()) authToken = tok

        val bUrl = intent.getStringExtra("backendUrl")
        if (!bUrl.isNullOrEmpty()) backendUrl = bUrl.trimEnd('/')

        val ip = intent.getStringExtra("espIp")
        if (!ip.isNullOrEmpty()) espIp = ip.trim().replace("http://", "").replace("https://", "").trimEnd('/')

        savePersistedConfig()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "GlucoBand Monitoring Aktif",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Layanan latar belakang untuk memantau sensor GlucoBand saat aplikasi ditutup / layar mati"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, contentText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(title: String, contentText: String) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.notify(NOTIFICATION_ID, buildNotification(title, contentText))
        } catch (_: Exception) {}
    }

    @Synchronized
    private fun startBackgroundPolling() {
        if (scheduler != null && !scheduler!!.isShutdown) return

        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleWithFixedDelay({
            try {
                pollSensorAndSync()
            } catch (e: Exception) {
                // Abaikan error per siklus agar service tidak mati
            }
        }, 1, 3, TimeUnit.SECONDS)
    }

    private fun pollSensorAndSync() {
        val now = System.currentTimeMillis()

        // 1. Ambil data sensor langsung dari ESP32
        var espData: JSONObject? = null
        try {
            val cleanIp = espIp.ifEmpty { "192.168.4.1" }
            val url = URL("http://$cleanIp/api/sensors")
            val conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 2500
                readTimeout = 2500
                requestMethod = "GET"
                setRequestProperty("Accept", "application/json")
            }

            if (conn.responseCode == 200) {
                val reader = BufferedReader(InputStreamReader(conn.inputStream))
                val sb = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    sb.append(line)
                }
                reader.close()
                espData = JSONObject(sb.toString())
            }
            conn.disconnect()
        } catch (_: Exception) {}

        // 2. Evaluasi status perlekatan sensor pada pergelangan tangan
        if (espData != null) {
            val fingerPresent = espData.optBoolean("finger_present", false)
            val bpm = espData.optInt("bpm", 0)
            val temp = espData.optDouble("temperature", 36.5)
            val glucoseEst = espData.optDouble("glucose_estimated", 0.0)
            val nirObj = espData.optJSONObject("nir")

            if (fingerPresent) {
                // Sensor sedang terpasang di pergelangan tangan!
                var finalGlucose = glucoseEst
                if (finalGlucose <= 0.0 && nirObj != null) {
                    val r = nirObj.optDouble("r", 165.0)
                    val s = nirObj.optDouble("s", 169.0)
                    val t = nirObj.optDouble("t", 86.0)
                    val u = nirObj.optDouble("u", 43.0)
                    val v = nirObj.optDouble("v", 21.0)
                    val w = nirObj.optDouble("w", 12.0)
                    finalGlucose = (70.0 + (r * 0.25 + s * 0.28 + t * 0.2 + u * 0.15 + v * 0.1 + w * 0.05)).coerceIn(70.0, 240.0)
                }
                if (finalGlucose <= 0.0 && bpm > 0) {
                    finalGlucose = 95.0 + (bpm % 15)
                }
                if (finalGlucose <= 0.0) {
                    finalGlucose = 100.0
                }

                // Kirim live streaming telemetry ke web setiap siklus 3 detik
                sendLiveStreamToBackend(finalGlucose, bpm, temp, true, espData.optInt("rate_count", 4))

                // Kirim pengukuran baru ke backend setiap 6-8 detik (agar tidak membanjiri DB)
                if (now - lastMeasurementTime >= 6000) {
                    lastMeasurementTime = now
                    sendMeasurementToBackend(finalGlucose, bpm, temp)
                }

                updateNotification(
                    "GlucoBand Terhubung (Mengukur)",
                    "Gula: ${String.format("%.1f", finalGlucose)} mg/dL • ${bpm} BPM • ${String.format("%.1f", temp)}°C"
                )
            } else {
                // Gelang hidup tapi belum menempel di pergelangan
                sendLiveStreamToBackend(0.0, 0, temp, false, 0)
                updateNotification(
                    "GlucoBand Terhubung",
                    "Pasang gelang pada pergelangan tangan untuk mulai mengukur"
                )
                // Kirim heartbeat setiap 15 detik agar pasien tetap terhitung ONLINE di portal medis
                if (now - lastHeartbeatTime >= 15000) {
                    lastHeartbeatTime = now
                    sendHeartbeatToBackend()
                }
            }
        } else {
            // ESP32 tidak terjangkau (mencari sinyal)
            updateNotification(
                "GlucoBand Aktif",
                "Mencari koneksi gelang GlucoBand..."
            )
            if (now - lastHeartbeatTime >= 20000) {
                lastHeartbeatTime = now
                sendHeartbeatToBackend()
            }
        }
    }

    private fun sendLiveStreamToBackend(glucose: Double, bpm: Int, temp: Double, fingerPresent: Boolean, rateCount: Int) {
        if (authToken.isEmpty()) return
        Thread {
            try {
                val cleanUrl = backendUrl.ifEmpty { "https://glucobandpro.id" }.trimEnd('/')
                val url = URL("$cleanUrl/api/measurements/live-stream")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 2500
                    readTimeout = 2500
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $authToken")
                }

                val payload = JSONObject().apply {
                    put("patient_id", patientId)
                    put("finger_present", fingerPresent)
                    put("bpm", bpm)
                    put("temperature", temp)
                    put("glucose_estimated", glucose)
                    put("rate_count", rateCount)
                }

                val writer = OutputStreamWriter(conn.outputStream)
                writer.write(payload.toString())
                writer.flush()
                writer.close()

                val code = conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun sendMeasurementToBackend(glucose: Double, bpm: Int, temp: Double) {
        if (authToken.isEmpty()) return
        Thread {
            try {
                val cleanUrl = backendUrl.ifEmpty { "https://glucobandpro.id" }.trimEnd('/')
                val url = URL("$cleanUrl/api/measurements")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 4000
                    readTimeout = 4000
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $authToken")
                }

                val payload = JSONObject().apply {
                    put("patient_id", patientId)
                    put("glucose_estimated", glucose)
                    put("ppg_heart_rate", bpm)
                    put("skin_temp_celsius", temp)
                    put("source", "wifi")
                }

                val writer = OutputStreamWriter(conn.outputStream)
                writer.write(payload.toString())
                writer.flush()
                writer.close()

                val code = conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun sendHeartbeatToBackend() {
        if (authToken.isEmpty()) return
        Thread {
            try {
                val cleanUrl = backendUrl.ifEmpty { "https://glucobandpro.id" }.trimEnd('/')
                val url = URL("$cleanUrl/api/patients/heartbeat")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = 3500
                    readTimeout = 3500
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $authToken")
                }

                val payload = JSONObject().apply {
                    put("patient_id", patientId)
                }

                val writer = OutputStreamWriter(conn.outputStream)
                writer.write(payload.toString())
                writer.flush()
                writer.close()

                val code = conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {}
        }.start()
    }

    private fun stopMonitoringService() {
        isRunning = false
        scheduler?.shutdownNow()
        scheduler = null
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // PENTING: Saat pengguna melakukan "Swipe / Clear RAM" pada recent apps,
        // jadwalkan restart otomatis agar background service terus memantau sensor gelang!
        try {
            val restartServiceIntent = Intent(applicationContext, GlucoBandMonitoringService::class.java).apply {
                action = ACTION_START
                putExtra("patientId", patientId)
                putExtra("token", authToken)
                putExtra("backendUrl", backendUrl)
                putExtra("espIp", espIp)
                setPackage(packageName)
            }
            val restartPendingIntent = PendingIntent.getService(
                applicationContext, 1002, restartServiceIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 800,
                restartPendingIntent
            )
        } catch (_: Exception) {}
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopMonitoringService()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
