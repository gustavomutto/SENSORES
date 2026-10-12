import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const BateriaApp());

class BateriaApp extends StatelessWidget {
  const BateriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Batería',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.greenAccent,
        scaffoldBackgroundColor: const Color(0xFF0E1116),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

// ─────────────────────────── Modelos ───────────────────────────

class InfoBateria {
  final int nivel;
  final String estado;
  final String fuente;
  final String salud;
  final double temperatura;
  final double voltaje;
  final String tecnologia;
  final int? corrienteMa;
  final int? cargaMah;
  final int? tiempoCompletoMin;
  final int? ciclos;
  final bool conectado;

  InfoBateria({
    required this.nivel,
    required this.estado,
    required this.fuente,
    required this.salud,
    required this.temperatura,
    required this.voltaje,
    required this.tecnologia,
    required this.corrienteMa,
    required this.cargaMah,
    required this.tiempoCompletoMin,
    required this.ciclos,
    required this.conectado,
  });

  factory InfoBateria.fromMap(Map<String, dynamic> m) => InfoBateria(
        nivel: (m['nivel'] as num).toInt(),
        estado: m['estado'] as String,
        fuente: m['fuente'] as String,
        salud: m['salud'] as String,
        temperatura: (m['temperatura'] as num).toDouble(),
        voltaje: (m['voltaje'] as num).toDouble(),
        tecnologia: (m['tecnologia'] as String?) ?? '—',
        corrienteMa: (m['corrienteMa'] as num?)?.toInt(),
        cargaMah: (m['cargaMah'] as num?)?.toInt(),
        tiempoCompletoMin: (m['tiempoCompletoMin'] as num?)?.toInt(),
        ciclos: (m['ciclos'] as num?)?.toInt(),
        conectado: m['conectado'] as bool,
      );
}

class ConsumoApp {
  final String paquete;
  final String nombre;
  final int minPrimerPlano;
  final int minSegundoPlano;
  final double porcentaje;
  final Uint8List? icono;

  ConsumoApp({
    required this.paquete,
    required this.nombre,
    required this.minPrimerPlano,
    required this.minSegundoPlano,
    required this.porcentaje,
    required this.icono,
  });

  factory ConsumoApp.fromMap(Map<String, dynamic> m) => ConsumoApp(
        paquete: m['paquete'] as String,
        nombre: m['nombre'] as String,
        minPrimerPlano: (m['minPrimerPlano'] as num).toInt(),
        minSegundoPlano: (m['minSegundoPlano'] as num).toInt(),
        porcentaje: (m['porcentaje'] as num).toDouble(),
        icono: m['icono'] as Uint8List?,
      );
}

// ─────────────── Comunicación con Android (Kotlin) ───────────────

class BateriaServicio {
  static const _canal = MethodChannel('bateria_info/canal');

  static Future<InfoBateria> info() async {
    final m = await _canal.invokeMethod('infoBateria');
    return InfoBateria.fromMap(Map<String, dynamic>.from(m as Map));
  }

  static Future<bool> tienePermisoUso() async =>
      await _canal.invokeMethod<bool>('tienePermisoUso') ?? false;

  static Future<void> abrirPermisoUso() => _canal.invokeMethod('abrirPermisoUso');

  static Future<void> abrirUsoBateria() => _canal.invokeMethod('abrirUsoBateria');

  static Future<List<ConsumoApp>> consumoApps() async {
    final lista = await _canal.invokeMethod<List<dynamic>>('consumoApps') ?? [];
    return lista
        .map((e) => ConsumoApp.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

// ─────────────────────────── Pantalla ───────────────────────────

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal>
    with WidgetsBindingObserver {
  InfoBateria? _info;
  bool? _conectadoAntes;
  bool _animacionVisible = false;
  Timer? _timer;

  bool _permisoUso = false;
  bool _cargandoApps = false;
  List<ConsumoApp> _apps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actualizar();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _actualizar());
    _cargarApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes (por si se dio el permiso), recargamos las apps.
    if (state == AppLifecycleState.resumed) {
      _actualizar();
      _cargarApps();
    }
  }

  Future<void> _actualizar() async {
    try {
      final info = await BateriaServicio.info();
      if (!mounted) return;
      // Se acaba de conectar el cargador → mostrar animación
      if (_conectadoAntes == false && info.conectado) {
        _mostrarAnimacionCarga(info);
      }
      _conectadoAntes = info.conectado;
      setState(() => _info = info);
    } catch (_) {}
  }

  Future<void> _cargarApps() async {
    final permiso = await BateriaServicio.tienePermisoUso();
    if (!mounted) return;
    setState(() {
      _permisoUso = permiso;
      _cargandoApps = permiso;
    });
    if (!permiso) return;
    final apps = await BateriaServicio.consumoApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _cargandoApps = false;
    });
  }

  Future<void> _mostrarAnimacionCarga(InfoBateria info) async {
    if (_animacionVisible) return;
    _animacionVisible = true;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'carga',
      barrierColor: Colors.black.withAlpha(235),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) =>
          AnimacionCarga(nivel: info.nivel, fuente: info.fuente),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
    _animacionVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Batería'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Probar animación de carga',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: info == null ? null : () => _mostrarAnimacionCarga(info),
          ),
        ],
      ),
      body: info == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _actualizar();
                await _cargarApps();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _Encabezado(info: info),
                  const SizedBox(height: 24),
                  _TituloSeccion('Detalles'),
                  _GridDetalles(info: info),
                  const SizedBox(height: 24),
                  _TituloSeccion('Apps que más consumen (24 h)'),
                  _seccionApps(),
                ],
              ),
            ),
    );
  }

  Widget _seccionApps() {
    if (!_permisoUso) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para ver qué apps gastan más batería necesito el permiso '
                '"Acceso a datos de uso". Busca "Mi Batería" en la lista y actívalo.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: BateriaServicio.abrirPermisoUso,
                icon: const Icon(Icons.lock_open),
                label: const Text('Dar permiso'),
              ),
            ],
          ),
        ),
      );
    }
    if (_cargandoApps) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estimado según el tiempo de uso en pantalla y en segundo plano.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        if (_apps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aún no hay datos de uso.'),
          ),
        ..._apps.map((a) => _FilaApp(app: a)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: BateriaServicio.abrirUsoBateria,
          icon: const Icon(Icons.settings),
          label: const Text('Ver consumo exacto en Ajustes'),
        ),
      ],
    );
  }
}

// ─────────────────────────── Widgets ───────────────────────────

Color colorNivel(int nivel) {
  if (nivel <= 20) return Colors.redAccent;
  if (nivel <= 50) return Colors.amber;
  return Colors.greenAccent;
}

String fmtMin(int m) => m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';

class _Encabezado extends StatelessWidget {
  final InfoBateria info;
  const _Encabezado({required this.info});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BateriaAnimada(
          nivel: info.nivel.toDouble(),
          cargando: info.conectado,
          ancho: 110,
          alto: 190,
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${info.nivel}%',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: colorNivel(info.nivel),
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(info.conectado ? Icons.bolt : Icons.battery_std,
                    size: 20, color: Colors.white70),
                const SizedBox(width: 4),
                Text(info.estado, style: const TextStyle(fontSize: 18)),
              ]),
              if (info.conectado) ...[
                const SizedBox(height: 4),
                Text(info.fuente, style: const TextStyle(color: Colors.white60)),
              ],
              if (info.conectado && info.tiempoCompletoMin != null) ...[
                const SizedBox(height: 4),
                Text('Llena en ~${fmtMin(info.tiempoCompletoMin!)}',
                    style: const TextStyle(color: Colors.white60)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );
}

class _GridDetalles extends StatelessWidget {
  final InfoBateria info;
  const _GridDetalles({required this.info});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.favorite, 'Salud', info.salud),
      (Icons.thermostat, 'Temperatura', '${info.temperatura.toStringAsFixed(1)} °C'),
      (Icons.electric_bolt, 'Voltaje', '${info.voltaje.toStringAsFixed(2)} V'),
      (Icons.speed, 'Corriente',
          info.corrienteMa == null ? '—' : '${info.corrienteMa} mA'),
      (Icons.battery_charging_full, 'Carga actual',
          info.cargaMah == null ? '—' : '${info.cargaMah} mAh'),
      (Icons.power, 'Fuente', info.fuente),
      (Icons.memory, 'Tecnología', info.tecnologia),
      (Icons.loop, 'Ciclos de carga',
          info.ciclos == null ? 'No disponible' : '${info.ciclos}'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        for (final (icono, titulo, valor) in items)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF181C23),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icono, color: Colors.greenAccent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 2),
                      Text(valor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FilaApp extends StatelessWidget {
  final ConsumoApp app;
  const _FilaApp({required this.app});

  @override
  Widget build(BuildContext context) {
    final pct = app.porcentaje;
    final color = pct >= 25
        ? Colors.redAccent
        : pct >= 10
            ? Colors.amber
            : Colors.greenAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF181C23),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: app.icono != null
                ? Image.memory(app.icono!, width: 40, height: 40)
                : const Icon(Icons.android, size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    color: color,
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pantalla ${fmtMin(app.minPrimerPlano)}'
                  '${app.minSegundoPlano > 0 ? ' · Segundo plano ${fmtMin(app.minSegundoPlano)}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ───────────────── Animación de pantalla completa al cargar ─────────────────

class AnimacionCarga extends StatefulWidget {
  final int nivel;
  final String fuente;
  const AnimacionCarga({super.key, required this.nivel, required this.fuente});

  @override
  State<AnimacionCarga> createState() => _AnimacionCargaState();
}

class _AnimacionCargaState extends State<AnimacionCarga> {
  Timer? _cerrar;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _cerrar = Timer(const Duration(milliseconds: 4500), _salir);
  }

  void _salir() {
    _cerrar?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _cerrar?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _salir,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: widget.nivel.toDouble()),
            duration: const Duration(milliseconds: 2200),
            curve: Curves.easeOutCubic,
            builder: (_, valor, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BateriaAnimada(
                  nivel: valor,
                  cargando: true,
                  ancho: 160,
                  alto: 290,
                  brillo: true,
                ),
                const SizedBox(height: 28),
                Text(
                  '${valor.round()}%',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: colorNivel(valor.round()),
                  ),
                ),
                const _TextoPulsante('Cargando…'),
                const SizedBox(height: 6),
                Text(widget.fuente, style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextoPulsante extends StatefulWidget {
  final String texto;
  const _TextoPulsante(this.texto);

  @override
  State<_TextoPulsante> createState() => _TextoPulsanteState();
}

class _TextoPulsanteState extends State<_TextoPulsante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Text(widget.texto,
            style: const TextStyle(fontSize: 20, letterSpacing: 1.2)),
      );
}

// ─────────────────────── Batería dibujada a mano ───────────────────────

class BateriaAnimada extends StatefulWidget {
  final double nivel; // 0..100
  final bool cargando;
  final double ancho;
  final double alto;
  final bool brillo;

  const BateriaAnimada({
    super.key,
    required this.nivel,
    required this.cargando,
    this.ancho = 100,
    this.alto = 180,
    this.brillo = false,
  });

  @override
  State<BateriaAnimada> createState() => _BateriaAnimadaState();
}

class _BateriaAnimadaState extends State<BateriaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorNivel(widget.nivel.round());
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final pulso = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
        return Container(
          decoration: widget.brillo && widget.cargando
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.ancho * 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha((60 + 80 * pulso).round()),
                      blurRadius: 40 + 20 * pulso,
                      spreadRadius: 4,
                    ),
                  ],
                )
              : null,
          child: SizedBox(
            width: widget.ancho,
            height: widget.alto,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.ancho, widget.alto),
                  painter: _PintorBateria(
                    nivel: (widget.nivel / 100).clamp(0.0, 1.0),
                    fase: _c.value,
                    cargando: widget.cargando,
                    color: color,
                  ),
                ),
                if (widget.cargando)
                  Transform.scale(
                    scale: 0.9 + 0.15 * pulso,
                    child: Icon(
                      Icons.bolt,
                      size: widget.ancho * 0.55,
                      color: Colors.white.withAlpha(230),
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PintorBateria extends CustomPainter {
  final double nivel; // 0..1
  final double fase; // 0..1
  final bool cargando;
  final Color color;

  _PintorBateria({
    required this.nivel,
    required this.fase,
    required this.cargando,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final capH = size.height * 0.06;
    final capW = size.width * 0.38;
    final cuerpo = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, capH, size.width, size.height - capH),
      Radius.circular(size.width * 0.16),
    );
    final tapa = RRect.fromRectAndRadius(
      Rect.fromLTWH((size.width - capW) / 2, 0, capW, capH + 2),
      Radius.circular(capH / 2),
    );
    canvas.drawRRect(tapa, Paint()..color = Colors.white70);

    final pad = size.width * 0.08;
    final interior = RRect.fromRectAndRadius(
      cuerpo.outerRect.deflate(pad),
      Radius.circular(size.width * 0.09),
    );
    final r = interior.outerRect;

    canvas.save();
    canvas.clipRRect(interior);
    canvas.drawRect(r, Paint()..color = Colors.white10);

    final topY = r.bottom - r.height * nivel;
    final path = Path();
    if (cargando && nivel > 0) {
      final amp = r.height * 0.022;
      path.moveTo(r.left, r.bottom);
      for (double x = r.left; x <= r.right + 2; x += 2) {
        final y = topY +
            math.sin((x - r.left) / r.width * 3 * math.pi + fase * 2 * math.pi) *
                amp;
        path.lineTo(x, y);
      }
      path.lineTo(r.right, r.bottom);
      path.close();
    } else {
      path.addRect(Rect.fromLTRB(r.left, topY, r.right, r.bottom));
    }

    final gradiente = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [color, Color.lerp(color, Colors.white, 0.35)!],
    ).createShader(r);
    canvas.drawPath(path, Paint()..shader = gradiente);

    // Burbujas que suben mientras carga
    if (cargando && nivel > 0.05) {
      for (int i = 0; i < 7; i++) {
        final progreso = (fase + i / 7) % 1.0;
        final x = r.left + r.width * ((i * 0.37 + 0.12) % 0.9 + 0.05);
        final y = r.bottom - progreso * (r.bottom - topY);
        final radio = r.width * 0.035 * (1 - progreso) + 1.5;
        canvas.drawCircle(
          Offset(x, y),
          radio,
          Paint()..color = Colors.white.withAlpha((110 * (1 - progreso)).round()),
        );
      }
    }
    canvas.restore();

    canvas.drawRRect(
      cuerpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.045
        ..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorBateria old) => true;
}
