// ================================================================
// BARBERPRO — main.dart
// Flutter + Supabase (PostgreSQL)
// Escáner QR real · Membresía editable · Accesos rápidos funcionales
// ================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ────────────────────────────────────────────────────────────
// CONFIGURACIÓN SUPABASE — reemplaza con tus credenciales
// ────────────────────────────────────────────────────────────
const _supabaseUrl  = 'https://TU_PROYECTO.supabase.co';
const _supabaseAnon = 'TU_ANON_KEY';

// ────────────────────────────────────────────────────────────
// ENTRY POINT
// ────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnon);
  runApp(const BarberProApp());
}

SupabaseClient get _sb => Supabase.instance.client;

// ────────────────────────────────────────────────────────────
// COLORES
// ────────────────────────────────────────────────────────────
class C {
  static const gold   = Color(0xFFC9A84C);
  static const goldBg = Color(0x18C9A84C);
  static const black  = Color(0xFF0A0A0A);
  static const d1     = Color(0xFF111111);
  static const d2     = Color(0xFF1A1A1A);
  static const d3     = Color(0xFF222222);
  static const brd    = Color(0x33C9A84C);
  static const brdS   = Color(0x80C9A84C);
  static const txt    = Color(0xFFF5F0E8);
  static const muted  = Color(0xFF888888);
  static const dim    = Color(0xFF555555);
  static const ok     = Color(0xFF4CAF82);
  static const err    = Color(0xFFE05A5A);
  static const info   = Color(0xFF5A9CE0);
}

// ────────────────────────────────────────────────────────────
// TEMA
// ────────────────────────────────────────────────────────────
ThemeData get kTheme => ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: C.black,
  primaryColor: C.gold,
  colorScheme: const ColorScheme.dark(primary: C.gold, secondary: C.gold, surface: C.d2, error: C.err),
  appBarTheme: const AppBarTheme(
    backgroundColor: C.d1, elevation: 0, centerTitle: true,
    titleTextStyle: TextStyle(color: C.gold, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: .5),
    iconTheme: IconThemeData(color: C.txt),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: C.d1, selectedItemColor: C.gold,
    unselectedItemColor: C.muted, type: BottomNavigationBarType.fixed, elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: C.d3,
    border:        _ob(C.brd), enabledBorder: _ob(C.brd),
    focusedBorder: _ob(C.gold, w: 1.5),
    errorBorder:   _ob(C.err), focusedErrorBorder: _ob(C.err, w: 1.5),
    labelStyle: const TextStyle(color: C.muted, fontSize: 13),
    hintStyle: const TextStyle(color: C.dim, fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
    backgroundColor: C.gold, foregroundColor: C.black,
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), elevation: 0,
  )),
  dialogTheme: DialogThemeData(
    backgroundColor: C.d2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.brd)),
    titleTextStyle: const TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold),
    contentTextStyle: const TextStyle(color: C.txt),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: C.d2, contentTextStyle: const TextStyle(color: C.txt),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: C.brdS)),
    behavior: SnackBarBehavior.floating,
  ),
);
OutlineInputBorder _ob(Color c, {double w = 1}) =>
    OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: w));

// ────────────────────────────────────────────────────────────
// APP
// ────────────────────────────────────────────────────────────
class BarberProApp extends StatelessWidget {
  const BarberProApp({super.key});
  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'BarberPro', debugShowCheckedModeBanner: false, theme: kTheme, home: const SplashScreen());
}

// ────────────────────────────────────────────────────────────
// HASH DE CONTRASEÑA (sin dependencias externas pesadas)
// ────────────────────────────────────────────────────────────
String hashPass(String pass) {
  final bytes = utf8.encode(pass + 'BaRbErPrO2024');
  return crypto.sha256.convert(bytes).toString();
}

// ────────────────────────────────────────────────────────────
// SERVICIO SUPABASE
// ────────────────────────────────────────────────────────────
class SB {
  // ── AUTH ──
  static Future<Map<String, dynamic>?> login(String cel, String pass) async {
    final r = await _sb.from('usuarios')
        .select()
        .eq('celular', cel)
        .eq('password_hash', hashPass(pass))
        .maybeSingle();
    return r;
  }

  static Future<bool> celularExiste(String cel) async {
    final r = await _sb.from('usuarios').select('id').eq('celular', cel).maybeSingle();
    return r != null;
  }

  static Future<Map<String, dynamic>> registrar({
    required String nombre, required String celular,
    required String pass, String email = '',
  }) async {
    final r = await _sb.from('usuarios').insert({
      'nombre': nombre, 'celular': celular,
      'password_hash': hashPass(pass), 'rol': 'cliente',
      'email': email, 'membresia': 'Ninguna', 'puntos': 0,
    }).select().single();
    return r;
  }

  // ── USUARIOS ──
  static Future<Map<String, dynamic>?> getUsuario(String id) async =>
      await _sb.from('usuarios').select().eq('id', id).maybeSingle();

  static Future<Map<String, dynamic>?> getUsuarioCelular(String cel) async =>
      await _sb.from('usuarios').select().eq('celular', cel).maybeSingle();

  static Future<List<Map<String, dynamic>>> getClientes({String? q}) async {
    // En postgrest ^2.x los filtros deben ir ANTES de .order()
    if (q != null && q.isNotEmpty) {
      return List<Map<String, dynamic>>.from(
        await _sb.from('usuarios')
            .select()
            .eq('rol', 'cliente')
            .or('nombre.ilike.%$q%,celular.ilike.%$q%')
            .order('nombre'),
      );
    }
    return List<Map<String, dynamic>>.from(
      await _sb.from('usuarios').select().eq('rol', 'cliente').order('nombre'),
    );
  }

  static Future<void> updateUsuario(String id, Map<String, dynamic> data) async =>
      await _sb.from('usuarios').update(data).eq('id', id);

  static Future<void> deleteCliente(String id) async =>
      await _sb.from('usuarios').delete().eq('id', id).eq('rol', 'cliente');

  static Future<void> addPuntos(String uid, int pts, String concepto, {String? citaId}) async {
    await _sb.rpc('completar_cita_manual', params: {
      'p_usuario_id': uid, 'p_puntos': pts,
      'p_concepto': concepto, 'p_cita_id': citaId,
    });
  }

  // Versión directa (sin RPC) por si no tienes la función
  static Future<void> addPuntosDirecto(String uid, int pts, String concepto) async {
    final u = await getUsuario(uid);
    if (u == null) return;
    final ptsActual = (u['puntos'] as int?) ?? 0;
    await _sb.from('usuarios').update({'puntos': ptsActual + pts}).eq('id', uid);
    await _sb.from('historial_puntos').insert({
      'usuario_id': uid, 'concepto': concepto, 'puntos': pts,
    });
  }

  static Future<void> setMembresia(String uid, String plan) async =>
      await _sb.from('usuarios').update({'membresia': plan}).eq('id', uid);

  // ── SERVICIOS ──
  static Future<List<Map<String, dynamic>>> getServicios({bool soloActivos = false}) async {
    // Filtro ANTES de .order() para compatibilidad con postgrest ^2.x
    if (soloActivos) {
      return List<Map<String, dynamic>>.from(
          await _sb.from('servicios').select().eq('activo', true).order('nombre'));
    }
    return List<Map<String, dynamic>>.from(
        await _sb.from('servicios').select().order('nombre'));
  }

  static Future<void> addServicio(Map<String, dynamic> s) async =>
      await _sb.from('servicios').insert(s);

  static Future<void> updateServicio(String id, Map<String, dynamic> s) async =>
      await _sb.from('servicios').update(s).eq('id', id);

  static Future<void> deleteServicio(String id) async =>
      await _sb.from('servicios').update({'activo': false}).eq('id', id);

  // ── PLANES MEMBRESÍA (editables) ──
  static Future<List<Map<String, dynamic>>> getPlanes() async =>
      List<Map<String, dynamic>>.from(
          await _sb.from('planes_membresia').select().eq('activo', true).order('orden'));

  static Future<void> addPlan(Map<String, dynamic> p) async =>
      await _sb.from('planes_membresia').insert(p);

  static Future<void> updatePlan(String id, Map<String, dynamic> p) async =>
      await _sb.from('planes_membresia').update(p).eq('id', id);

  static Future<void> deletePlan(String id) async =>
      await _sb.from('planes_membresia').update({'activo': false}).eq('id', id);

  // ── CITAS ──
  // En postgrest ^2.x los filtros deben ir ANTES de .order()
  static Future<List<Map<String, dynamic>>> getCitas({
    String? clienteId, String? estado, String? fecha}) async {
    const cols = 'id,cliente_id,cliente_nombre,servicio_id,servicio_nombre,fecha,hora,estado,precio,notas,creado_en';
    const ord1 = false; // ascending: false
    // Construir la query aplicando sólo los filtros necesarios antes del order
    if (clienteId != null && estado != null && fecha != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('cliente_id', clienteId).eq('estado', estado).eq('fecha', fecha)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (clienteId != null && estado != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('cliente_id', clienteId).eq('estado', estado)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (clienteId != null && fecha != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('cliente_id', clienteId).eq('fecha', fecha)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (estado != null && fecha != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('estado', estado).eq('fecha', fecha)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (clienteId != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('cliente_id', clienteId)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (estado != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('estado', estado)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    if (fecha != null) {
      return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
          .eq('fecha', fecha)
          .order('fecha', ascending: ord1).order('hora', ascending: ord1));
    }
    return List<Map<String, dynamic>>.from(await _sb.from('citas').select(cols)
        .order('fecha', ascending: ord1).order('hora', ascending: ord1));
  }

  static Future<List<Map<String, dynamic>>> getCitasHoy() async {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return List<Map<String, dynamic>>.from(await _sb.from('citas')
        .select().eq('fecha', hoy).order('hora'));
  }

  static Future<bool> horarioOcupado(String fecha, String hora, {String? excluirId}) async {
    var q = _sb.from('citas').select('id').eq('fecha', fecha).eq('hora', hora)
        .neq('estado', 'cancelada');
    if (excluirId != null) q = q.neq('id', excluirId);
    final r = await q;
    return (r as List).isNotEmpty;
  }

  static Future<void> addCita(Map<String, dynamic> c) async =>
      await _sb.from('citas').insert(c);

  static Future<void> setCitaEstado(String id, String estado) async =>
      await _sb.from('citas').update({'estado': estado}).eq('id', id);

  static Future<void> completarCita(String id) async {
    // Usa la función PostgreSQL que suma puntos automáticamente
    try {
      await _sb.rpc('completar_cita', params: {'cita_uuid': id});
    } catch (_) {
      // Fallback manual si no existe la función RPC
      final cita = await _sb.from('citas').select().eq('id', id).single();
      await _sb.from('citas').update({'estado': 'completada'}).eq('id', id);
      final svc = await _sb.from('servicios')
          .select('puntos_otorga').eq('id', cita['servicio_id']).single();
      final pts = (svc['puntos_otorga'] as int?) ?? 0;
      await addPuntosDirecto(cita['cliente_id'].toString(), pts, cita['servicio_nombre'].toString());
    }
  }

  // ── HISTORIAL PUNTOS ──
  static Future<List<Map<String, dynamic>>> getHistorial(String uid) async =>
      List<Map<String, dynamic>>.from(await _sb.from('historial_puntos')
          .select().eq('usuario_id', uid).order('fecha', ascending: false));

  // ── PROMOCIONES ──
  static Future<List<Map<String, dynamic>>> getPromociones({bool soloActivas = false}) async {
    // Filtro ANTES de .order() para postgrest ^2.x
    if (soloActivas) {
      return List<Map<String, dynamic>>.from(await _sb.from('promociones')
          .select().eq('activa', true).order('creado_en', ascending: false));
    }
    return List<Map<String, dynamic>>.from(await _sb.from('promociones')
        .select().order('creado_en', ascending: false));
  }

  static Future<void> addPromocion(Map<String, dynamic> p) async =>
      await _sb.from('promociones').insert(p);

  static Future<void> deletePromocion(String id) async =>
      await _sb.from('promociones').delete().eq('id', id);

  // ── REPORTES ──
  static Future<Map<String, dynamic>> reportes() async {
    final citas    = List<Map<String, dynamic>>.from(await _sb.from('citas').select());
    final usuarios = List<Map<String, dynamic>>.from(
        await _sb.from('usuarios').select().eq('rol', 'cliente'));
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final completadas = citas.where((c) => c['estado'] == 'completada').toList();
    final ingTotal    = completadas.fold<double>(0, (s, c) => s + (c['precio'] as num).toDouble());
    final citasHoy    = citas.where((c) => c['fecha'].toString() == hoy).length;
    final ingHoy      = citas.where((c) => c['fecha'].toString() == hoy && c['estado'] == 'completada')
        .fold<double>(0, (s, c) => s + (c['precio'] as num).toDouble());
    final vip = usuarios.where((u) =>
        u['membresia'] == 'Premium' || u['membresia'] == 'VIP Anual').length;

    final Map<String, int> pop = {};
    for (final c in completadas) {
      final n = c['servicio_nombre'].toString();
      pop[n] = (pop[n] ?? 0) + 1;
    }
    final pops = pop.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'total': citas.length, 'completadas': completadas.length,
      'canceladas': citas.where((c) => c['estado'] == 'cancelada').length,
      'ingTotal': ingTotal, 'citasHoy': citasHoy, 'ingHoy': ingHoy,
      'clientes': usuarios.length, 'vip': vip, 'populares': pops,
    };
  }
}

// ────────────────────────────────────────────────────────────
// SESSION (en memoria)
// ────────────────────────────────────────────────────────────
class Session {
  static Map<String, dynamic>? usuario;
  static bool get isAdmin => usuario?['rol'] == 'admin';
  static String get uid => usuario!['id'].toString();
  static void clear() => usuario = null;
}

// ────────────────────────────────────────────────────────────
// HELPERS UI COMUNES
// ────────────────────────────────────────────────────────────
Color _estadoColor(String e) => switch (e) {
  'pendiente'  => C.info,
  'confirmada' => C.gold,
  'completada' => C.ok,
  'cancelada'  => C.err,
  _            => C.muted,
};

String _fmtFecha(String f) {
  try {
    final d = DateTime.parse(f);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) { return f; }
}

void _snack(BuildContext ctx, String msg, {bool err = false}) {
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg), backgroundColor: err ? C.err : C.ok));
}

Future<bool> _confirm(BuildContext ctx, String t, String msg) async {
  final r = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
    title: Text(t), content: Text(msg),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
      TextButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Si', style: TextStyle(color: C.err))),
    ],
  ));
  return r ?? false;
}

Widget _badge(String l, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: c.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
  child: Text(l.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
);

Widget _stat(String icon, String val, String lbl) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gold)),
      const SizedBox(height: 2),
      Text(lbl, style: const TextStyle(color: C.muted, fontSize: 10), textAlign: TextAlign.center),
    ]),
  ),
);

class _T extends StatelessWidget {
  final String t;
  const _T(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: const TextStyle(color: C.gold, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: .5)),
  );
}

class _F extends StatelessWidget {
  final TextEditingController c;
  final String label;
  final String? hint;
  final bool obs;
  final TextInputType kb;
  final List<TextInputFormatter>? fmt;
  final String? Function(String?)? val;
  final Widget? suffix;
  final int lines;
  const _F({required this.c, required this.label, this.hint, this.obs = false,
    this.kb = TextInputType.text, this.fmt, this.val, this.suffix, this.lines = 1});
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: c, obscureText: obs, keyboardType: kb, inputFormatters: fmt,
    style: const TextStyle(color: C.txt), maxLines: obs ? 1 : lines,
    decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
    validator: val,
  );
}

Widget _dlgHead(String t, BuildContext ctx) => Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(t, style: const TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
    IconButton(icon: const Icon(Icons.close, color: C.muted), onPressed: () => Navigator.pop(ctx)),
  ],
);

DropdownButtonFormField<T> _drop<T>({
  required T? val, required String label, String? hint,
  required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChange,
}) => DropdownButtonFormField<T>(
  value: val, hint: hint != null ? Text(hint) : null,
  dropdownColor: C.d3, style: const TextStyle(color: C.txt),
  decoration: InputDecoration(labelText: hint == null ? label : null),
  items: items, onChanged: onChange,
);

// ────────────────────────────────────────────────────────────
// SPLASH
// ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() { super.initState(); _go(); }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.black,
    body: FadeTransition(
      opacity: CurvedAnimation(parent: _ac, curve: Curves.easeIn),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 100, height: 100,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: C.gold, width: 2), color: C.goldBg),
          child: const Center(child: Text('✂️', style: TextStyle(fontSize: 50)))),
        const SizedBox(height: 18),
        const Text('BARBERPRO', style: TextStyle(
            color: C.gold, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 5)),
        const SizedBox(height: 6),
        const Text('Sistema de gestion profesional', style: TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 40),
        const SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)),
      ])),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// LOGIN
// ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _fk = GlobalKey<FormState>();
  final _cel = TextEditingController();
  final _pas = TextEditingController();
  bool _obs = true, _loading = false;

  @override
  void dispose() { _cel.dispose(); _pas.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final u = await SB.login(_cel.text.trim(), _pas.text);
      if (!mounted) return;
      setState(() => _loading = false);
      if (u == null) { _snack(context, 'Celular o contraseña incorrectos', err: true); return; }
      Session.usuario = u;
      _push(u['rol'] == 'admin' ? AdminMain(admin: u) : ClienteMain(usuario: u));
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _snack(context, 'Error: $e', err: true); }
    }
  }

  void _push(Widget w) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: RadialGradient(
        center: Alignment(0, -.3), radius: 1.2, colors: [Color(0xFF1A1200), C.black])),
      child: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(key: _fk, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 88, height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: C.gold, width: 2), color: C.goldBg),
            child: const Center(child: Text('✂️', style: TextStyle(fontSize: 44)))),
          const SizedBox(height: 16),
          const Text('BarberPro', style: TextStyle(color: C.gold, fontSize: 36, fontWeight: FontWeight.bold)),
          const Text('Ingresa a tu cuenta', style: TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 36),
          _F(c: _cel, label: 'Número de celular', hint: '987654321',
              kb: TextInputType.phone,
              fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              val: (v) {
                if (v == null || v.isEmpty) return 'Ingresa tu celular';
                if (v.length != 9) return 'Debe tener 9 dígitos';
                if (!v.startsWith('9')) return 'Debe empezar con 9';
                return null;
              }),
          const SizedBox(height: 14),
          _F(c: _pas, label: 'Contraseña', obs: _obs,
              suffix: IconButton(
                icon: Icon(_obs ? Icons.visibility_off : Icons.visibility, color: C.muted, size: 20),
                onPressed: () => setState(() => _obs = !_obs)),
              val: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
          const SizedBox(height: 26),
          _loading
              ? const CircularProgressIndicator(color: C.gold)
              : ElevatedButton(onPressed: _login, child: const Text('INGRESAR')),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('¿Sin cuenta? ', style: TextStyle(color: C.muted, fontSize: 13)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Regístrate', style: TextStyle(
                color: C.gold, fontSize: 13, fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline, decorationColor: C.gold))),
          ]),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.brd)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cuentas demo:', style: TextStyle(color: C.gold, fontSize: 11, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Admin:   999000000 / admin123',   style: TextStyle(color: C.muted, fontSize: 11, fontFamily: 'monospace')),
              Text('Cliente: 999111111 / cliente123', style: TextStyle(color: C.muted, fontSize: 11, fontFamily: 'monospace')),
            ])),
        ])),
      ))),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// REGISTRO
// ────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegState();
}

class _RegState extends State<RegisterScreen> {
  final _fk = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _cel = TextEditingController();
  final _eml = TextEditingController();
  final _pa1 = TextEditingController();
  final _pa2 = TextEditingController();
  bool _o1 = true, _o2 = true, _loading = false;

  @override
  void dispose() { for (final c in [_nom,_cel,_eml,_pa1,_pa2]) c.dispose(); super.dispose(); }

  Future<void> _registrar() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (await SB.celularExiste(_cel.text.trim())) {
        if (!mounted) return;
        setState(() => _loading = false);
        _snack(context, 'Celular ya registrado', err: true);
        return;
      }
      final u = await SB.registrar(nombre: _nom.text.trim(), celular: _cel.text.trim(),
          pass: _pa1.text, email: _eml.text.trim());
      if (!mounted) return;
      Session.usuario = u;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => ClienteMain(usuario: u)), (_) => false);
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _snack(context, 'Error: $e', err: true); }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear cuenta')),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(key: _fk, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('¡Bienvenido!', style: TextStyle(color: C.gold, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Completa tus datos', style: TextStyle(color: C.muted, fontSize: 13)),
        const SizedBox(height: 24),
        _F(c: _nom, label: 'Nombre completo',
            val: (v) => (v == null || v.trim().length < 3) ? 'Requerido' : null),
        const SizedBox(height: 12),
        _F(c: _cel, label: 'Celular', hint: '987654321', kb: TextInputType.phone,
            fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
            val: (v) {
              if (v == null || v.isEmpty) return 'Requerido';
              if (v.length != 9) return '9 dígitos';
              if (!v.startsWith('9')) return 'Empieza con 9';
              return null;
            }),
        const SizedBox(height: 12),
        _F(c: _eml, label: 'Email (opcional)', kb: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _F(c: _pa1, label: 'Contraseña', obs: _o1,
            suffix: IconButton(icon: Icon(_o1 ? Icons.visibility_off : Icons.visibility, color: C.muted, size: 20),
                onPressed: () => setState(() => _o1 = !_o1)),
            val: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
        const SizedBox(height: 12),
        _F(c: _pa2, label: 'Confirmar contraseña', obs: _o2,
            suffix: IconButton(icon: Icon(_o2 ? Icons.visibility_off : Icons.visibility, color: C.muted, size: 20),
                onPressed: () => setState(() => _o2 = !_o2)),
            val: (v) => v != _pa1.text ? 'No coinciden' : null),
        const SizedBox(height: 28),
        _loading
            ? const Center(child: CircularProgressIndicator(color: C.gold))
            : ElevatedButton(onPressed: _registrar, child: const Text('CREAR CUENTA')),
      ])),
    )),
  );
}

// ────────────────────────────────────────────────────────────
// CLIENTE MAIN
// ────────────────────────────────────────────────────────────
class ClienteMain extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const ClienteMain({super.key, required this.usuario});
  @override
  State<ClienteMain> createState() => _ClienteMainState();
}

class _ClienteMainState extends State<ClienteMain> {
  int _tab = 0;
  late Map<String, dynamic> _u;

  @override
  void initState() { super.initState(); _u = Map.from(widget.usuario); }

  Future<void> _reload() async {
    final u = await SB.getUsuario(_u['id'].toString());
    if (mounted && u != null) setState(() => _u = u);
  }

  Future<void> _logout() async {
    Session.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      CliHomeTab(u: _u, onReload: _reload),
      CliCitasTab(u: _u, onReload: _reload),
      CliQRTab(u: _u),
      CliPuntosTab(u: _u, onReload: _reload),
      CliPerfilTab(u: _u, onReload: _reload, onLogout: _logout),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ BarberPro'),
        actions: [Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.star, size: 13, color: C.gold),
              const SizedBox(width: 4),
              Text('${_u['puntos'] ?? 0} pts',
                  style: const TextStyle(color: C.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          )),
        )],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) { setState(() => _tab = i); _reload(); },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),         activeIcon: Icon(Icons.home),          label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined),activeIcon: Icon(Icons.calendar_today),label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_outlined),      activeIcon: Icon(Icons.qr_code),       label: 'QR'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline),          activeIcon: Icon(Icons.star),          label: 'Puntos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),        activeIcon: Icon(Icons.person),        label: 'Perfil'),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// CLIENTE HOME (accesos rápidos 100% funcionales)
// ────────────────────────────────────────────────────────────
class CliHomeTab extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onReload;
  const CliHomeTab({super.key, required this.u, required this.onReload});
  @override
  State<CliHomeTab> createState() => _CliHomeState();
}

class _CliHomeState extends State<CliHomeTab> {
  List<Map<String, dynamic>> _citas = [];
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await SB.getCitas(clienteId: widget.u['id'].toString());
    final p = await SB.getPromociones(soloActivas: true);
    if (mounted) setState(() { _citas = c; _promos = p; _loading = false; });
  }

  Map<String, dynamic>? get _proxima {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final activas = _citas.where((c) =>
        c['fecha'].toString().compareTo(hoy) >= 0 && c['estado'] != 'cancelada').toList();
    activas.sort((a, b) => a['fecha'].toString().compareTo(b['fecha'].toString()));
    return activas.isEmpty ? null : activas.first;
  }

  // ── Navegar a tab específico ──
  void _goTab(int i) {
    final main = context.findAncestorStateOfType<_ClienteMainState>();
    main?.setState(() => main._tab = i);
  }

  // ── Abrir reservar ──
  void _openReservar() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: C.d2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ReservarSheet(u: widget.u, onOk: () { _load(); widget.onReload(); }),
  );

  // ── Abrir membresía ──
  void _openMembresia() => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: C.d2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => MembresiaSheet(u: widget.u, onOk: () { _load(); widget.onReload(); }),
  );

  @override
  Widget build(BuildContext context) {
    final px = _proxima;
    return RefreshIndicator(
      color: C.gold,
      onRefresh: () async { await _load(); widget.onReload(); },
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : ListView(padding: const EdgeInsets.all(16), children: [

        // ── Próxima cita ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A1200), Color(0xFF2A1F00)]),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: C.gold)),
          child: Row(children: [
            const Text('📅', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PRÓXIMA CITA', style: TextStyle(color: C.muted, fontSize: 10, letterSpacing: 1.5)),
              const SizedBox(height: 3),
              Text(px != null
                  ? '${_fmtFecha(px['fecha'].toString())}  ·  ${px['hora']}'
                  : 'Sin citas programadas',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (px != null) Text(px['servicio_nombre'].toString(),
                  style: const TextStyle(color: C.gold, fontSize: 12)),
            ])),
            OutlinedButton(
              onPressed: _openReservar,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: C.gold),
                  foregroundColor: C.gold, minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Text(px != null ? 'Nueva' : 'Reservar', style: const TextStyle(fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Stats ──
        Row(children: [
          _stat('📅', '${_citas.length}', 'Total citas'),
          const SizedBox(width: 12),
          _stat('⭐', '${widget.u['puntos'] ?? 0}', 'Mis puntos'),
        ]),
        const SizedBox(height: 18),

        // ── Accesos rápidos FUNCIONALES ──
        const _T('ACCESO RÁPIDO'),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.2,
          children: [
            _qCard('✂️', 'Reservar cita',  'Elige tu servicio',
                _openReservar),                     // ← abre sheet reservar
            _qCard('📱', 'Mi QR',          'Código de cliente',
                () => _goTab(2)),                   // ← navega a tab QR
            _qCard('⭐', 'Mis puntos',     'Programa de lealtad',
                () => _goTab(3)),                   // ← navega a tab Puntos
            _qCard('👑', 'Membresía',
                (widget.u['membresia'] ?? 'Ninguna') != 'Ninguna'
                    ? (widget.u['membresia'].toString()) : 'Ver planes',
                _openMembresia),                    // ← abre sheet membresía
          ],
        ),

        // ── Promociones activas ──
        if (_promos.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _T('PROMOCIONES ACTIVAS'),
          ..._promos.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.brd)),
            child: Row(children: [
              const Text('🏷️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['titulo'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(p['descripcion'].toString(), style: const TextStyle(color: C.muted, fontSize: 12)),
              ])),
              _badge('${p['descuento']}% OFF', C.gold),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _qCard(String icon, String t, String s, VoidCallback fn) =>
      GestureDetector(onTap: fn, child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.brd)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), textAlign: TextAlign.center),
          Text(s, style: const TextStyle(color: C.muted, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ));
}

// ────────────────────────────────────────────────────────────
// RESERVAR CITA SHEET
// ────────────────────────────────────────────────────────────
class ReservarSheet extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onOk;
  const ReservarSheet({super.key, required this.u, required this.onOk});
  @override
  State<ReservarSheet> createState() => _ReservarState();
}

class _ReservarState extends State<ReservarSheet> {
  static const _horas = ['09:00','09:30','10:00','10:30','11:00','11:30',
    '12:00','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00'];
  List<Map<String, dynamic>> _svcs = [];
  Map<String, dynamic>? _svc;
  DateTime _fecha = DateTime.now();
  String? _hora;
  Set<String> _ocupadas = {};
  final _notasCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() { super.initState(); _loadSvcs(); }
  @override
  void dispose() { _notasCtrl.dispose(); super.dispose(); }

  Future<void> _loadSvcs() async {
    final s = await SB.getServicios(soloActivos: true);
    if (mounted) setState(() => _svcs = s);
    await _refreshOcupadas();
  }

  Future<void> _refreshOcupadas() async {
    final f = DateFormat('yyyy-MM-dd').format(_fecha);
    final ocu = <String>{};
    for (final h in _horas) {
      if (await SB.horarioOcupado(f, h)) ocu.add(h);
    }
    if (mounted) setState(() => _ocupadas = ocu);
  }

  Future<void> _confirmar() async {
    if (_svc == null) { _snack(context, 'Selecciona un servicio', err: true); return; }
    if (_hora == null) { _snack(context, 'Selecciona un horario', err: true); return; }
    final f = DateFormat('yyyy-MM-dd').format(_fecha);
    if (await SB.horarioOcupado(f, _hora!)) {
      if (mounted) _snack(context, 'Horario no disponible', err: true); return;
    }
    setState(() => _loading = true);
    try {
      await SB.addCita({
        'cliente_id': widget.u['id'], 'cliente_nombre': widget.u['nombre'],
        'servicio_id': _svc!['id'], 'servicio_nombre': _svc!['nombre'],
        'fecha': f, 'hora': _hora!, 'estado': 'pendiente',
        'precio': _svc!['precio'], 'notas': _notasCtrl.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onOk();
      _snack(context, '¡Cita reservada con éxito!');
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _snack(context, 'Error: $e', err: true); }
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .92, maxChildSize: .92, minChildSize: .5, expand: false,
    builder: (_, ctrl) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: ListView(controller: ctrl, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: C.dim, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        const Text('Reservar Cita', style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // servicios
        const Text('Servicio', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(height: 90, child: ListView.builder(
          scrollDirection: Axis.horizontal, itemCount: _svcs.length,
          itemBuilder: (_, i) {
            final s = _svcs[i]; final sel = _svc?['id'] == s['id'];
            return GestureDetector(
              onTap: () => setState(() => _svc = s),
              child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                width: 90, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: sel ? C.goldBg : C.d3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? C.gold : C.brd, width: sel ? 1.5 : 1)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s['icono'].toString(), style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 3),
                  Text(s['nombre'].toString(), style: const TextStyle(fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  Text('S/${(s['precio'] as num).toInt()}',
                      style: const TextStyle(color: C.gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        )),
        const SizedBox(height: 14),

        // fecha
        const Text('Fecha', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _fecha,
              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: (_, ch) => Theme(data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: C.gold)), child: ch!));
            if (d != null) { setState(() { _fecha = d; _hora = null; }); _refreshOcupadas(); }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(color: C.d3, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.brd)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 15, color: C.muted), const SizedBox(width: 10),
              Text(DateFormat('dd/MM/yyyy').format(_fecha), style: const TextStyle(color: C.txt)),
              const Spacer(), const Icon(Icons.chevron_right, size: 16, color: C.muted),
            ]),
          ),
        ),
        const SizedBox(height: 14),

        // horarios
        const Text('Horario disponible', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.9),
          itemCount: _horas.length,
          itemBuilder: (_, i) {
            final h = _horas[i]; final ocu = _ocupadas.contains(h); final sel = _hora == h;
            return GestureDetector(
              onTap: ocu ? null : () => setState(() => _hora = h),
              child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: sel ? C.gold : ocu ? C.err.withOpacity(.08) : C.d3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sel ? C.gold : ocu ? C.err.withOpacity(.3) : C.brd)),
                child: Center(child: Text(h, style: TextStyle(
                  color: sel ? C.black : ocu ? C.err : C.txt,
                  fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // notas
        const Text('Notas (opcional)', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 6),
        _F(c: _notasCtrl, label: '', hint: 'Indicaciones especiales...', lines: 2),

        // resumen
        if (_svc != null) ...[
          const SizedBox(height: 14),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.brd)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_svc!['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${_svc!['duracion_min']} min  ·  +${_svc!['puntos_otorga']} pts',
                    style: const TextStyle(color: C.muted, fontSize: 12)),
              ]),
              Text('S/ ${(_svc!['precio'] as num).toInt()}',
                  style: const TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        _loading
            ? const Center(child: CircularProgressIndicator(color: C.gold))
            : ElevatedButton(onPressed: _confirmar, child: const Text('✅  Confirmar reserva')),
      ]),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// MEMBRESÍA SHEET (planes desde Supabase — editables)
// ────────────────────────────────────────────────────────────
class MembresiaSheet extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onOk;
  const MembresiaSheet({super.key, required this.u, required this.onOk});
  @override
  State<MembresiaSheet> createState() => _MembresiaState();
}

class _MembresiaState extends State<MembresiaSheet> {
  List<Map<String, dynamic>> _planes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SB.getPlanes();
    if (mounted) setState(() { _planes = p; _loading = false; });
  }

  Future<void> _activar(String plan) async {
    await SB.setMembresia(widget.u['id'].toString(), plan);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onOk();
    _snack(context, 'Plan $plan activado! 👑');
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .88, maxChildSize: .92, minChildSize: .5, expand: false,
    builder: (_, ctrl) => Padding(padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : ListView(controller: ctrl, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: C.dim, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 14),
        const Text('Planes de Membresía', style: TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ..._planes.map((p) {
          final activo = widget.u['membresia'] == p['nombre'];
          final beneficios = (p['beneficios'] as List?)?.cast<String>() ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: activo ? C.goldBg : C.d3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activo ? C.gold : C.brd, width: activo ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(p['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                RichText(text: TextSpan(children: [
                  TextSpan(text: 'S/${(p['precio'] as num).toInt()}',
                      style: const TextStyle(color: C.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                  TextSpan(text: '/${p['periodo']}',
                      style: const TextStyle(color: C.muted, fontSize: 12)),
                ])),
              ]),
              if ((p['descripcion'] ?? '').toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(p['descripcion'].toString(),
                        style: const TextStyle(color: C.muted, fontSize: 12))),
              const SizedBox(height: 10),
              ...beneficios.map((b) => Padding(padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Text('✅ ', style: TextStyle(fontSize: 12)),
                    Expanded(child: Text(b, style: const TextStyle(color: C.muted, fontSize: 12))),
                  ]))),
              const SizedBox(height: 12),
              activo
                  ? Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(color: C.ok.withOpacity(.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.ok.withOpacity(.3))),
                      child: const Center(child: Text('✓ Plan activo',
                          style: TextStyle(color: C.ok, fontWeight: FontWeight.w600))))
                  : SizedBox(width: double.infinity, child: ElevatedButton(
                      onPressed: () => _activar(p['nombre'].toString()),
                      child: Text('Activar ${p['nombre']}'))),
            ]),
          );
        }),
      ]),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// CLIENTE CITAS
// ────────────────────────────────────────────────────────────
class CliCitasTab extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onReload;
  const CliCitasTab({super.key, required this.u, required this.onReload});
  @override
  State<CliCitasTab> createState() => _CliCitasState();
}

class _CliCitasState extends State<CliCitasTab> {
  List<Map<String, dynamic>> _citas = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await SB.getCitas(clienteId: widget.u['id'].toString());
    if (mounted) setState(() => _citas = c);
  }

  Future<void> _cancelar(Map<String, dynamic> c) async {
    if (!await _confirm(context, 'Cancelar cita',
        '¿Cancelar ${c['servicio_nombre']} del ${_fmtFecha(c['fecha'].toString())}?')) return;
    await SB.setCitaEstado(c['id'].toString(), 'cancelada');
    _load(); widget.onReload();
    if (mounted) _snack(context, 'Cita cancelada', err: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(
      backgroundColor: C.gold, foregroundColor: C.black,
      onPressed: () => showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: C.d2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => ReservarSheet(u: widget.u, onOk: () { _load(); widget.onReload(); }),
      ),
      child: const Icon(Icons.add),
    ),
    body: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: _citas.isEmpty
          ? const Center(child: Text('No tienes citas registradas', style: TextStyle(color: C.muted)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _citas.length,
              itemBuilder: (_, i) {
                final c = _citas[i]; final col = _estadoColor(c['estado'].toString());
                return Container(
                  margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['servicio_nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 3),
                        Text('${_fmtFecha(c['fecha'].toString())}  ·  ${c['hora']}',
                            style: const TextStyle(color: C.muted, fontSize: 12)),
                      ])),
                      _badge(c['estado'].toString(), col),
                    ]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('S/ ${(c['precio'] as num).toInt()}',
                          style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (c['estado'] == 'pendiente' || c['estado'] == 'confirmada')
                        OutlinedButton(
                          onPressed: () => _cancelar(c),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: C.err),
                              foregroundColor: C.err, minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                          child: const Text('Cancelar', style: TextStyle(fontSize: 12))),
                    ]),
                    if ((c['notas'] ?? '').toString().isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 6),
                          child: Text('📝 ${c['notas']}', style: const TextStyle(color: C.muted, fontSize: 11))),
                  ]),
                );
              }),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// CLIENTE QR
// ────────────────────────────────────────────────────────────
class CliQRTab extends StatelessWidget {
  final Map<String, dynamic> u;
  const CliQRTab({super.key, required this.u});
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      const _T('Mi Código QR'),
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.brd)),
        child: Column(children: [
          const Text('Muestra este código al barbero\npara registrar tu servicio',
              textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: QrImageView(
              // Datos embebidos: id|celular|nombre
              data: '${u['id']}|${u['celular']}|${u['nombre']}',
              version: QrVersions.auto, size: 200, backgroundColor: Colors.white)),
          const SizedBox(height: 14),
          Text('ID: ${u['id'].toString().substring(0, 8).toUpperCase()}...',
              style: const TextStyle(color: C.muted, fontSize: 11, letterSpacing: 2, fontFamily: 'monospace')),
          const SizedBox(height: 8),
          _badge(
            (u['membresia'] ?? 'Ninguna') != 'Ninguna' ? '👑 ${u['membresia']}' : 'Cliente estándar',
            (u['membresia'] ?? 'Ninguna') != 'Ninguna' ? C.gold : C.muted),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.brd)),
        child: Row(children: [
          const Text('⭐', style: TextStyle(fontSize: 22)), const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['puntos'] ?? 0} puntos acumulados',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(_nivel(u['puntos'] as int? ?? 0),
                style: const TextStyle(color: C.gold, fontSize: 12)),
          ]),
        ])),
    ])),
  );
  String _nivel(int p) {
    if (p >= 500) return 'Nivel: Oro 🥇';
    if (p >= 200) return 'Nivel: Plata 🥈';
    return 'Nivel: Bronce 🥉';
  }
}

// ────────────────────────────────────────────────────────────
// CLIENTE PUNTOS
// ────────────────────────────────────────────────────────────
class CliPuntosTab extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onReload;
  const CliPuntosTab({super.key, required this.u, required this.onReload});
  @override
  State<CliPuntosTab> createState() => _CliPuntosState();
}

class _CliPuntosState extends State<CliPuntosTab> {
  Map<String, dynamic>? _u;
  List<Map<String, dynamic>> _hist = [];

  @override
  void initState() { super.initState(); _u = widget.u; _reload(); }

  Future<void> _reload() async {
    final u = await SB.getUsuario(widget.u['id'].toString());
    final h = await SB.getHistorial(widget.u['id'].toString());
    if (mounted && u != null) setState(() { _u = u; _hist = h; });
  }

  int get _pts => (_u ?? widget.u)['puntos'] as int? ?? 0;
  String get _nivel { if (_pts >= 500) return '🥇 Oro'; if (_pts >= 200) return '🥈 Plata'; return '🥉 Bronce'; }
  double get _prog { if (_pts >= 500) return 1.0; if (_pts >= 200) return (_pts-200)/300.0; return _pts/200.0; }
  int get _falt { if (_pts >= 500) return 0; if (_pts >= 200) return 500-_pts; return 200-_pts; }
  double get _desc { if (_pts >= 500) return 20; if (_pts >= 200) return 10; return 5; }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: C.gold, onRefresh: () async { await _reload(); widget.onReload(); },
    child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A1200), Color(0xFF2A1F00)]),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: C.gold)),
        child: Column(children: [
          Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.gold, width: 3)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_pts', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: C.gold)),
              const Text('PUNTOS', style: TextStyle(color: C.muted, fontSize: 9, letterSpacing: 1)),
            ])),
          const SizedBox(height: 12),
          _badge(_nivel, C.gold),
          const SizedBox(height: 10),
          if (_falt > 0) Text('$_falt puntos para siguiente nivel',
              style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(value: _prog.clamp(0.0, 1.0),
                  backgroundColor: C.d3, color: C.gold, minHeight: 8)),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DESCUENTO ACTUAL', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
            SizedBox(height: 4),
            Text('En todos los servicios', style: TextStyle(color: C.txt, fontSize: 13)),
          ]),
          Text('${_desc.toInt()}% OFF', style: const TextStyle(color: C.gold, fontSize: 22, fontWeight: FontWeight.bold)),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BENEFICIOS POR NIVEL', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          _nv('🥉', 'Bronce — 0 a 199 pts', '5% descuento'),
          const Divider(color: C.brd, height: 20),
          _nv('🥈', 'Plata — 200 a 499 pts', '10% descuento + 1 corte gratis/mes'),
          const Divider(color: C.brd, height: 20),
          _nv('🥇', 'Oro — 500+ pts', '20% descuento + prioridad de cita'),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HISTORIAL DE PUNTOS', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_hist.isEmpty) const Center(child: Text('Sin historial aún', style: TextStyle(color: C.muted)))
          else ..._hist.map((h) => Padding(padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('⭐', style: TextStyle(fontSize: 18)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h['concepto'].toString(), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(h['fecha'].toString())),
                      style: const TextStyle(color: C.muted, fontSize: 11)),
                ])),
                _badge('+${h['puntos']} pts', C.gold),
              ]))),
        ])),
    ]),
  );
  Widget _nv(String e, String t, String b) => Row(children: [
    Text(e, style: const TextStyle(fontSize: 22)), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
      Text(b, style: const TextStyle(color: C.muted, fontSize: 11)),
    ])),
  ]);
}

// ────────────────────────────────────────────────────────────
// CLIENTE PERFIL
// ────────────────────────────────────────────────────────────
class CliPerfilTab extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onReload;
  final VoidCallback onLogout;
  const CliPerfilTab({super.key, required this.u, required this.onReload, required this.onLogout});
  @override
  State<CliPerfilTab> createState() => _CliPerfilState();
}

class _CliPerfilState extends State<CliPerfilTab> {
  final _fk = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.u['nombre']?.toString() ?? '');
  late final _eml = TextEditingController(text: widget.u['email']?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() { _nom.dispose(); _eml.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _saving = true);
    await SB.updateUsuario(widget.u['id'].toString(), {'nombre': _nom.text.trim(), 'email': _eml.text.trim()});
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onReload();
    _snack(context, 'Perfil actualizado ✓');
  }

  String _init(String n) {
    final p = n.trim().split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase() : n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u; final mem = u['membresia']?.toString() ?? 'Ninguna';
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Form(key: _fk, child: Column(children: [
      Container(padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.brd)),
        child: Column(children: [
          Container(width: 68, height: 68,
            decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
            child: Center(child: Text(_init(u['nombre']?.toString() ?? ''),
                style: const TextStyle(color: C.black, fontSize: 26, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 10),
          Text(u['nombre']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(u['celular']?.toString() ?? '', style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 8),
          _badge(mem != 'Ninguna' ? '👑 $mem' : 'Sin membresía', mem != 'Ninguna' ? C.gold : C.muted),
        ])),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EDITAR PERFIL', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 14),
          _F(c: _nom, label: 'Nombre completo',
              val: (v) => (v == null || v.trim().length < 3) ? 'Requerido' : null),
          const SizedBox(height: 12),
          _F(c: _eml, label: 'Email (opcional)', kb: TextInputType.emailAddress),
          const SizedBox(height: 18),
          _saving ? const Center(child: CircularProgressIndicator(color: C.gold))
              : ElevatedButton(onPressed: _guardar, child: const Text('Guardar cambios')),
        ])),
      const SizedBox(height: 14),
      OutlinedButton(onPressed: widget.onLogout,
        style: OutlinedButton.styleFrom(side: const BorderSide(color: C.err),
            foregroundColor: C.err, minimumSize: const Size(double.infinity, 52)),
        child: const Text('Cerrar sesión')),
    ])));
  }
}

// ════════════════════════════════════════════════════════════
// ADMIN
// ════════════════════════════════════════════════════════════
class AdminMain extends StatefulWidget {
  final Map<String, dynamic> admin;
  const AdminMain({super.key, required this.admin});
  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int _tab = 0;

  Future<void> _logout() async {
    Session.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdmDashTab(onLogout: _logout),
      const AdmCitasTab(),
      const AdmClientesTab(),
      const AdmServiciosTab(),
      const AdmMembresiaTab(),   // ← Planes editables
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('✂️ Admin Panel'),
        actions: [
          IconButton(icon: const Icon(Icons.bar_chart, color: C.muted),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportesScreen())),
              tooltip: 'Reportes'),
          IconButton(icon: const Icon(Icons.logout, color: C.muted),
              onPressed: _logout, tooltip: 'Salir'),
        ],
      ),
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined),     activeIcon: Icon(Icons.dashboard),    label: 'Panel'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today),label: 'Citas'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline),         activeIcon: Icon(Icons.people),       label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.cut_outlined),           activeIcon: Icon(Icons.cut),          label: 'Servicios'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), activeIcon: Icon(Icons.workspace_premium), label: 'Membresía'),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ────────────────────────────────────────────────────────────
class AdmDashTab extends StatefulWidget {
  final VoidCallback onLogout;
  const AdmDashTab({super.key, required this.onLogout});
  @override
  State<AdmDashTab> createState() => _AdmDashState();
}

class _AdmDashState extends State<AdmDashTab> {
  Map<String, dynamic> _r = {};
  List<Map<String, dynamic>> _hoy = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await SB.reportes();
    final h = await SB.getCitasHoy();
    if (mounted) setState(() { _r = r; _hoy = h; _loading = false; });
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: C.gold, onRefresh: _load,
    child: _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
        : ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        _stat('📅', '${_r['citasHoy'] ?? 0}', 'Citas hoy'),
        const SizedBox(width: 12),
        _stat('👥', '${_r['clientes'] ?? 0}', 'Clientes'),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _stat('💰', 'S/${(_r['ingHoy'] ?? 0.0).toInt()}', 'Ingresos hoy'),
        const SizedBox(width: 12),
        _stat('👑', '${_r['vip'] ?? 0}', 'VIP activos'),
      ]),
      const SizedBox(height: 20),
      const _T('CITAS DE HOY'),
      if (_hoy.isEmpty) const Padding(padding: EdgeInsets.all(20),
          child: Center(child: Text('Sin citas para hoy', style: TextStyle(color: C.muted))))
      else ..._hoy.map((c) => _citaCard(c)),
      const SizedBox(height: 20),
      const _T('ACCIONES RÁPIDAS'),
      ElevatedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => QRScannerScreen(onScanned: (data) async {
              // data = "id|celular|nombre"
              final parts = data.split('|');
              if (parts.isEmpty) return;
              final uid = parts[0];
              final u = await SB.getUsuario(uid);
              if (u == null || !mounted) return;
              if (!mounted) return;
              _showQRResult(u);
            }))),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Escanear QR de cliente'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => showDialog(context: context,
            builder: (_) => NuevaCitaDialog(onOk: _load)),
        icon: const Icon(Icons.add), label: const Text('Crear cita manual'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: C.brd),
            foregroundColor: C.txt, minimumSize: const Size(double.infinity, 52))),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdmPromoScreen())),
        icon: const Icon(Icons.local_offer_outlined), label: const Text('Gestionar promociones'),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: C.brd),
            foregroundColor: C.txt, minimumSize: const Size(double.infinity, 52))),
    ]),
  );

  Widget _citaCard(Map<String, dynamic> c) {
    final col = _estadoColor(c['estado'].toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
      child: Row(children: [
        SizedBox(width: 46, child: Text(c['hora'].toString(),
            style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold, fontSize: 13))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['cliente_nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${c['servicio_nombre']}  ·  S/${(c['precio'] as num).toInt()}',
              style: const TextStyle(color: C.muted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _badge(c['estado'].toString(), col),
          const SizedBox(height: 4),
          if (c['estado'] == 'pendiente')
            _mBtn('Confirmar', C.gold, () => _accion(c['id'].toString(), 'confirmada')),
          if (c['estado'] == 'confirmada')
            _mBtn('✓ Completar', C.ok, () async {
              await SB.completarCita(c['id'].toString()); _load();
            }),
        ]),
      ]),
    );
  }

  Widget _mBtn(String l, Color col, VoidCallback fn) => GestureDetector(onTap: fn,
    child: Container(margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: col.withOpacity(.4))),
      child: Text(l, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w600))));

  Future<void> _accion(String id, String est) async {
    await SB.setCitaEstado(id, est); _load();
  }

  void _showQRResult(Map<String, dynamic> u) {
    showDialog(context: context, builder: (_) => _QRResultDialog(u: u, onOk: _load));
  }
}

// ────────────────────────────────────────────────────────────
// ESCÁNER QR REAL (mobile_scanner)
// ────────────────────────────────────────────────────────────
class QRScannerScreen extends StatefulWidget {
  final Future<void> Function(String data) onScanned;
  const QRScannerScreen({super.key, required this.onScanned});
  @override
  State<QRScannerScreen> createState() => _QRScannerState();
}

class _QRScannerState extends State<QRScannerScreen> {
  late final MobileScannerController _ctrl;
  bool _procesando = false;
  String? _resultado;
  bool _torchOn = false; // estado linterna local

  @override
  void initState() {
    super.initState();
    // En mobile_scanner v5.x se puede pasar opciones al constructor
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_procesando) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    setState(() { _procesando = true; _resultado = barcode.rawValue; });
    await _ctrl.stop();
    await widget.onScanned(barcode.rawValue!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.black,
    appBar: AppBar(title: const Text('Escanear QR'),
      actions: [
        // Linterna: en v5.x usamos estado local y llamamos toggleTorch()
        IconButton(
          icon: Icon(
            _torchOn ? Icons.flash_on : Icons.flash_off,
            color: _torchOn ? C.gold : C.muted,
          ),
          onPressed: () async {
            await _ctrl.toggleTorch();
            if (mounted) setState(() => _torchOn = !_torchOn);
          },
        ),
        IconButton(
          icon: const Icon(Icons.flip_camera_ios),
          onPressed: () => _ctrl.switchCamera(),
        ),
      ]),
    body: Stack(children: [
      MobileScanner(controller: _ctrl, onDetect: _onDetect),
      // Marco de escaneo
      Center(child: Container(
        width: 260, height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: C.gold, width: 2.5),
          borderRadius: BorderRadius.circular(16)),
        child: Stack(children: [
          Positioned(top: 0, left: 0,   child: _corner(true,  true)),
          Positioned(top: 0, right: 0,  child: _corner(true,  false)),
          Positioned(bottom: 0, left: 0,  child: _corner(false, true)),
          Positioned(bottom: 0, right: 0, child: _corner(false, false)),
        ]),
      )),
      Positioned(bottom: 40, left: 0, right: 0,
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: C.black.withOpacity(.7), borderRadius: BorderRadius.circular(20)),
          child: Text(
            _procesando ? 'Procesando: ${_resultado ?? '...'}' : 'Apunta la cámara al código QR',
            style: TextStyle(color: _procesando ? C.gold : C.txt, fontSize: 14)),
        ))),
      if (_procesando) const Center(child: CircularProgressIndicator(color: C.gold)),
    ]),
  );

  Widget _corner(bool top, bool left) => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      border: Border(
        top:    top  ? const BorderSide(color: C.gold, width: 4) : BorderSide.none,
        bottom: !top ? const BorderSide(color: C.gold, width: 4) : BorderSide.none,
        left:   left  ? const BorderSide(color: C.gold, width: 4) : BorderSide.none,
        right:  !left ? const BorderSide(color: C.gold, width: 4) : BorderSide.none,
      ),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// RESULTADO QR → SUMAR PUNTOS
// ────────────────────────────────────────────────────────────
class _QRResultDialog extends StatefulWidget {
  final Map<String, dynamic> u;
  final VoidCallback onOk;
  const _QRResultDialog({required this.u, required this.onOk});
  @override
  State<_QRResultDialog> createState() => _QRResultDialogState();
}

class _QRResultDialogState extends State<_QRResultDialog> {
  List<Map<String, dynamic>> _svcs = [];
  Map<String, dynamic>? _svc;
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await SB.getServicios(soloActivos: true);
    if (mounted) setState(() { _svcs = s; if (s.isNotEmpty) _svc = s.first; });
  }

  Future<void> _registrar() async {
    if (_svc == null) { _snack(context, 'Selecciona servicio', err: true); return; }
    setState(() => _loading = true);
    await SB.addPuntosDirecto(
        widget.u['id'].toString(), _svc!['puntos_otorga'] as int, _svc!['nombre'].toString());
    if (!mounted) return;
    Navigator.pop(context);
    widget.onOk();
    _snack(context, '+${_svc!['puntos_otorga']} pts a ${widget.u['nombre']} ⭐');
  }

  @override
  Widget build(BuildContext context) => Dialog(child: Padding(padding: const EdgeInsets.all(20),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgHead('Cliente encontrado', context),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.ok.withOpacity(.08), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.ok.withOpacity(.3))),
        child: Row(children: [
          Container(width: 38, height: 38,
            decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
            child: Center(child: Text(
              (widget.u['nombre']?.toString() ?? 'C').isNotEmpty
                  ? (widget.u['nombre']?.toString() ?? 'C')[0].toUpperCase() : 'C',
              style: const TextStyle(color: C.black, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.u['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${widget.u['puntos']} pts  ·  ${widget.u['membresia']}',
                style: const TextStyle(color: C.muted, fontSize: 11)),
          ]),
        ])),
      const SizedBox(height: 14),
      if (_svcs.isNotEmpty) ...[
        const Text('Servicio realizado', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 6),
        _drop<Map<String, dynamic>>(
          val: _svc, label: 'Servicio',
          items: _svcs.map((s) => DropdownMenuItem(value: s,
              child: Text('${s['icono']} ${s['nombre']}  (+${s['puntos_otorga']}pts)'))).toList(),
          onChange: (v) => setState(() => _svc = v)),
      ],
      const SizedBox(height: 18),
      _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
          : ElevatedButton(onPressed: _registrar, child: const Text('✅  Registrar y sumar puntos')),
    ])));
}

// ────────────────────────────────────────────────────────────
// CREAR CITA MANUAL — con buscador de cliente en tiempo real
// ────────────────────────────────────────────────────────────
class NuevaCitaDialog extends StatefulWidget {
  final VoidCallback onOk;
  const NuevaCitaDialog({super.key, required this.onOk});
  @override
  State<NuevaCitaDialog> createState() => _NuevaCitaDialogState();
}

class _NuevaCitaDialogState extends State<NuevaCitaDialog> {
  static const _horas = ['09:00','09:30','10:00','10:30','11:00','11:30',
    '12:00','14:00','14:30','15:00','15:30','16:00','16:30','17:00','17:30','18:00'];

  // ── Búsqueda de cliente ──
  final _busCtrl = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _cliSel;
  bool _buscando = false;

  // ── Servicio / fecha / hora ──
  List<Map<String, dynamic>> _svcs = [];
  Map<String, dynamic>? _svcSel;
  DateTime _fecha = DateTime.now();
  String _hora = '09:00';
  String _estado = 'pendiente';
  bool _guardando = false;

  @override
  void initState() { super.initState(); _loadSvcs(); }
  @override
  void dispose() { _busCtrl.dispose(); super.dispose(); }

  Future<void> _loadSvcs() async {
    final s = await SB.getServicios(soloActivos: true);
    if (mounted) setState(() { _svcs = s; if (s.isNotEmpty) _svcSel = s.first; });
  }

  Future<void> _buscar(String q) async {
    if (q.length < 2) { setState(() { _resultados = []; _buscando = false; }); return; }
    setState(() => _buscando = true);
    final r = await SB.getClientes(q: q);
    if (mounted) setState(() { _resultados = r; _buscando = false; });
  }

  Future<void> _crear() async {
    if (_cliSel == null) { _snack(context, 'Selecciona un cliente', err: true); return; }
    if (_svcSel == null) { _snack(context, 'Selecciona un servicio', err: true); return; }
    setState(() => _guardando = true);
    final f = DateFormat('yyyy-MM-dd').format(_fecha);
    try {
      await SB.addCita({
        'cliente_id': _cliSel!['id'], 'cliente_nombre': _cliSel!['nombre'],
        'servicio_id': _svcSel!['id'], 'servicio_nombre': _svcSel!['nombre'],
        'fecha': f, 'hora': _hora, 'estado': _estado,
        'precio': _svcSel!['precio'], 'notas': '',
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onOk();
      _snack(context, 'Cita creada con éxito');
    } catch (e) {
      if (mounted) { setState(() => _guardando = false); _snack(context, 'Error: $e', err: true); }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _dlgHead('Nueva Cita Manual', context),
        const SizedBox(height: 14),

        // ── Buscador de cliente ──
        const Text('BUSCAR CLIENTE', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _busCtrl,
          style: const TextStyle(color: C.txt),
          decoration: InputDecoration(
            labelText: 'Nombre o celular',
            suffixIcon: _buscando
                ? const Padding(padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)))
                : const Icon(Icons.search, color: C.muted, size: 18)),
          onChanged: _buscar,
        ),

        // Lista de resultados
        if (_resultados.isNotEmpty && _cliSel == null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: C.d3, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: C.brd)),
            child: Column(children: _resultados.take(5).map((u) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              leading: Container(width: 32, height: 32,
                decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                child: Center(child: Text(
                  u['nombre'].toString().isNotEmpty ? u['nombre'].toString()[0].toUpperCase() : 'C',
                  style: const TextStyle(color: C.black, fontWeight: FontWeight.bold, fontSize: 14)))),
              title: Text(u['nombre'].toString(), style: const TextStyle(fontSize: 13)),
              subtitle: Text(u['celular'].toString(), style: const TextStyle(color: C.muted, fontSize: 11)),
              onTap: () => setState(() {
                _cliSel = u; _resultados = [];
                _busCtrl.text = u['nombre'].toString();
              }),
            )).toList()),
          ),

        // Cliente seleccionado
        if (_cliSel != null) ...[
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: C.goldBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.gold)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: C.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cliSel!['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${_cliSel!['celular']}  ·  ${_cliSel!['puntos']} pts',
                    style: const TextStyle(color: C.muted, fontSize: 11)),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 16, color: C.muted),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  onPressed: () => setState(() { _cliSel = null; _busCtrl.clear(); })),
            ])),
        ],
        const SizedBox(height: 14),

        // Servicio
        _drop<Map<String, dynamic>>(
          val: _svcSel, label: 'Servicio',
          items: _svcs.map((s) => DropdownMenuItem(value: s,
              child: Text('${s['icono']} ${s['nombre']}  S/${(s['precio'] as num).toInt()}'))).toList(),
          onChange: (v) => setState(() => _svcSel = v)),
        const SizedBox(height: 10),

        // Fecha
        ListTile(contentPadding: EdgeInsets.zero,
          title: Text(
            'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha)}',
            style: const TextStyle(color: C.txt)),
          trailing: const Icon(Icons.calendar_today, color: C.gold, size: 18),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _fecha,
              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: (_, ch) => Theme(data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(primary: C.gold)), child: ch!));
            if (d != null) setState(() => _fecha = d);
          }),
        const SizedBox(height: 6),

        // Hora
        _drop<String>(val: _hora, label: 'Hora',
          items: _horas.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
          onChange: (v) => setState(() => _hora = v!)),
        const SizedBox(height: 10),

        // Estado
        _drop<String>(val: _estado, label: 'Estado inicial',
          items: const [
            DropdownMenuItem(value: 'pendiente',  child: Text('Pendiente')),
            DropdownMenuItem(value: 'confirmada', child: Text('Confirmada')),
          ],
          onChange: (v) => setState(() => _estado = v!)),
        const SizedBox(height: 18),

        _guardando ? const Center(child: CircularProgressIndicator(color: C.gold))
            : ElevatedButton(onPressed: _crear, child: const Text('Crear cita')),
      ])));
}

// ────────────────────────────────────────────────────────────
// ADMIN CITAS
// ────────────────────────────────────────────────────────────
class AdmCitasTab extends StatefulWidget {
  const AdmCitasTab({super.key});
  @override
  State<AdmCitasTab> createState() => _AdmCitasState();
}

class _AdmCitasState extends State<AdmCitasTab> {
  List<Map<String, dynamic>> _citas = [];
  String _filtro = '';
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final c = await SB.getCitas(estado: _filtro.isEmpty ? null : _filtro);
    if (mounted) setState(() { _citas = c; _loading = false; });
  }

  Future<void> _accion(Map<String, dynamic> c, String est) async {
    if (est == 'completada') await SB.completarCita(c['id'].toString());
    else await SB.setCitaEstado(c['id'].toString(), est);
    _load();
    if (mounted) _snack(context, 'Estado: $est');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0), child: Row(children: [
      Expanded(child: _drop<String>(
        val: _filtro.isEmpty ? null : _filtro, label: 'Filtrar', hint: 'Todas las citas',
        items: const [
          DropdownMenuItem(value: '',          child: Text('Todas')),
          DropdownMenuItem(value: 'pendiente', child: Text('Pendientes')),
          DropdownMenuItem(value: 'confirmada',child: Text('Confirmadas')),
          DropdownMenuItem(value: 'completada',child: Text('Completadas')),
          DropdownMenuItem(value: 'cancelada', child: Text('Canceladas')),
        ],
        onChange: (v) { setState(() => _filtro = v ?? ''); _load(); })),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.add_circle, color: C.gold, size: 28),
          onPressed: () => showDialog(context: context,
              builder: (_) => NuevaCitaDialog(onOk: _load))),
    ])),
    Expanded(child: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
          : _citas.isEmpty ? const Center(child: Text('Sin citas', style: TextStyle(color: C.muted)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _citas.length,
              itemBuilder: (_, i) {
                final c = _citas[i]; final col = _estadoColor(c['estado'].toString());
                return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['cliente_nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(c['servicio_nombre'].toString(), style: const TextStyle(color: C.muted, fontSize: 12)),
                        Text('${_fmtFecha(c['fecha'].toString())}  ·  ${c['hora']}',
                            style: const TextStyle(color: C.gold, fontSize: 12)),
                      ])),
                      _badge(c['estado'].toString(), col),
                    ]),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('S/ ${(c['precio'] as num).toInt()}',
                          style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
                      Row(children: [
                        if (c['estado'] == 'pendiente')
                          _aBtn('Confirmar', C.gold, () => _accion(c, 'confirmada')),
                        if (c['estado'] == 'confirmada') ...[
                          _aBtn('✓', C.ok, () => _accion(c, 'completada')),
                          const SizedBox(width: 6),
                        ],
                        if (c['estado'] != 'cancelada' && c['estado'] != 'completada')
                          _aBtn('✕', C.err, () => _accion(c, 'cancelada')),
                      ]),
                    ]),
                  ]),
                );
              }))),
  ]);

  Widget _aBtn(String l, Color col, VoidCallback fn) => OutlinedButton(onPressed: fn,
    style: OutlinedButton.styleFrom(side: BorderSide(color: col), foregroundColor: col,
        minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        textStyle: const TextStyle(fontSize: 11)),
    child: Text(l));
}

// ────────────────────────────────────────────────────────────
// ADMIN CLIENTES
// ────────────────────────────────────────────────────────────
class AdmClientesTab extends StatefulWidget {
  const AdmClientesTab({super.key});
  @override
  State<AdmClientesTab> createState() => _AdmClientesState();
}

class _AdmClientesState extends State<AdmClientesTab> {
  List<Map<String, dynamic>> _clientes = [];
  String _q = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final c = await SB.getClientes(q: _q.isEmpty ? null : _q);
    if (mounted) setState(() => _clientes = c);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirm(context, 'Eliminar cliente', 'Esta acción no se puede deshacer.')) return;
    await SB.deleteCliente(id); _load();
    if (mounted) _snack(context, 'Cliente eliminado', err: true);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0), child: Row(children: [
      Expanded(child: TextFormField(
        style: const TextStyle(color: C.txt),
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: C.muted, size: 18),
            hintText: 'Buscar por nombre o celular...'),
        onChanged: (v) { setState(() => _q = v); _load(); })),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.person_add, color: C.gold, size: 26),
          onPressed: () => showDialog(context: context,
              builder: (_) => NuevoClienteDialog(onOk: _load))),
    ])),
    Expanded(child: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: _clientes.isEmpty
          ? const Center(child: Text('Sin resultados', style: TextStyle(color: C.muted)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _clientes.length,
              itemBuilder: (_, i) {
                final u = _clientes[i]; final mem = u['membresia']?.toString() ?? 'Ninguna';
                final init = (u['nombre']?.toString() ?? 'C').isNotEmpty
                    ? (u['nombre']?.toString() ?? 'C')[0].toUpperCase() : 'C';
                return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                      child: Center(child: Text(init,
                          style: const TextStyle(color: C.black, fontSize: 18, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(u['celular']?.toString() ?? '', style: const TextStyle(color: C.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, children: [
                        _badge(mem != 'Ninguna' ? '👑 $mem' : 'Sin membresía', mem != 'Ninguna' ? C.gold : C.muted),
                        _badge('⭐ ${u['puntos']} pts', C.info),
                      ]),
                    ])),
                    IconButton(icon: const Icon(Icons.delete_outline, color: C.err, size: 20),
                        onPressed: () => _eliminar(u['id'].toString())),
                  ]));
              }))),
  ]);
}

// ────────────────────────────────────────────────────────────
// ADMIN SERVICIOS
// ────────────────────────────────────────────────────────────
class AdmServiciosTab extends StatefulWidget {
  const AdmServiciosTab({super.key});
  @override
  State<AdmServiciosTab> createState() => _AdmServiciosState();
}

class _AdmServiciosState extends State<AdmServiciosTab> {
  List<Map<String, dynamic>> _svcs = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await SB.getServicios(); if (mounted) setState(() => _svcs = s);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirm(context, 'Eliminar servicio', '¿Confirmar eliminación?')) return;
    await SB.deleteServicio(id); _load();
    if (mounted) _snack(context, 'Servicio eliminado', err: true);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8),
      child: ElevatedButton.icon(onPressed: () => showDialog(context: context,
          builder: (_) => NuevoServicioDialog(onOk: _load)),
          icon: const Icon(Icons.add), label: const Text('Nuevo Servicio'))),
    Expanded(child: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _svcs.length,
        itemBuilder: (_, i) {
          final s = _svcs[i];
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
            child: Row(children: [
              Text(s['icono']?.toString() ?? '✂️', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(s['descripcion']?.toString() ?? '', style: const TextStyle(color: C.muted, fontSize: 12)),
                const SizedBox(height: 5),
                Wrap(spacing: 6, children: [
                  _badge('S/${(s['precio'] as num).toInt()}', C.gold),
                  _badge('${s['duracion_min']}min', C.muted),
                  _badge('+${s['puntos_otorga']}pts', C.info),
                ]),
              ])),
              Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit_outlined, color: C.gold, size: 18),
                    onPressed: () => showDialog(context: context,
                        builder: (_) => EditServicioDialog(svc: s, onOk: _load))),
                IconButton(icon: const Icon(Icons.delete_outline, color: C.err, size: 18),
                    onPressed: () => _eliminar(s['id'].toString())),
              ]),
            ]));
        }))),
  ]);
}

// ────────────────────────────────────────────────────────────
// ADMIN MEMBRESÍA (planes EDITABLES desde admin)
// ────────────────────────────────────────────────────────────
class AdmMembresiaTab extends StatefulWidget {
  const AdmMembresiaTab({super.key});
  @override
  State<AdmMembresiaTab> createState() => _AdmMembresiaState();
}

class _AdmMembresiaState extends State<AdmMembresiaTab> {
  List<Map<String, dynamic>> _planes = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SB.getPlanes(); if (mounted) setState(() => _planes = p);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirm(context, 'Eliminar plan', '¿Confirmar eliminación?')) return;
    await SB.deletePlan(id); _load();
    if (mounted) _snack(context, 'Plan eliminado', err: true);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8),
      child: ElevatedButton.icon(
        onPressed: () => showDialog(context: context,
            builder: (_) => PlanDialog(onOk: _load)),
        icon: const Icon(Icons.add), label: const Text('Nuevo Plan de Membresía'))),
    Expanded(child: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: _planes.isEmpty
          ? const Center(child: Text('Sin planes configurados', style: TextStyle(color: C.muted)))
          : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _planes.length,
              itemBuilder: (_, i) {
                final p = _planes[i];
                final beneficios = (p['beneficios'] as List?)?.cast<String>() ?? [];
                return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(p['nombre'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(children: [
                        RichText(text: TextSpan(children: [
                          TextSpan(text: 'S/${(p['precio'] as num).toInt()}',
                              style: const TextStyle(color: C.gold, fontSize: 18, fontWeight: FontWeight.bold)),
                          TextSpan(text: '/${p['periodo']}',
                              style: const TextStyle(color: C.muted, fontSize: 12)),
                        ])),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.edit_outlined, color: C.gold, size: 18),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                            onPressed: () => showDialog(context: context,
                                builder: (_) => PlanDialog(plan: p, onOk: _load))),
                        const SizedBox(width: 4),
                        IconButton(icon: const Icon(Icons.delete_outline, color: C.err, size: 18),
                            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                            onPressed: () => _eliminar(p['id'].toString())),
                      ]),
                    ]),
                    if ((p['descripcion'] ?? '').toString().isNotEmpty)
                      Text(p['descripcion'].toString(), style: const TextStyle(color: C.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4,
                        children: beneficios.map((b) => _badge('✅ $b', C.ok)).toList()),
                    const SizedBox(height: 8),
                    _badge('Orden: ${p['orden']}', C.muted),
                  ]));
              }))),
  ]);
}

// ────────────────────────────────────────────────────────────
// DIALOG: PLAN MEMBRESÍA (crear / editar)
// ────────────────────────────────────────────────────────────
class PlanDialog extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onOk;
  const PlanDialog({super.key, this.plan, required this.onOk});
  @override
  State<PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<PlanDialog> {
  final _fk = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.plan?['nombre']?.toString() ?? '');
  late final _pre = TextEditingController(text: widget.plan != null ? (widget.plan!['precio'] as num).toInt().toString() : '');
  late final _des = TextEditingController(text: widget.plan?['descripcion']?.toString() ?? '');
  late final _ord = TextEditingController(text: widget.plan?['orden']?.toString() ?? '0');
  late String _periodo = widget.plan?['periodo']?.toString() ?? 'mes';
  // Beneficios como lista editable
  final List<TextEditingController> _benCtrls = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final bens = (widget.plan?['beneficios'] as List?)?.cast<String>() ?? [];
    for (final b in bens) _benCtrls.add(TextEditingController(text: b));
    if (_benCtrls.isEmpty) _benCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _nom.dispose(); _pre.dispose(); _des.dispose(); _ord.dispose();
    for (final c in _benCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    final bens = _benCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final data = {
      'nombre': _nom.text.trim(), 'precio': double.tryParse(_pre.text) ?? 0,
      'periodo': _periodo, 'descripcion': _des.text.trim(),
      'beneficios': bens, 'activo': true, 'orden': int.tryParse(_ord.text) ?? 0,
    };
    if (widget.plan == null) {
      await SB.addPlan(data);
    } else {
      await SB.updatePlan(widget.plan!['id'].toString(), data);
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    widget.onOk();
    _snack(context, widget.plan == null ? 'Plan creado ✓' : 'Plan actualizado ✓');
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _dlgHead(widget.plan == null ? 'Nuevo Plan' : 'Editar Plan', context),
        const SizedBox(height: 14),
        _F(c: _nom, label: 'Nombre del plan', val: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _F(c: _pre, label: 'Precio S/', kb: TextInputType.number,
              val: (v) => (v == null || double.tryParse(v) == null) ? 'Inválido' : null)),
          const SizedBox(width: 10),
          Expanded(child: _drop<String>(val: _periodo, label: 'Período',
            items: const [
              DropdownMenuItem(value: 'mes', child: Text('Por mes')),
              DropdownMenuItem(value: 'año', child: Text('Por año')),
            ], onChange: (v) => setState(() => _periodo = v ?? 'mes'))),
        ]),
        const SizedBox(height: 10),
        _F(c: _des, label: 'Descripción (opcional)', lines: 2),
        const SizedBox(height: 10),
        _F(c: _ord, label: 'Orden de visualización', kb: TextInputType.number),
        const SizedBox(height: 14),
        const Text('BENEFICIOS (uno por línea)', style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 8),
        ..._benCtrls.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(child: TextFormField(
              controller: e.value, style: const TextStyle(color: C.txt),
              decoration: InputDecoration(labelText: 'Beneficio ${e.key+1}',
                  suffixIcon: _benCtrls.length > 1
                      ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: C.err, size: 18),
                          onPressed: () => setState(() { _benCtrls[e.key].dispose(); _benCtrls.removeAt(e.key); }))
                      : null))),
          ]))),
        TextButton.icon(
          onPressed: () => setState(() => _benCtrls.add(TextEditingController())),
          icon: const Icon(Icons.add, size: 16, color: C.gold),
          label: const Text('Agregar beneficio', style: TextStyle(color: C.gold, fontSize: 13))),
        const SizedBox(height: 16),
        _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
            : ElevatedButton(onPressed: _guardar,
                child: Text(widget.plan == null ? 'Crear plan' : 'Guardar cambios')),
      ]))));
}

// ────────────────────────────────────────────────────────────
// ADMIN REPORTES
// ────────────────────────────────────────────────────────────
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesState();
}

class _ReportesState extends State<ReportesScreen> {
  Map<String, dynamic> _r = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await SB.reportes();
    if (mounted) setState(() { _r = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final pops = (_r['populares'] as List<MapEntry<String, int>>?) ?? [];
    final maxV = pops.isEmpty ? 1 : pops.first.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: RefreshIndicator(color: C.gold, onRefresh: _load,
        child: _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
            : ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            _stat('📊', '${_r['total'] ?? 0}', 'Total citas'),
            const SizedBox(width: 12),
            _stat('💰', 'S/${(_r['ingTotal'] ?? 0.0).toInt()}', 'Ingresos totales'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _stat('✅', '${_r['completadas'] ?? 0}', 'Completadas'),
            const SizedBox(width: 12),
            _stat('❌', '${_r['canceladas'] ?? 0}', 'Canceladas'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _stat('👥', '${_r['clientes'] ?? 0}', 'Clientes'),
            const SizedBox(width: 12),
            _stat('👑', '${_r['vip'] ?? 0}', 'VIP activos'),
          ]),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SERVICIOS MÁS POPULARES',
                  style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 14),
              if (pops.isEmpty) const Center(child: Text('Sin datos aún', style: TextStyle(color: C.muted)))
              else ...pops.map((e) => Padding(padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(e.key, style: const TextStyle(fontSize: 13)),
                      Text('${e.value}', style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 5),
                    ClipRRect(borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(value: e.value / maxV,
                            backgroundColor: C.d3, color: C.gold, minHeight: 7)),
                  ]))),
            ])),
        ])),
    );
  }
}

// ────────────────────────────────────────────────────────────
// ADMIN PROMOCIONES
// ────────────────────────────────────────────────────────────
class AdmPromoScreen extends StatefulWidget {
  const AdmPromoScreen({super.key});
  @override
  State<AdmPromoScreen> createState() => _AdmPromoState();
}

class _AdmPromoState extends State<AdmPromoScreen> {
  List<Map<String, dynamic>> _promos = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SB.getPromociones(); if (mounted) setState(() => _promos = p);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirm(context, 'Eliminar promoción', '¿Confirmar?')) return;
    await SB.deletePromocion(id); _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Promociones')),
    floatingActionButton: FloatingActionButton(
      backgroundColor: C.gold, foregroundColor: C.black,
      onPressed: () => showDialog(context: context,
          builder: (_) => NuevaPromoDialog(onOk: _load)),
      child: const Icon(Icons.add)),
    body: RefreshIndicator(color: C.gold, onRefresh: _load,
      child: _promos.isEmpty
          ? const Center(child: Text('Sin promociones', style: TextStyle(color: C.muted)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _promos.length,
              itemBuilder: (_, i) {
                final p = _promos[i];
                return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.d2, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.brd)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(p['titulo'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      _badge('${p['descuento']}% OFF', C.gold),
                    ]),
                    const SizedBox(height: 4),
                    Text(p['descripcion']?.toString() ?? '', style: const TextStyle(color: C.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Hasta: ${_fmtFecha(p['valida_hasta']?.toString() ?? '')}',
                          style: const TextStyle(color: C.muted, fontSize: 11)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: C.err, size: 20),
                          onPressed: () => _eliminar(p['id'].toString())),
                    ]),
                  ]));
              })),
  );
}

// ────────────────────────────────────────────────────────────
// DIALOGS CRUD: NUEVO CLIENTE, NUEVO SERVICIO, EDITAR SERVICIO,
//               NUEVA PROMOCIÓN
// ────────────────────────────────────────────────────────────

class NuevoClienteDialog extends StatefulWidget {
  final VoidCallback onOk;
  const NuevoClienteDialog({super.key, required this.onOk});
  @override
  State<NuevoClienteDialog> createState() => _NuevoClienteState();
}

class _NuevoClienteState extends State<NuevoClienteDialog> {
  final _fk = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _cel = TextEditingController();
  final _eml = TextEditingController();
  final _pas = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { for (final c in [_nom,_cel,_eml,_pas]) c.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    if (await SB.celularExiste(_cel.text.trim())) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Celular ya registrado', err: true); return;
    }
    await SB.registrar(nombre: _nom.text.trim(), celular: _cel.text.trim(),
        pass: _pas.text, email: _eml.text.trim());
    if (!mounted) return;
    Navigator.pop(context); widget.onOk();
    _snack(context, 'Cliente registrado ✓');
  }

  @override
  Widget build(BuildContext context) => Dialog(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
    child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgHead('Nuevo Cliente', context), const SizedBox(height: 14),
      _F(c: _nom, label: 'Nombre completo', val: (v) => (v == null || v.trim().length < 3) ? 'Requerido' : null),
      const SizedBox(height: 10),
      _F(c: _cel, label: 'Celular', hint: '987654321', kb: TextInputType.phone,
          fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          val: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (v.length != 9) return '9 dígitos';
            if (!v.startsWith('9')) return 'Empieza con 9';
            return null;
          }),
      const SizedBox(height: 10),
      _F(c: _eml, label: 'Email (opcional)', kb: TextInputType.emailAddress),
      const SizedBox(height: 10),
      _F(c: _pas, label: 'Contraseña inicial', obs: true,
          val: (v) => (v == null || v.length < 6) ? 'Mín. 6 caracteres' : null),
      const SizedBox(height: 18),
      _loading ? const Center(child: CircularProgressIndicator(color: C.gold))
          : ElevatedButton(onPressed: _guardar, child: const Text('Registrar cliente')),
    ]))));
}

class NuevoServicioDialog extends StatefulWidget {
  final VoidCallback onOk;
  const NuevoServicioDialog({super.key, required this.onOk});
  @override
  State<NuevoServicioDialog> createState() => _NuevoSvcState();
}

class _NuevoSvcState extends State<NuevoServicioDialog> {
  final _fk = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _des = TextEditingController();
  final _pre = TextEditingController();
  final _dur = TextEditingController();
  final _pts = TextEditingController();
  final _ico = TextEditingController(text: '✂️');

  @override
  void dispose() { for (final c in [_nom,_des,_pre,_dur,_pts,_ico]) c.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    await SB.addServicio({
      'nombre': _nom.text.trim(), 'descripcion': _des.text.trim(),
      'precio': double.tryParse(_pre.text) ?? 0,
      'duracion_min': int.tryParse(_dur.text) ?? 30,
      'puntos_otorga': int.tryParse(_pts.text) ?? 5,
      'icono': _ico.text.isNotEmpty ? _ico.text : '✂️', 'activo': true,
    });
    if (!mounted) return;
    Navigator.pop(context); widget.onOk();
    _snack(context, 'Servicio creado ✓');
  }

  @override
  Widget build(BuildContext context) => Dialog(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
    child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgHead('Nuevo Servicio', context), const SizedBox(height: 14),
      _F(c: _nom, label: 'Nombre', val: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
      const SizedBox(height: 10),
      _F(c: _des, label: 'Descripción'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _F(c: _pre, label: 'Precio S/', kb: TextInputType.number,
            val: (v) => (v == null || double.tryParse(v) == null) ? 'Inválido' : null)),
        const SizedBox(width: 10),
        Expanded(child: _F(c: _dur, label: 'Duración (min)', kb: TextInputType.number,
            val: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _F(c: _pts, label: 'Puntos', kb: TextInputType.number,
            val: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null)),
        const SizedBox(width: 10),
        Expanded(child: _F(c: _ico, label: 'Ícono emoji')),
      ]),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: _guardar, child: const Text('Guardar servicio')),
    ]))));
}

class EditServicioDialog extends StatefulWidget {
  final Map<String, dynamic> svc;
  final VoidCallback onOk;
  const EditServicioDialog({super.key, required this.svc, required this.onOk});
  @override
  State<EditServicioDialog> createState() => _EditSvcState();
}

class _EditSvcState extends State<EditServicioDialog> {
  final _fk = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.svc['nombre']?.toString() ?? '');
  late final _des = TextEditingController(text: widget.svc['descripcion']?.toString() ?? '');
  late final _pre = TextEditingController(text: (widget.svc['precio'] as num?)?.toInt().toString() ?? '');
  late final _dur = TextEditingController(text: widget.svc['duracion_min']?.toString() ?? '30');
  late final _pts = TextEditingController(text: widget.svc['puntos_otorga']?.toString() ?? '5');
  late final _ico = TextEditingController(text: widget.svc['icono']?.toString() ?? '✂️');

  @override
  void dispose() { for (final c in [_nom,_des,_pre,_dur,_pts,_ico]) c.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    await SB.updateServicio(widget.svc['id'].toString(), {
      'nombre': _nom.text.trim(), 'descripcion': _des.text.trim(),
      'precio': double.tryParse(_pre.text) ?? 0,
      'duracion_min': int.tryParse(_dur.text) ?? 30,
      'puntos_otorga': int.tryParse(_pts.text) ?? 5,
      'icono': _ico.text.isNotEmpty ? _ico.text : '✂️',
    });
    if (!mounted) return;
    Navigator.pop(context); widget.onOk();
    _snack(context, 'Servicio actualizado ✓');
  }

  @override
  Widget build(BuildContext context) => Dialog(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
    child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgHead('Editar Servicio', context), const SizedBox(height: 14),
      _F(c: _nom, label: 'Nombre', val: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
      const SizedBox(height: 10),
      _F(c: _des, label: 'Descripción'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _F(c: _pre, label: 'Precio S/', kb: TextInputType.number,
            val: (v) => (v == null || double.tryParse(v) == null) ? 'Inválido' : null)),
        const SizedBox(width: 10),
        Expanded(child: _F(c: _dur, label: 'Duración (min)', kb: TextInputType.number,
            val: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _F(c: _pts, label: 'Puntos', kb: TextInputType.number,
            val: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null)),
        const SizedBox(width: 10),
        Expanded(child: _F(c: _ico, label: 'Ícono emoji')),
      ]),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: _guardar, child: const Text('Guardar cambios')),
    ]))));
}

class NuevaPromoDialog extends StatefulWidget {
  final VoidCallback onOk;
  const NuevaPromoDialog({super.key, required this.onOk});
  @override
  State<NuevaPromoDialog> createState() => _NuevaPromoState();
}

class _NuevaPromoState extends State<NuevaPromoDialog> {
  final _fk = GlobalKey<FormState>();
  final _tit = TextEditingController();
  final _des = TextEditingController();
  final _pct = TextEditingController();
  DateTime _hasta = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() { _tit.dispose(); _des.dispose(); _pct.dispose(); super.dispose(); }

  Future<void> _guardar() async {
    if (!_fk.currentState!.validate()) return;
    await SB.addPromocion({
      'titulo': _tit.text.trim(), 'descripcion': _des.text.trim(),
      'descuento': int.tryParse(_pct.text) ?? 0,
      'valida_hasta': DateFormat('yyyy-MM-dd').format(_hasta), 'activa': true,
    });
    if (!mounted) return;
    Navigator.pop(context); widget.onOk();
    _snack(context, 'Promoción publicada ✓');
  }

  @override
  Widget build(BuildContext context) => Dialog(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
    child: Form(key: _fk, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _dlgHead('Nueva Promoción', context), const SizedBox(height: 14),
      _F(c: _tit, label: 'Título', val: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
      const SizedBox(height: 10),
      _F(c: _des, label: 'Descripción', lines: 2),
      const SizedBox(height: 10),
      _F(c: _pct, label: 'Descuento (%)', kb: TextInputType.number,
          val: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null),
      const SizedBox(height: 10),
      ListTile(contentPadding: EdgeInsets.zero,
        title: Text('Válida hasta: ${DateFormat('dd/MM/yyyy').format(_hasta)}',
            style: const TextStyle(color: C.txt, fontSize: 14)),
        trailing: const Icon(Icons.calendar_today, color: C.gold, size: 18),
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _hasta,
            firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (_, ch) => Theme(data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: C.gold)), child: ch!));
          if (d != null) setState(() => _hasta = d);
        }),
      const SizedBox(height: 18),
      ElevatedButton(onPressed: _guardar, child: const Text('Publicar promoción')),
    ]))));
}
