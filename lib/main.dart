import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ╔══════════════════════════════════════════════════════════════╗
//  GYMCONTROL PRO — Dark Luxury Fitness
//  Paleta: Negro carbón · Dorado metálico · Rojo coral
//  Psicología:
//    · Negro  → poder, exclusividad, seriedad
//    · Dorado → premium, éxito, prosperidad
//    · Rojo   → energía, urgencia, acción
// ╚══════════════════════════════════════════════════════════════╝
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const GymControlPro());
}

// ─── TOKENS DE DISEÑO ───────────────────────────────────────────
class AppColors {
  // Fondo profundo con matiz azul-negro (más sofisticado que negro puro)
  static const bg0 = Color(0xFF080B12);
  static const bg1 = Color(0xFF0F1420);
  static const bg2 = Color(0xFF161C2E);
  static const bg3 = Color(0xFF1E2640);

  // Dorado metálico — psicología: riqueza, éxito, premium
  static const gold     = Color(0xFFD4A843);
  static const goldDim  = Color(0xFF8A6C25);
  static const goldGlow = Color(0x33D4A843);

  // Rojo coral — psicología: energía, urgencia, vitalidad
  static const red      = Color(0xFFE8433A);
  static const redDark  = Color(0xFFB02E27);
  static const redGlow  = Color(0x40E8433A);

  // Esmeralda — éxito, salud, crecimiento
  static const green    = Color(0xFF2DD4A0);
  static const greenDim = Color(0xFF1A7A5E);

  // Textos
  static const textPrimary   = Color(0xFFF0F2FF);
  static const textSecondary = Color(0xFF7A8AAD);
  static const textMuted     = Color(0xFF3D4A66);

  // Bordes y separadores
  static const border    = Color(0xFF1F2B47);
  static const borderGold= Color(0x40D4A843);
}

class AppGradients {
  static const heroRed = LinearGradient(
    colors: [Color(0xFFE8433A), Color(0xFF8B1A16)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const heroGold = LinearGradient(
    colors: [Color(0xFFD4A843), Color(0xFF8A6C25)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const card = LinearGradient(
    colors: [Color(0xFF1A2236), Color(0xFF0F1420)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const darkBg = LinearGradient(
    colors: [Color(0xFF080B12), Color(0xFF0C1022)],
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
  );
}

// ─── DATOS DE DEMO ───────────────────────────────────────────────
final List<Map<String, dynamic>> demoClients = [
  {"id":"C-001","name":"Carlos Mendoza Ríos",       "plan":"Premium Anual",  "status":"Activo",  "vence":"15 Dic 2025","asistencias":72,"avatar":"CM","hue":210.0,"monto":480.0},
  {"id":"C-002","name":"Lucía Paredes Villanueva",   "plan":"Trimestral",     "status":"Activo",  "vence":"30 Jul 2025","asistencias":34,"avatar":"LP","hue":270.0,"monto":240.0},
  {"id":"C-003","name":"Jorge Castillo Huanca",      "plan":"Premium Anual",  "status":"Activo",  "vence":"01 Ene 2026","asistencias":88,"avatar":"JC","hue":160.0,"monto":480.0},
  {"id":"C-004","name":"Milagros Quispe Arce",       "plan":"Mensual",        "status":"Vencido", "vence":"01 May 2025","asistencias":7, "avatar":"MQ","hue":30.0, "monto":80.0},
  {"id":"C-005","name":"Andrés Torres Lozano",       "plan":"Semestral",      "status":"Activo",  "vence":"20 Sep 2025","asistencias":55,"avatar":"AT","hue":120.0,"monto":300.0},
  {"id":"C-006","name":"Valeria Flores Chávez",      "plan":"Mensual",        "status":"Activo",  "vence":"22 Jun 2025","asistencias":18,"avatar":"VF","hue":330.0,"monto":80.0},
  {"id":"C-007","name":"Héctor Mamani Condori",      "plan":"Trimestral",     "status":"Vencido", "vence":"10 Abr 2025","asistencias":4, "avatar":"HM","hue":0.0,  "monto":240.0},
  {"id":"C-008","name":"Daniela Soto Ramírez",       "plan":"Premium Anual",  "status":"Activo",  "vence":"15 Mar 2026","asistencias":91,"avatar":"DS","hue":190.0,"monto":480.0},
  {"id":"C-009","name":"Ricardo Vega Palomino",      "plan":"Mensual",        "status":"Activo",  "vence":"28 Jun 2025","asistencias":29,"avatar":"RV","hue":45.0, "monto":80.0},
  {"id":"C-010","name":"Paola Núñez Rojas",          "plan":"Semestral",      "status":"Activo",  "vence":"05 Nov 2025","asistencias":47,"avatar":"PN","hue":240.0,"monto":300.0},
];

final List<Map<String, dynamic>> demoProducts = [
  {"name":"Whey Protein Gold","brand":"Optimum Nutrition","price":189.90,"oldPrice":229.90,"stock":14,"tag":"MÁS VENDIDO","icon":Icons.science,              "hue":210.0},
  {"name":"Creatina Monohidrato","brand":"MuscleTech",    "price":65.00, "oldPrice":null,  "stock":8, "tag":"",          "icon":Icons.bolt,                 "hue":45.0},
  {"name":"BCAA 2:1:1 400g",  "brand":"Scitec Nutrition", "price":79.90, "oldPrice":99.90, "stock":22,"tag":"OFERTA",    "icon":Icons.bubble_chart,         "hue":150.0},
  {"name":"Pre-Entreno C4",   "brand":"Cellucor",          "price":120.00,"oldPrice":null,  "stock":5, "tag":"ÚLTIMAS",  "icon":Icons.local_fire_department,"hue":0.0},
  {"name":"Multivitamínico",  "brand":"Animal Pak",        "price":95.00, "oldPrice":110.00,"stock":30,"tag":"",         "icon":Icons.medication,           "hue":280.0},
  {"name":"Shaker Pro 700ml", "brand":"BlenderBottle",     "price":39.90, "oldPrice":null,  "stock":17,"tag":"NUEVO",    "icon":Icons.sports_bar,           "hue":180.0},
];

final List<double> revenue = [5.8,6.2,5.4,7.1,6.8,7.9,8.2,7.6,8.45,9.1,8.7,9.3];
final List<String> months  = ['E','F','M','A','M','J','J','A','S','O','N','D'];

final List<Map<String,dynamic>> accessLog = [
  {"name":"Carlos Mendoza Ríos",     "hora":"06:02 AM","ok":true, "avatar":"CM"},
  {"name":"Daniela Soto Ramírez",    "hora":"06:18 AM","ok":true, "avatar":"DS"},
  {"name":"Andrés Torres Lozano",    "hora":"06:45 AM","ok":true, "avatar":"AT"},
  {"name":"Héctor Mamani Condori",   "hora":"07:10 AM","ok":false,"avatar":"HM"},
  {"name":"Valeria Flores Chávez",   "hora":"07:33 AM","ok":true, "avatar":"VF"},
  {"name":"Jorge Castillo Huanca",   "hora":"08:01 AM","ok":true, "avatar":"JC"},
  {"name":"Paola Núñez Rojas",       "hora":"08:22 AM","ok":true, "avatar":"PN"},
  {"name":"Milagros Quispe Arce",    "hora":"08:55 AM","ok":false,"avatar":"MQ"},
  {"name":"Ricardo Vega Palomino",   "hora":"09:14 AM","ok":true, "avatar":"RV"},
  {"name":"Lucía Paredes Villanueva","hora":"09:40 AM","ok":true, "avatar":"LP"},
];

// ─── APP ROOT ────────────────────────────────────────────────────
class GymControlPro extends StatelessWidget {
  const GymControlPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymControl Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg0,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.gold,
          secondary: AppColors.red,
          surface: AppColors.bg2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ─── WIDGETS COMUNES ─────────────────────────────────────────────

// Tarjeta con glassmorphism (borde sutil + fondo degradado)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Gradient? gradient;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

// Etiqueta de estado (Activo / Vencido)
class StatusBadge extends StatelessWidget {
  final String text;
  final bool active;
  const StatusBadge({super.key, required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.green.withOpacity(0.12) : AppColors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: active ? AppColors.green.withOpacity(0.4) : AppColors.red.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(
          color: active ? AppColors.green : AppColors.red,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3,
        )),
      ]),
    );
  }
}

// Avatar con inicial sobre fondo coloreado por hue
class HueAvatar extends StatelessWidget {
  final String initials;
  final double hue;
  final double radius;

  const HueAvatar({super.key, required this.initials, required this.hue, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final color = HSLColor.fromAHSL(1, hue, 0.7, 0.5).toColor();
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(
        child: Text(initials, style: TextStyle(
          color: Colors.white, fontSize: radius * 0.65,
          fontWeight: FontWeight.w800, letterSpacing: 0.5,
        )),
      ),
    );
  }
}

// Botón primario con gradiente y sombra de brillo
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Gradient gradient;
  final IconData? icon;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.gradient = AppGradients.heroRed,
    this.icon,
    this.height = 54,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) { _ac.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _ac.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (widget.gradient == AppGradients.heroGold ? AppColors.gold : AppColors.red)
                    .withOpacity(0.35),
                blurRadius: 20, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
            Text(widget.label, style: const TextStyle(
              color: Colors.white, fontSize: 15,
              fontWeight: FontWeight.w800, letterSpacing: 1.0,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  LOGIN SCREEN
//  Psicología: el logo grande + dorado genera confianza inmediata.
//  El degradado oscuro comunica premium. El rojo en el CTA activa.
// ══════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController(text: "admin@gymcontrolpro.pe");
  final _passwordCtrl = TextEditingController(text: "Admin2025#");
  bool _obscure  = true;
  bool _loading  = false;
  String _role   = "admin";

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() { _fadeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Fondo con puntos de luz decorativos
        Container(decoration: const BoxDecoration(gradient: AppGradients.darkBg)),
        Positioned(top: -80, right: -60,
          child: Container(width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.gold.withOpacity(0.12), Colors.transparent])))),
        Positioned(bottom: -60, left: -40,
          child: Container(width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.red.withOpacity(0.10), Colors.transparent])))),

        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Logo premium
                const SizedBox(height: 16),
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: AppGradients.heroGold,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 16, offset: const Offset(0,4))],
                    ),
                    child: const Icon(Icons.fitness_center, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("GymControl", style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary, letterSpacing: -0.5,
                    )),
                    ShaderMask(
                      shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                      child: const Text("PRO", style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3,
                        color: Colors.white,
                      )),
                    ),
                  ]),
                ]),
                const SizedBox(height: 40),

                // Headline
                const Text("Bienvenido\nde vuelta", style: TextStyle(
                  fontSize: 38, fontWeight: FontWeight.w900, height: 1.1,
                  color: AppColors.textPrimary, letterSpacing: -1.2,
                )),
                const SizedBox(height: 8),
                const Text("Gestión premium para tu gimnasio", style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary,
                )),
                const SizedBox(height: 36),

                // Selector de rol
                GlassCard(
                  padding: const EdgeInsets.all(5),
                  radius: 16,
                  child: Row(children: [
                    _roleChip("admin",   "Admin",       Icons.shield_outlined),
                    _roleChip("trainer", "Entrenador",  Icons.sports_martial_arts),
                    _roleChip("client",  "Cliente",     Icons.person_outline),
                  ]),
                ),
                const SizedBox(height: 22),

                // Campo email
                _buildField(
                  controller: _emailCtrl,
                  label: "Correo electrónico",
                  icon: Icons.alternate_email,
                ),
                const SizedBox(height: 14),

                // Campo contraseña
                _buildField(
                  controller: _passwordCtrl,
                  label: "Contraseña",
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textMuted, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text("¿Olvidaste tu contraseña?", style: TextStyle(
                    color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w600,
                  )),
                ),
                const SizedBox(height: 28),

                // CTA principal — rojo activa urgencia de acción
                _loading
                    ? Center(child: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          gradient: AppGradients.heroRed,
                          boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 16)],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      ))
                    : GradientButton(
                        label: "INGRESAR AL SISTEMA",
                        icon: Icons.arrow_forward_rounded,
                        gradient: AppGradients.heroRed,
                        height: 56,
                        onTap: () {
                          setState(() => _loading = true);
                          Future.delayed(const Duration(milliseconds: 1400), () {
                            Navigator.pushReplacement(context,
                                MaterialPageRoute(builder: (_) => MainScreen(role: _role)));
                          });
                        },
                      ),
                const SizedBox(height: 36),

                // Info del demo — uso social proof para generar confianza
                GlassCard(
                  borderColor: AppColors.borderGold,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppGradients.heroGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("DEMO EN VIVO", style: TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1,
                        )),
                      ),
                      const SizedBox(width: 10),
                      const Text("Gym Fitness Chimbote", style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12,
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _demoStat("S/ 8,450", "Ingresos mes"),
                      _divider(),
                      _demoStat("248", "Clientes"),
                      _divider(),
                      _demoStat("94", "Asistencias hoy"),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _roleChip(String val, String label, IconData icon) {
    final sel = _role == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: sel ? AppGradients.heroGold : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel ? [BoxShadow(color: AppColors.goldGlow, blurRadius: 12)] : null,
          ),
          child: Column(children: [
            Icon(icon, size: 18, color: sel ? Colors.white : AppColors.textMuted),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? Colors.white : AppColors.textMuted,
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _demoStat(String val, String label) {
    return Expanded(child: Column(children: [
      ShaderMask(
        shaderCallback: (b) => AppGradients.heroGold.createShader(b),
        child: Text(val, style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5,
        )),
      ),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          textAlign: TextAlign.center),
    ]));
  }

  Widget _divider() => Container(width: 1, height: 36, color: AppColors.border);
}

// ══════════════════════════════════════════════════════════════════
//  MAIN SHELL — BottomNav con indicador dorado
// ══════════════════════════════════════════════════════════════════
class MainScreen extends StatefulWidget {
  final String role;
  const MainScreen({super.key, required this.role});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardScreen(),
      const ClientsScreen(),
      const AccessScreen(),
      const StoreScreen(),
      ProfileScreen(role: widget.role),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bg1,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(children: [
              _navItem(0, Icons.grid_view_rounded,     "Inicio"),
              _navItem(1, Icons.people_alt_outlined,   "Clientes"),
              _navItem(2, Icons.qr_code_scanner,       "Acceso"),
              _navItem(3, Icons.storefront_outlined,   "Tienda"),
              _navItem(4, Icons.person_outline_rounded,"Perfil"),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final sel = _idx == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idx = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Punto indicador superior
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: sel ? 24 : 0, height: sel ? 2 : 0,
              margin: EdgeInsets.only(bottom: sel ? 6 : 0),
              decoration: BoxDecoration(
                gradient: AppGradients.heroGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(icon,
              size: 22,
              color: sel ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              fontSize: 10,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? AppColors.gold : AppColors.textMuted,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  DASHBOARD
//  Layout: métricas de alto impacto arriba (ingresos en grande),
//  KPIs visuales, gráfico custom, accesos recientes.
//  Psicología: verde = crecimiento, dorado = riqueza, rojo = alerta
// ══════════════════════════════════════════════════════════════════
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: CustomScrollView(
        slivers: [
          // AppBar personalizado con gradiente
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.bg0,
            flexibleSpace: FlexibleSpaceBar(
              background: _heroHeader(),
            ),
            actions: [
              _notifIcon(),
              const SizedBox(width: 16),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // KPI Grid — 2 x 2
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _kpiCard("236",  "Clientes Activos", Icons.people_alt_rounded,  AppColors.green, "+12 nuevos"),
                  _kpiCard("94",   "Asistencias Hoy",  Icons.directions_run,      AppColors.gold,  "Pico 09:00 AM"),
                  _kpiCard("7",    "Vencen Pronto",    Icons.hourglass_bottom,    AppColors.red,   "Próximos 7 días"),
                  _kpiCard("12",   "Sin Renovar",      Icons.warning_amber_rounded,const Color(0xFFFF9500),"Acción requerida"),
                ],
              ),
              const SizedBox(height: 24),

              // Gráfico de ingresos
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Ingresos 2025", style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.3,
                )),
                ShaderMask(
                  shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                  child: const Text("S/ 89,200 total", style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                  )),
                ),
              ]),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(12, 20, 16, 14),
                child: SizedBox(
                  height: 180,
                  child: CustomPaint(
                    painter: _PremiumBarChart(revenue, months, 8),
                    size: Size.infinite,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Accesos recientes
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Accesos Recientes", style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, letterSpacing: -0.3,
                )),
                Text("Ver todos →", style: TextStyle(
                  color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ]),
              const SizedBox(height: 12),
              ...accessLog.take(5).map(_recentAccess),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _heroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1420), Color(0xFF080B12)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [
        // Orbe decorativo
        Positioned(right: -30, top: 10,
          child: Container(width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [AppColors.goldGlow, Colors.transparent],
                radius: 0.7,
              )))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text("Sistema activo", style: TextStyle(
                    color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            const Text("Buenos días,\nAdmin 👋", style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900,
              color: AppColors.textPrimary, height: 1.2, letterSpacing: -0.8,
            )),
            const SizedBox(height: 16),
            // Ingreso del mes — número grande genera impacto
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ShaderMask(
                shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                child: const Text("S/ 8,450", style: TextStyle(
                  fontSize: 44, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -2,
                )),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.green.withOpacity(0.3)),
                  ),
                  child: const Text("↑ 18%", style: TextStyle(
                    color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w800,
                  )),
                ),
              ),
            ]),
            const Text("Ingresos de mayo 2025", style: TextStyle(
              color: AppColors.textSecondary, fontSize: 12,
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _notifIcon() {
    return Stack(children: [
      Container(
        margin: const EdgeInsets.only(top: 8),
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppColors.bg2, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textSecondary),
      ),
      Positioned(right: 6, top: 10,
        child: Container(width: 8, height: 8,
          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle))),
    ]);
  }

  Widget _kpiCard(String value, String label, IconData icon, Color color, String sub) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Text(value, style: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w900,
            color: color, letterSpacing: -1,
          )),
        ]),
        const Spacer(),
        Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500,
        )),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _recentAccess(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: a["ok"] ? AppColors.green.withOpacity(0.12) : AppColors.red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(a["avatar"], style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: a["ok"] ? AppColors.green : AppColors.red,
          ))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a["name"], style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
          )),
          Text(a["hora"], style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: a["ok"] ? AppColors.green.withOpacity(0.1) : AppColors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: a["ok"] ? AppColors.green.withOpacity(0.3) : AppColors.red.withOpacity(0.3),
            ),
          ),
          child: Text(a["ok"] ? "Permitido" : "Denegado", style: TextStyle(
            color: a["ok"] ? AppColors.green : AppColors.red,
            fontSize: 11, fontWeight: FontWeight.w700,
          )),
        ),
      ]),
    );
  }
}

// ─── GRÁFICO DE BARRAS PREMIUM ────────────────────────────────────
class _PremiumBarChart extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final int activeIdx;

  _PremiumBarChart(this.data, this.labels, this.activeIdx);

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = data.reduce(max);
    final n      = data.length;
    final barW   = (size.width - 24) / n - 6;
    final chartH = size.height - 28;

    // Líneas guía horizontales (4 niveles)
    final guidePaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 4; i++) {
      final y = chartH - (chartH / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guidePaint);
    }

    for (int i = 0; i < n; i++) {
      final barH  = (data[i] / maxVal) * chartH;
      final x     = i * ((size.width - 24) / n) + 12;
      final top   = chartH - barH;
      final isAct = i == activeIdx;

      final paint = Paint()
        ..shader = (isAct
            ? AppGradients.heroGold
            : LinearGradient(
                colors: [AppColors.bg3, AppColors.bg3.withOpacity(0.3)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ))
            .createShader(Rect.fromLTWH(x, top, barW, barH))
        ..style = PaintingStyle.fill;

      final rr = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top, barW, barH),
        topLeft: const Radius.circular(6), topRight: const Radius.circular(6),
      );
      canvas.drawRRect(rr, paint);

      // Brillo en barra activa
      if (isAct) {
        canvas.drawRRect(rr, Paint()
          ..shader = LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.transparent],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)
            .createShader(Rect.fromLTWH(x, top, barW, barH)));
      }

      // Etiqueta del mes
      final span = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isAct ? AppColors.gold : AppColors.textMuted,
          fontSize: 10,
          fontWeight: isAct ? FontWeight.w800 : FontWeight.w400,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════
//  CLIENTES
// ══════════════════════════════════════════════════════════════════
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _filter = "Todos";
  final _search = TextEditingController();

  List<Map<String, dynamic>> get _list {
    var l = demoClients;
    if (_filter == "Activo")  l = l.where((c) => c["status"] == "Activo").toList();
    if (_filter == "Vencido") l = l.where((c) => c["status"] == "Vencido").toList();
    if (_search.text.isNotEmpty)
      l = l.where((c) => (c["name"] as String).toLowerCase()
          .contains(_search.text.toLowerCase())).toList();
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final active  = demoClients.where((c) => c["status"] == "Activo").length;
    final expired = demoClients.where((c) => c["status"] == "Vencido").length;

    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text("Clientes", style: TextStyle(
          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
        )),
        backgroundColor: AppColors.bg0,
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppGradients.heroGold,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 10)],
              ),
              child: const Row(children: [
                Icon(Icons.add, size: 16, color: Colors.white),
                SizedBox(width: 4),
                Text("Nuevo", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Resumen rápido
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            Expanded(child: _quickStat("$active", "Activos", AppColors.green)),
            const SizedBox(width: 10),
            Expanded(child: _quickStat("$expired", "Vencidos", AppColors.red)),
            const SizedBox(width: 10),
            Expanded(child: _quickStat("${demoClients.length}", "Total", AppColors.gold)),
          ]),
        ),
        const SizedBox(height: 14),

        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "Buscar por nombre o ID...",
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chips de filtro
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: ["Todos", "Activo", "Vencido"].map((f) {
            final sel = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel
                      ? (f == "Vencido" ? AppGradients.heroRed : AppGradients.heroGold)
                      : null,
                  color: sel ? null : AppColors.bg2,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: sel ? Colors.transparent : AppColors.border),
                  boxShadow: sel ? [BoxShadow(
                    color: (f == "Vencido" ? AppColors.red : AppColors.gold).withOpacity(0.3),
                    blurRadius: 10,
                  )] : null,
                ),
                child: Text(f, style: TextStyle(
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
            );
          }).toList()),
        ),
        const SizedBox(height: 12),

        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _list.length,
            itemBuilder: (ctx, i) {
              final c = _list[i];
              final ok = c["status"] == "Activo";
              final color = HSLColor.fromAHSL(1, c["hue"], 0.7, 0.5).toColor();
              return GestureDetector(
                onTap: () => _showDetail(ctx, c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(children: [
                    // Barra de color superior (señal visual del status)
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0)]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        HueAvatar(initials: c["avatar"], hue: c["hue"]),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c["name"], style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                          )),
                          const SizedBox(height: 2),
                          Text("${c["plan"]}  ·  ${c["id"]}", style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11,
                          )),
                          const SizedBox(height: 6),
                          // Barra de asistencias coloreada
                          Stack(children: [
                            Container(height: 4, decoration: BoxDecoration(
                              color: AppColors.bg3, borderRadius: BorderRadius.circular(4),
                            )),
                            FractionallySizedBox(
                              widthFactor: ((c["asistencias"] as int) / 100).clamp(0.0, 1.0),
                              child: Container(height: 4, decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
                                borderRadius: BorderRadius.circular(4),
                              )),
                            ),
                          ]),
                        ])),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          StatusBadge(text: c["status"], active: ok),
                          const SizedBox(height: 6),
                          Text("${c["asistencias"]} asist.", style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10,
                          )),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _quickStat(String val, String label, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(children: [
        Container(width: 4, height: 36,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5,
          )),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ]),
      ]),
    );
  }

  void _showDetail(BuildContext ctx, Map<String, dynamic> c) {
    final ok    = c["status"] == "Activo";
    final color = HSLColor.fromAHSL(1, c["hue"], 0.7, 0.5).toColor();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Tirador
          Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),

          Row(children: [
            HueAvatar(initials: c["avatar"], hue: c["hue"], radius: 30),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c["name"], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                StatusBadge(text: c["status"], active: ok),
                const SizedBox(width: 8),
                Text(c["id"], style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ])),
          ]),

          const SizedBox(height: 20),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Detalle
          _dRow("Plan",         c["plan"]),
          _dRow("Vence el",     c["vence"]),
          _dRow("Asistencias",  "${c["asistencias"]} este mes"),
          _dRow("Aportado",     "S/ ${c["monto"].toStringAsFixed(2)}"),

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: Text("Cerrar", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(
              label: ok ? "VER RUTINA" : "RENOVAR",
              gradient: ok ? AppGradients.heroGold : AppGradients.heroRed,
              height: 48,
              onTap: () => Navigator.pop(ctx),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _dRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(v, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════
//  ACCESO QR
//  Animación de escaneo + historial del día
// ══════════════════════════════════════════════════════════════════
class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});
  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late Animation<double> _scanAnim;
  Map<String, dynamic>? _result;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 2));
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
    _scanCtrl.repeat(reverse: true);
  }

  @override
  void dispose() { _scanCtrl.dispose(); super.dispose(); }

  void _simulate() {
    setState(() { _scanning = true; _result = null; });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final c = demoClients[Random().nextInt(demoClients.length)];
      setState(() { _scanning = false; _result = c; });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _result = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text("Control de Acceso", style: TextStyle(
          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
        )),
        backgroundColor: AppColors.bg0,
      ),
      body: Column(children: [
        // Panel de escáner
        Expanded(
          flex: 3,
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

            // Resultado del escaneo
            if (_result != null) ...[
              _scanResult(_result!),
            ] else if (_scanning) ...[
              const SizedBox(height: 20),
              const Text("Analizando código...", style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14,
              )),
              const SizedBox(height: 20),
            ],

            // Marco del escáner
            Stack(alignment: Alignment.center, children: [
              // Halo de brillo
              Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (_result == null ? AppColors.goldGlow : (_result!["status"] == "Activo"
                        ? AppColors.green.withOpacity(0.15) : AppColors.redGlow)),
                    Colors.transparent,
                  ]),
                ),
              ),
              // Marco principal
              Container(
                width: 230, height: 230,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _result == null
                        ? AppColors.gold
                        : (_result!["status"] == "Activo" ? AppColors.green : AppColors.red),
                    width: 2.5,
                  ),
                ),
              ),
              // Esquinas decorativas
              ..._corners(_result == null
                  ? AppColors.gold
                  : (_result!["status"] == "Activo" ? AppColors.green : AppColors.red)),

              // Contenido interior
              if (_scanning)
                const SizedBox(
                  width: 50, height: 50,
                  child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                )
              else if (_result != null)
                Icon(
                  _result!["status"] == "Activo" ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 72,
                  color: _result!["status"] == "Activo" ? AppColors.green : AppColors.red,
                )
              else
                const Icon(Icons.qr_code_2_rounded, size: 80, color: AppColors.textMuted),

              // Línea de escaneo animada
              if (_result == null && !_scanning)
                AnimatedBuilder(
                  animation: _scanAnim,
                  builder: (_, __) => Positioned(
                    top: 16 + _scanAnim.value * 196,
                    child: Container(
                      width: 196, height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent, AppColors.gold, Colors.transparent,
                        ]),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 6)],
                      ),
                    ),
                  ),
                ),
            ]),

            const SizedBox(height: 28),
            GradientButton(
              label: _scanning ? "ESCANEANDO..." : "SIMULAR ESCANEO QR",
              icon: _scanning ? null : Icons.qr_code_scanner,
              gradient: AppGradients.heroGold,
              onTap: _scanning ? null : _simulate,
              height: 52,
            ),
          ])),
        ),

        // Historial del día
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Accesos de Hoy", style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
              )),
              Text("${accessLog.where((a) => a["ok"]).length} permitidos  "
                   "· ${accessLog.where((a) => !a["ok"]).length} denegados",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: ListView.builder(
                itemCount: accessLog.length,
                itemBuilder: (_, i) {
                  final a = accessLog[i];
                  final ok = a["ok"] as bool;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: ok ? AppColors.green.withOpacity(0.12) : AppColors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text(a["avatar"], style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: ok ? AppColors.green : AppColors.red,
                        ))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(a["name"], style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600,
                      ))),
                      Text(a["hora"], style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11,
                      )),
                      const SizedBox(width: 8),
                      Icon(ok ? Icons.check_circle : Icons.cancel,
                        color: ok ? AppColors.green : AppColors.red, size: 15),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _scanResult(Map<String, dynamic> c) {
    final ok    = c["status"] == "Activo";
    final color = ok ? AppColors.green : AppColors.red;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? "Acceso Permitido" : "Membresía Vencida",
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          Text(c["name"], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text("${c["plan"]}  ·  Vence: ${c["vence"]}",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
      ]),
    );
  }

  // Esquinas decorativas del marco del escáner
  List<Widget> _corners(Color color) {
    const s = 20.0; // tamaño de la esquina
    const t = 3.0;  // grosor
    const r = 28.0; // radio del marco
    return [
      _corner(color, -110, -110, s, t, true,  true,  r),
      _corner(color,  110, -110, s, t, false, true,  r),
      _corner(color, -110,  110, s, t, true,  false, r),
      _corner(color,  110,  110, s, t, false, false, r),
    ];
  }

  Widget _corner(Color color, double dx, double dy, double s, double t,
      bool left, bool top, double r) {
    return Positioned(
      left: 115 + dx,
      top:  115 + dy,
      child: Container(
        width: s, height: s,
        decoration: BoxDecoration(
          border: Border(
            left:   left  ? BorderSide(color: color, width: t) : BorderSide.none,
            right: !left  ? BorderSide(color: color, width: t) : BorderSide.none,
            top:    top   ? BorderSide(color: color, width: t) : BorderSide.none,
            bottom: !top  ? BorderSide(color: color, width: t) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft:     left  && top  ? Radius.circular(r) : Radius.zero,
            topRight:   !left  && top  ? Radius.circular(r) : Radius.zero,
            bottomLeft:  left  && !top ? Radius.circular(r) : Radius.zero,
            bottomRight:!left  && !top ? Radius.circular(r) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TIENDA
//  Psicología de ventas: precio tachado, badges de escasez,
//  "OFERTA" en rojo, "MÁS VENDIDO" en dorado, carrito acumulativo
// ══════════════════════════════════════════════════════════════════
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int    _cartCount = 0;
  double _cartTotal = 0;

  void _add(Map<String, dynamic> p) {
    setState(() { _cartCount++; _cartTotal += p["price"] as double; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
        const SizedBox(width: 8),
        Text("${p["name"]} agregado", style: const TextStyle(color: AppColors.textPrimary)),
      ]),
      backgroundColor: AppColors.bg2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      appBar: AppBar(
        title: const Text("Tienda Fitness", style: TextStyle(
          color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800,
        )),
        backgroundColor: AppColors.bg0,
        actions: [
          GestureDetector(
            onTap: _cartCount > 0 ? _showCart : null,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _cartCount > 0 ? AppColors.bg2 : AppColors.bg2.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cartCount > 0 ? AppColors.gold : AppColors.border),
              ),
              child: Row(children: [
                Icon(Icons.shopping_bag_outlined,
                  color: _cartCount > 0 ? AppColors.gold : AppColors.textMuted, size: 18),
                if (_cartCount > 0) ...[
                  const SizedBox(width: 6),
                  Text("$_cartCount", style: const TextStyle(
                    color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13,
                  )),
                ],
              ]),
            ),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner de oferta — urgencia social
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppGradients.heroRed,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: AppColors.redGlow, blurRadius: 14, offset: const Offset(0,4))],
          ),
          child: const Row(children: [
            Icon(Icons.local_fire_department, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("¡Ofertas de temporada! Hasta 22% de descuento",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
            ),
            itemCount: demoProducts.length,
            itemBuilder: (ctx, i) {
              final p = demoProducts[i];
              final hue   = p["hue"] as double;
              final color = HSLColor.fromAHSL(1, hue, 0.7, 0.55).toColor();
              final tag   = p["tag"] as String;
              final hasDis= p["oldPrice"] != null;

              return GestureDetector(
                onTap: () => _add(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Zona de imagen
                    Stack(children: [
                      Container(
                        height: 105,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.15), color.withOpacity(0.04)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Center(child: Icon(p["icon"] as IconData, size: 52, color: color)),
                      ),

                      // Badge de tag (MÁS VENDIDO / OFERTA / ÚLTIMAS / NUEVO)
                      if (tag.isNotEmpty)
                        Positioned(top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: tag == "MÁS VENDIDO" ? AppGradients.heroGold : AppGradients.heroRed,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [BoxShadow(
                                color: (tag == "MÁS VENDIDO" ? AppColors.gold : AppColors.red).withOpacity(0.4),
                                blurRadius: 6,
                              )],
                            ),
                            child: Text(tag, style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w800, letterSpacing: 0.5,
                            )),
                          ),
                        ),

                      // Indicador de stock bajo
                      if ((p["stock"] as int) < 8)
                        Positioned(top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg0.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.red.withOpacity(0.4)),
                            ),
                            child: Text("${p["stock"]} und.", style: const TextStyle(
                              color: AppColors.red, fontSize: 9, fontWeight: FontWeight.w700,
                            )),
                          ),
                        ),
                    ]),

                    // Info del producto
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p["name"] as String, style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700,
                        ), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(p["brand"] as String, style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10,
                        )),
                        const SizedBox(height: 8),

                        // Precio con descuento tachado — psicología del precio
                        if (hasDis)
                          Text("S/ ${(p["oldPrice"] as double).toStringAsFixed(2)}", style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          )),
                        ShaderMask(
                          shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                          child: Text(
                            "S/ ${(p["price"] as double).toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Botón de agregar
                        Container(
                          width: double.infinity,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: AppGradients.heroGold,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 8)],
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_shopping_cart, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text("Agregar", style: TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                            )),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          const Row(children: [
            Icon(Icons.shopping_bag_outlined, color: AppColors.gold),
            SizedBox(width: 10),
            Text("Carrito de compras", style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
            )),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bg2, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("$_cartCount producto(s)", style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13,
                )),
                const SizedBox(height: 4),
                ShaderMask(
                  shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                  child: Text("S/ ${_cartTotal.toStringAsFixed(2)}", style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
                  )),
                ),
              ]),
              GestureDetector(
                onTap: () { setState(() { _cartCount = 0; _cartTotal = 0; }); Navigator.pop(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.red.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("Vaciar", style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          GradientButton(label: "PROCESAR PAGO", gradient: AppGradients.heroGold, icon: Icons.payment_rounded, height: 52, onTap: () => Navigator.pop(context)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  PERFIL
//  Header premium con dorado, estadísticas impactantes,
//  QR de acceso, menú de navegación y logout de cierre seguro.
// ══════════════════════════════════════════════════════════════════
class ProfileScreen extends StatelessWidget {
  final String role;
  const ProfileScreen({super.key, required this.role});

  String get _roleName => role == "admin" ? "Administrador" : role == "trainer" ? "Entrenador" : "Cliente";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg0,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.bg0,
            flexibleSpace: FlexibleSpaceBar(background: _profileHero()),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg2, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(children: [
                  Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 5),
                  Text("Editar", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(delegate: SliverChildListDelegate([

              // Stats del gimnasio
              Row(children: [
                _bigStat("248", "Clientes", AppColors.gold),
                const SizedBox(width: 10),
                _bigStat("S/ 8,450", "Ingresos", AppColors.green),
                const SizedBox(width: 10),
                _bigStat("94", "Asist. hoy", AppColors.red),
              ]),
              const SizedBox(height: 20),

              // QR Card
              GlassCard(
                borderColor: AppColors.borderGold,
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Tu código de acceso", style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                    )),
                    ShaderMask(
                      shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                      child: const Text("Premium Anual", style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700,
                      )),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    width: 150, height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 20)],
                    ),
                    child: Stack(alignment: Alignment.center, children: [
                      const Icon(Icons.qr_code_2_rounded, size: 130, color: Color(0xFF111111)),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          gradient: AppGradients.heroGold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fitness_center, size: 18, color: Colors.white),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text("ID: #00001  ·  Gym Fitness Chimbote", style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12,
                  )),
                ]),
              ),
              const SizedBox(height: 20),

              // Menú de opciones
              const Text("Configuración", style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.5,
              )),
              const SizedBox(height: 10),
              _menuItem(Icons.settings_outlined,    "Configuración del Gimnasio"),
              _menuItem(Icons.receipt_long_outlined,"Historial de Pagos"),
              _menuItem(Icons.people_outline,       "Gestión de Entrenadores"),
              _menuItem(Icons.bar_chart_outlined,   "Reportes y Estadísticas"),
              _menuItem(Icons.help_outline,         "Centro de Ayuda"),
              const SizedBox(height: 20),

              // Cierre de sesión
              GestureDetector(
                onTap: () => Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.red.withOpacity(0.4)),
                    color: AppColors.red.withOpacity(0.06),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
                    SizedBox(width: 10),
                    Text("Cerrar Sesión", style: TextStyle(
                      color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 15,
                    )),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              const Text("GymControl Pro v2.1.0 · © 2025 Todos los derechos reservados",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.6),
              ),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _profileHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1408), Color(0xFF080B12)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [
        Positioned(right: -40, top: 20,
          child: Container(width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AppColors.goldGlow, Colors.transparent])))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Avatar con borde dorado
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.heroGold,
                  boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 14)],
                ),
                child: const CircleAvatar(radius: 38, backgroundColor: AppColors.bg2,
                  child: Text("AD", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Luis Alberto García", style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
                )),
                const SizedBox(height: 4),
                Row(children: [
                  ShaderMask(
                    shaderCallback: (b) => AppGradients.heroGold.createShader(b),
                    child: const Text("● Administrador", style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                    )),
                  ),
                ]),
                const SizedBox(height: 2),
                const Text("admin@gymcontrolpro.pe", style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12,
                )),
              ])),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldGlow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderGold),
              ),
              child: const Text("🏋️  Gym Fitness Chimbote · Ancash, PE", style: TextStyle(
                color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bigStat(String val, String label, Color color) {
    return Expanded(child: GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(children: [
        Text(val, style: TextStyle(
          fontSize: val.length > 5 ? 15 : 22, fontWeight: FontWeight.w900,
          color: color, letterSpacing: -0.5,
        )),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _menuItem(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(
          fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500,
        ))),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      ]),
    );
  }
}
