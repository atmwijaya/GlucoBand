package com.glucoband.app

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.glucoband.app/system"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWifiSettings") {
                try {
                    // Coba buka panel internet jika didukung (string action aman untuk seluruh versi SDK Android)
                    val panelIntent = Intent("android.settings.panel.action.INTERNET")
                    panelIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    if (packageManager != null && panelIntent.resolveActivity(packageManager) != null) {
                        startActivity(panelIntent)
                    } else {
                        val wifiIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        wifiIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(wifiIntent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val fallbackIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(fallbackIntent)
                        result.success(true)
                    } catch (e2: Exception) {
                        result.error("ERROR", e2.message, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
