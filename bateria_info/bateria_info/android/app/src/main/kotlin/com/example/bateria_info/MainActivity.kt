package com.example.bateria_info

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.abs

class MainActivity : FlutterActivity() {

    private val canal = "bateria_info/canal"
    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "infoBateria" -> result.success(infoBateria())
                    "tienePermisoUso" -> result.success(tienePermisoUso())
                    "abrirPermisoUso" -> {
                        abrirPermisoUso(); result.success(null)
                    }
                    "abrirUsoBateria" -> {
                        abrirUsoBateria(); result.success(null)
                    }
                    "consumoApps" -> hilo.execute {
                        val datos = try { consumoApps() } catch (e: Exception) { emptyList() }
                        principal.post { result.success(datos) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ───────────── Información de la batería ─────────────

    private fun infoBateria(): Map<String, Any?> {
        val i = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

        val nivel = i?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val escala = i?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val porcentaje = if (nivel >= 0 && escala > 0) nivel * 100 / escala
            else bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

        val estado = when (i?.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "Cargando"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "Descargando"
            BatteryManager.BATTERY_STATUS_FULL -> "Carga completa"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Conectado, sin cargar"
            else -> "Desconocido"
        }

        val enchufe = i?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        val fuente = when (enchufe) {
            BatteryManager.BATTERY_PLUGGED_AC -> "Cargador de pared"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Inalámbrica"
            8 -> "Base / dock"
            else -> "Batería"
        }

        val salud = when (i?.getIntExtra(BatteryManager.EXTRA_HEALTH, -1)) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Buena"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Sobrecalentada"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Agotada"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Sobrevoltaje"
            BatteryManager.BATTERY_HEALTH_COLD -> "Fría"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Falla"
            else -> "Desconocida"
        }

        val temperatura = (i?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0) / 10.0
        val voltaje = (i?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) ?: 0) / 1000.0
        val tecnologia = i?.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)

        // Corriente: la mayoría de teléfonos la reporta en µA, algunos en mA.
        val corrienteRaw = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
        val corrienteMa: Int? = when {
            corrienteRaw == Int.MIN_VALUE || corrienteRaw == 0 -> null
            abs(corrienteRaw) > 20_000 -> corrienteRaw / 1000
            else -> corrienteRaw
        }

        val cargaRaw = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
        val cargaMah: Int? = if (cargaRaw > 0) cargaRaw / 1000 else null

        val tiempoCompletoMin: Int? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && enchufe != 0) {
                val ms = bm.computeChargeTimeRemaining()
                if (ms > 0) (ms / 60_000).toInt() else null
            } else null

        // Ciclos de carga: solo Android 14+ y si el fabricante lo expone.
        val ciclos = i?.getIntExtra("android.os.extra.CYCLE_COUNT", -1)?.takeIf { it >= 0 }

        return mapOf(
            "nivel" to porcentaje,
            "estado" to estado,
            "fuente" to fuente,
            "salud" to salud,
            "temperatura" to temperatura,
            "voltaje" to voltaje,
            "tecnologia" to tecnologia,
            "corrienteMa" to corrienteMa,
            "cargaMah" to cargaMah,
            "tiempoCompletoMin" to tiempoCompletoMin,
            "ciclos" to ciclos,
            "conectado" to (enchufe != 0),
        )
    }

    // ───────────── Permiso de uso y apps que más consumen ─────────────

    private fun tienePermisoUso(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val modo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return modo == AppOpsManager.MODE_ALLOWED
    }

    private fun abrirPermisoUso() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
        }
    }

    private fun abrirUsoBateria() {
        try {
            startActivity(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    /**
     * Android no deja que apps normales lean el % exacto de batería por app
     * (eso requiere permisos de sistema). Por eso estimamos con el tiempo en
     * pantalla + tiempo de servicios en segundo plano de las últimas 24 h.
     */
    private fun consumoApps(): List<Map<String, Any?>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val fin = System.currentTimeMillis()
        val inicio = fin - 24L * 60 * 60 * 1000
        val stats = usm.queryAndAggregateUsageStats(inicio, fin)
        val pm = packageManager

        data class Fila(val pkg: String, val nombre: String, val fg: Long, val bg: Long,
                        val peso: Double, val icono: ByteArray?)

        val filas = stats.values.mapNotNull { s ->
            if (s.packageName == packageName) return@mapNotNull null
            val fg = s.totalTimeInForeground
            val bg = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                s.totalTimeForegroundServiceUsed else 0L
            if (fg + bg < 60_000) return@mapNotNull null // menos de 1 minuto: ignorar
            val ai: ApplicationInfo = try {
                pm.getApplicationInfo(s.packageName, 0)
            } catch (e: Exception) { return@mapNotNull null }
            if (pm.getLaunchIntentForPackage(s.packageName) == null) return@mapNotNull null
            val nombre = pm.getApplicationLabel(ai).toString()
            // La pantalla encendida gasta mucho más que un servicio en segundo plano.
            val peso = fg + bg * 0.35
            Fila(s.packageName, nombre, fg, bg, peso, null)
        }.sortedByDescending { it.peso }.take(15)

        val total = filas.sumOf { it.peso }.takeIf { it > 0 } ?: 1.0

        return filas.map { f ->
            val icono = try { aPng(pm.getApplicationIcon(f.pkg)) } catch (e: Exception) { null }
            mapOf(
                "paquete" to f.pkg,
                "nombre" to f.nombre,
                "minPrimerPlano" to (f.fg / 60_000).toInt(),
                "minSegundoPlano" to (f.bg / 60_000).toInt(),
                "porcentaje" to f.peso / total * 100.0,
                "icono" to icono,
            )
        }
    }

    private fun aPng(d: Drawable): ByteArray {
        val tam = 96
        val bmp = if (d is BitmapDrawable && d.bitmap != null) {
            Bitmap.createScaledBitmap(d.bitmap, tam, tam, true)
        } else {
            val b = Bitmap.createBitmap(tam, tam, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            d.setBounds(0, 0, tam, tam)
            d.draw(c)
            b
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }
}
