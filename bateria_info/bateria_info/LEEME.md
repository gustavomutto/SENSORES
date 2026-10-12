# Mi Batería — app Flutter (Android)

## Qué hace
- Muestra nivel, estado, salud, temperatura, voltaje, corriente (mA), carga en mAh,
  tecnología, tipo de cargador, tiempo para carga completa y ciclos (Android 14+).
- Al conectar el cargador aparece una animación a pantalla completa: batería que se
  llena con ola y burbujas, rayo pulsante y porcentaje subiendo.
  (El botón ▶ arriba a la derecha la muestra cuando quieras para probarla.)
- Lista de las 15 apps que más gastan en las últimas 24 h, con icono y barra de %.

## Cómo instalarla en tu teléfono

1. Crear en el escritorio una carpeta llamada bateria_info
   ```
   flutter create --platforms=android bateria_info
   ```
2. Reemplaza estos 3 archivos con los de este zip:
   - `lib/main.dart`
   - `android/app/src/main/AndroidManifest.xml`
   - `android/app/src/main/kotlin/com/example/bateria_info/MainActivity.kt`
3. En el teléfono: Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación".
   Luego en Opciones de desarrollador activa **Depuración USB**.
4. Conecta el teléfono por USB y ejecuta:
   ```
   flutter run
   ```
   o para generar el APK e instalarlo a mano:
   ```
   flutter build apk --release
   ```
   (queda en `build/app/outputs/flutter-apk/app-release.apk`)
5. Abre la app → "Dar permiso" → busca **Mi Batería** y activa
   "Permitir acceso a datos de uso". Vuelve a la app y aparecerá la lista.

## Importante sobre "apps que consumen energía"
Android no permite que una app normal lea el % exacto de batería de cada app
(solo apps del sistema). Por eso la lista es una **estimación** basada en el tiempo
en pantalla y en segundo plano. El botón "Ver consumo exacto en Ajustes" abre la
pantalla oficial del sistema con los datos reales.

La animación de carga aparece cuando la app está abierta. En iPhone esto no funciona:
iOS no expone estos datos.
 gustavo jose mutto aguilar