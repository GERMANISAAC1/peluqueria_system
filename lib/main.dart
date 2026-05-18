import 'dart:math';
import 'package:flutter/material.dart';

// ============================================================
//  PUNTO DE ENTRADA
// ============================================================
void main() => runApp(const GymControlPro());

// ============================================================
//  DATOS DE DEMO — Clientes, productos, accesos e ingresos
// ============================================================

/// Lista de clientes ficticios con nombres peruanos
final List<Map<String, dynamic>> demoClients = [
  {"id":"001","name":"Carlos Mendoza Ríos",       "plan":"Mensual",    "status":"Activo",  "vence":"15 Jun 2025","asistencias":18,"avatar":"CM","color":Colors.blue},
  {"id":"002","name":"Lucía Paredes Villanueva",   "plan":"Trimestral", "status":"Activo",  "vence":"30 Jul 2025","asistencias":34,"avatar":"LP","color":Colors.purple},
  {"id":"003","name":"Jorge Castillo Huanca",      "plan":"Anual",      "status":"Activo",  "vence":"01 Ene 2026","asistencias":52,"avatar":"JC","color":Colors.teal},
  {"id":"004","name":"Milagros Quispe Arce",       "plan":"Mensual",    "status":"Vencido", "vence":"01 May 2025","asistencias":7, "avatar":"MQ","color":Colors.orange},
  {"id":"005","name":"Andrés Torres Lozano",       "plan":"Semestral",  "status":"Activo",  "vence":"20 Sep 2025","asistencias":41,"avatar":"AT","color":Colors.green},
  {"id":"006","name":"Valeria Flores Chávez",      "plan":"Mensual",    "status":"Activo",  "vence":"22 Jun 2025","asistencias":12,"avatar":"VF","color":Colors.pink},
  {"id":"007","name":"Héctor Mamani Condori",      "plan":"Trimestral", "status":"Vencido", "vence":"10 Abr 2025","asistencias":3, "avatar":"HM","color":Colors.red},
  {"id":"008","name":"Daniela Soto Ramírez",       "plan":"Anual",      "status":"Activo",  "vence":"15 Mar 2026","asistencias":67,"avatar":"DS","color":Colors.cyan},
  {"id":"009","name":"Ricardo Vega Palomino",      "plan":"Mensual",    "status":"Activo",  "vence":"28 Jun 2025","asistencias":21,"avatar":"RV","color":Colors.amber},
  {"id":"010","name":"Paola Núñez Rojas",          "plan":"Semestral",  "status":"Activo",  "vence":"05 Nov 2025","asistencias":38,"avatar":"PN","color":Colors.indigo},
];

/// Productos de la tienda con precios reales en soles
final List<Map<String, dynamic>> demoProducts = [
  {"name":"Proteína Whey Gold", "brand":"Optimum Nutrition","price":189.90,"stock":14,"icon":Icons.science,             "color":const Color(0xFF4FC3F7)},
  {"name":"Creatina Monohidrato","brand":"MuscleTech",       "price":65.00, "stock":8, "icon":Icons.bolt,                "color":const Color(0xFFFFB74D)},
  {"name":"BCAA 2:1:1",         "brand":"Scitec Nutrition",  "price":79.90, "stock":22,"icon":Icons.bubble_chart,        "color":const Color(0xFF81C784)},
  {"name":"Pre-Entreno C4",     "brand":"Cellucor",          "price":120.00,"stock":5, "icon":Icons.local_fire_department,"color":const Color(0xFFE57373)},
  {"name":"Multivitamínico",    "brand":"Animal Pak",        "price":95.00, "stock":30,"icon":Icons.medication,          "color":const Color(0xFFBA68C8)},
  {"name":"Shaker Pro 700ml",   "brand":"BlenderBottle",     "price":39.90, "stock":17,"icon":Icons.sports_bar,          "color":const Color(0xFF4DB6AC)},
];

/// Ingresos mensuales en soles (Enero–Diciembre 2025)
final List<double> monthlyRevenue = [5800,6200,5400,7100,6800,7900,8200,7600,8450,9100,8700,9300];
final List<String> months = ['E','F','M','A','M','J','J','A','S','O','N','D'];

/// Historial de accesos del día de hoy
final List<Map<String, dynamic>> todayAccess = [
  {"name":"Carlos Mendoza Ríos",     "hora":"06:02","status":"Permitido","avatar":"CM"},
  {"name":"Daniela Soto Ramírez",    "hora":"06:18","status":"Permitido","avatar":"DS"},
  {"name":"Andrés Torres Lozano",    "hora":"06:45","status":"Permitido","avatar":"AT"},
  {"name":"Héctor Mamani Condori",   "hora":"07:10","status":"Denegado", "avatar":"HM"},
  {"name":"Valeria Flores Chávez",   "hora":"07:33","status":"Permitido","avatar":"VF"},
  {"name":"Jorge Castillo Huanca",   "hora":"08:01","status":"Permitido","avatar":"JC"},
  {"name":"Paola Núñez Rojas",       "hora":"08:22","status":"Permitido","avatar":"PN"},
  {"name":"Milagros Quispe Arce",    "hora":"08:55","status":"Denegado", "avatar":"MQ"},
  {"name":"Ricardo Vega Palomino",   "hora":"09:14","status":"Permitido","avatar":"RV"},
  {"name":"Lucía Paredes Villanueva","hora":"09:40","status":"Permitido","avatar":"LP"},
];

// ============================================================
//  APP ROOT
// ============================================================
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
        primaryColor: const Color(0xFFE63939),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF151515),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE63939),
          surface: Color(0xFF151515),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0A),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================
//  PANTALLA DE LOGIN
//  Selector de rol, campos de correo/contraseña y
//  un banner informativo del gimnasio de demo.
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email    = TextEditingController(text: "admin@gymcontrolpro.pe");
  final _password = TextEditingController(text: "••••••••");
  bool _loading = false;
  bool _obscure = true;
  String _role = "admin";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C1C1C), Color(0xFF0A0A0A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63939),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.fitness_center, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 28),
                const Text(
                  "GymControl\nPro",
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.5),
                ),
                const SizedBox(height: 6),
                const Text("Sistema de Gestión Premium",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 15)),
                const SizedBox(height: 36),

                // Selector de rol
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [
                    _roleBtn("admin",   "Admin"),
                    _roleBtn("trainer", "Entrenador"),
                    _roleBtn("client",  "Cliente"),
                  ]),
                ),
                const SizedBox(height: 24),

                // Campo correo
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "Correo electrónico",
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF888888)),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Campo contraseña
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF888888)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF888888)),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text("¿Olvidaste tu contraseña?",
                        style: TextStyle(color: Color(0xFFE63939))),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón de login
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE63939),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _loading ? null : () {
                      setState(() => _loading = true);
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        Navigator.pushReplacement(context,
                            MaterialPageRoute(builder: (_) => MainScreen(role: _role)));
                      });
                    },
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text("INICIAR SESIÓN",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 32),

                // Banner de la demo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("DEMO — Gym Fitness Chimbote",
                          style: TextStyle(color: Color(0xFFE63939), fontSize: 12,
                              fontWeight: FontWeight.w700, letterSpacing: 1)),
                      SizedBox(height: 6),
                      Text("248 clientes activos  •  S/ 8,450 este mes\n"
                           "12 membresías por vencer  •  94 asistencias hoy",
                          style: TextStyle(color: Color(0xFF888888), fontSize: 13, height: 1.6)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleBtn(String value, String label) {
    final sel = _role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _role = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFE63939) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
                color: sel ? Colors.white : const Color(0xFF888888),
              )),
        ),
      ),
    );
  }
}

// ============================================================
//  SHELL PRINCIPAL — BottomNavigationBar con IndexedStack
//  IndexedStack conserva el estado de cada pestaña.
// ============================================================
class MainScreen extends StatefulWidget {
  final String role;
  const MainScreen({super.key, required this.role});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
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
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          border: Border(top: BorderSide(color: Color(0xFF222222))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFE63939),
          unselectedItemColor: const Color(0xFF555555),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded),    label: "Inicio"),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined),  label: "Clientes"),
            BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner),      label: "Acceso"),
            BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined),  label: "Tienda"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline),       label: "Perfil"),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  DASHBOARD
//  - Tarjeta destacada de ingresos del mes
//  - Grid 2x2 de KPIs (clientes, asistencias, vencidas)
//  - Gráfico de barras dibujado con CustomPainter (sin deps)
//  - Últimos 4 accesos del día
// ============================================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("GymControl Pro"),
        actions: [
          Stack(children: [
            IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
            Positioned(right: 10, top: 10,
              child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFE63939), shape: BoxShape.circle))),
          ]),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(radius: 18, backgroundColor: Color(0xFFE63939),
              child: Text("AD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Buenos días, Admin 👋",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const Text("Lunes, 19 de Mayo 2025",
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 20),

            // Tarjeta de ingresos del mes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE63939), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ingresos este mes",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text("S/ 8,450.00",
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("↑ 18% vs mes anterior",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grid de KPIs
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _statCard("Clientes Activos",    "236", Icons.people_alt,       Colors.blue,   "+12 este mes"),
                _statCard("Asistencias Hoy",     "94",  Icons.directions_run,   Colors.green,  "Pico: 09:00 AM"),
                _statCard("Vencen esta semana",  "7",   Icons.warning_amber,    Colors.orange, "Requieren aviso"),
                _statCard("Membresías Vencidas", "12",  Icons.cancel_outlined,  Colors.red,    "Sin renovar"),
              ],
            ),
            const SizedBox(height: 24),

            // Gráfico de ingresos con CustomPainter
            const Text("Ingresos 2025",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CustomPaint(
                painter: BarChartPainter(
                  values: monthlyRevenue,
                  labels: months,
                  activeIndex: 8, // Septiembre = mes activo en el demo
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Últimos accesos del día
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Últimas Asistencias",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton(onPressed: () {},
                    child: const Text("Ver todo", style: TextStyle(color: Color(0xFFE63939)))),
              ],
            ),
            ...todayAccess.take(4).map(_accessTile),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 20),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
              color: color, letterSpacing: -1)),
        ]),
        const Spacer(),
        Text(title, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
      ]),
    );
  }

  Widget _accessTile(Map<String, dynamic> a) {
    final ok = a["status"] == "Permitido";
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: ok ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          child: Text(a["avatar"], style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold, color: ok ? Colors.green : Colors.red)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a["name"], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(a["hora"], style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: ok ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(a["status"],
              style: TextStyle(color: ok ? Colors.green : Colors.red,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ============================================================
//  CUSTOM PAINTER: Gráfico de barras (sin dependencias externas)
//  Dibuja las barras de ingresos mensuales con Canvas.
//  La barra del mes activo se resalta en rojo.
// ============================================================
class BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final int activeIndex;

  BarChartPainter({required this.values, required this.labels, required this.activeIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.reduce(max);
    final barW   = (size.width - 16) / values.length - 4;
    final chartH = size.height - 24;

    final inactive = Paint()..color = const Color(0xFF2A2A2A)..style = PaintingStyle.fill;
    final active   = Paint()..color = const Color(0xFFE63939)..style = PaintingStyle.fill;

    for (int i = 0; i < values.length; i++) {
      final barH = (values[i] / maxVal) * chartH;
      final x    = i * ((size.width - 16) / values.length) + 8;
      final top  = chartH - barH;

      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, top, barW, barH),
            topLeft: const Radius.circular(5), topRight: const Radius.circular(5)),
        i == activeIndex ? active : inactive,
      );

      // Etiqueta del mes debajo de cada barra
      final tp = TextPainter(
        text: TextSpan(text: labels[i],
            style: const TextStyle(color: Color(0xFF555555), fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================
//  CLIENTES
//  - Buscador en tiempo real por nombre
//  - Filtro por estado (Todos / Activo / Vencido)
//  - Barra de progreso de asistencias por cliente
//  - Bottom sheet con detalle completo y botón de renovación
// ============================================================
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _filter = "Todos";
  final _search = TextEditingController();

  List<Map<String, dynamic>> get _filtered {
    var list = demoClients;
    if (_filter != "Todos") list = list.where((c) => c["status"] == _filter).toList();
    if (_search.text.isNotEmpty)
      list = list.where((c) =>
          (c["name"] as String).toLowerCase().contains(_search.text.toLowerCase())).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Clientes"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              icon: const Icon(Icons.add, color: Color(0xFFE63939)),
              label: const Text("Nuevo", style: TextStyle(color: Color(0xFFE63939))),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Buscar cliente...",
              prefixIcon: const Icon(Icons.search, color: Color(0xFF888888)),
              filled: true, fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Filtros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: ["Todos","Activo","Vencido"].map((f) {
            final sel = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFE63939) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f, style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ),
            );
          }).toList()),
        ),

        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            itemBuilder: (ctx, i) {
              final c = _filtered[i];
              final active = c["status"] == "Activo";
              return GestureDetector(
                onTap: () => _showDetail(ctx, c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF151515), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: (c["color"] as Color).withOpacity(0.2),
                      child: Text(c["avatar"], style: TextStyle(
                          color: c["color"] as Color, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c["name"], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text("${c["plan"]}  •  Vence: ${c["vence"]}",
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(height: 6),
                      // Barra de progreso de asistencias
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (c["asistencias"] as int) / 80,
                            backgroundColor: const Color(0xFF2A2A2A),
                            color: c["color"] as Color,
                            minHeight: 4,
                          ),
                        )),
                        const SizedBox(width: 8),
                        Text("${c["asistencias"]} asist.",
                            style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
                      ]),
                    ])),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c["status"], style: TextStyle(
                          color: active ? Colors.green : Colors.red,
                          fontSize: 11, fontWeight: FontWeight.w600)),
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

  void _showDetail(BuildContext context, Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: (c["color"] as Color).withOpacity(0.2),
              child: Text(c["avatar"], style: TextStyle(
                  color: c["color"] as Color, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c["name"], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text("ID: #${c["id"]}", style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ]),
          ]),
          const Divider(height: 28, color: Color(0xFF222222)),
          _row("Plan",        c["plan"]),
          _row("Estado",      c["status"]),
          _row("Vence",       c["vence"]),
          _row("Asistencias", "${c["asistencias"]} este mes"),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF333333)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Cerrar"),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63939),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Renovar"),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 14)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  );
}

// ============================================================
//  ACCESO QR
//  - Animación de línea de escaneo con AnimationController
//  - Simulación de escaneo con cliente aleatorio
//  - Resultado visual según estado de membresía
//  - Historial de accesos del día con iconos de aprobación
// ============================================================
class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});
  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _scanned = false;
  Map<String, dynamic>? _lastClient;

  @override
  void initState() {
    super.initState();
    // La línea de escaneo sube y baja en un ciclo de 2 segundos
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _simulateScan() {
    final client = demoClients[Random().nextInt(demoClients.length)];
    setState(() { _scanned = true; _lastClient = client; });
    // El resultado se oculta automáticamente a los 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scanned = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Control de Acceso")),
      body: Column(children: [
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Marco con línea animada
          Stack(alignment: Alignment.center, children: [
            Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _scanned
                      ? (_lastClient!["status"] == "Activo" ? Colors.green : Colors.red)
                      : const Color(0xFFE63939),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _scanned
                  ? Center(child: Icon(
                      _lastClient!["status"] == "Activo"
                          ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 80,
                      color: _lastClient!["status"] == "Activo" ? Colors.green : Colors.red))
                  : const Center(child: Icon(Icons.qr_code_scanner,
                      size: 100, color: Color(0xFF333333))),
            ),
            if (!_scanned)
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Positioned(
                  top: 20 + _anim.value * 220,
                  child: Container(width: 220, height: 2,
                      color: const Color(0xFFE63939).withOpacity(0.7)),
                ),
              ),
          ]),
          const SizedBox(height: 24),

          // Resultado del escaneo
          if (_scanned && _lastClient != null) ...[
            Text(
              _lastClient!["status"] == "Activo" ? "✅ Acceso Permitido" : "❌ Membresía Vencida",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: _lastClient!["status"] == "Activo" ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 8),
            Text(_lastClient!["name"],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text("${_lastClient!["plan"]}  •  Vence: ${_lastClient!["vence"]}",
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ] else ...[
            const Text("Escanea el QR del cliente",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text("Apunta la cámara al código QR",
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ],
          const SizedBox(height: 32),

          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("SIMULAR ESCANEO"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63939),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _simulateScan,
          ),
        ])),

        // Historial del día
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Accesos de Hoy",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: todayAccess.length,
                itemBuilder: (_, i) {
                  final a = todayAccess[i];
                  final ok = a["status"] == "Permitido";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: ok ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                        child: Text(a["avatar"], style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.bold, color: ok ? Colors.green : Colors.red)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(a["name"], style: const TextStyle(fontSize: 13))),
                      Text(a["hora"], style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                      const SizedBox(width: 10),
                      Icon(ok ? Icons.check_circle : Icons.cancel,
                          color: ok ? Colors.green : Colors.red, size: 16),
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
}

// ============================================================
//  TIENDA FITNESS
//  - Productos con precio, marca y stock real
//  - Carrito con contador acumulativo en el ícono del AppBar
//  - Dialog de carrito con total y opción de vaciar/pagar
//  - SnackBar confirmatorio al agregar producto
// ============================================================
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int _cartCount = 0;
  double _cartTotal = 0;

  void _addToCart(double price, String name) {
    setState(() { _cartCount++; _cartTotal += price; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("$name agregado al carrito"),
      duration: const Duration(seconds: 1),
      backgroundColor: const Color(0xFF222222),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tienda Fitness"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(alignment: Alignment.center, children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: _cartCount > 0 ? () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text("Carrito de compras"),
                    content: Text("$_cartCount producto(s)\nTotal: S/ ${_cartTotal.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 16)),
                    actions: [
                      TextButton(onPressed: () {
                        setState(() { _cartCount = 0; _cartTotal = 0; });
                        Navigator.pop(context);
                      }, child: const Text("Vaciar")),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63939)),
                        child: const Text("Pagar"),
                      ),
                    ],
                  ),
                ) : null,
              ),
              if (_cartCount > 0) Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Color(0xFFE63939), shape: BoxShape.circle),
                  child: Text("$_cartCount", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text("Suplementos & Accesorios",
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.75,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
            ),
            itemCount: demoProducts.length,
            itemBuilder: (ctx, i) {
              final p = demoProducts[i];
              return Container(
                decoration: BoxDecoration(
                    color: const Color(0xFF151515), borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Imagen del producto
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: (p["color"] as Color).withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    child: Center(child: Icon(p["icon"] as IconData,
                        size: 54, color: p["color"] as Color)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p["name"], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(p["brand"], style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("S/ ${(p["price"] as double).toStringAsFixed(2)}",
                            style: const TextStyle(color: Color(0xFFE63939),
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text("${p["stock"]} und.",
                            style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
                      ]),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity, height: 34,
                        child: ElevatedButton(
                          onPressed: () => _addToCart(p["price"] as double, p["name"]),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE63939), padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Agregar",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ============================================================
//  PERFIL
//  - Datos del administrador (nombre, rol, correo, gimnasio)
//  - Mini-estadísticas del gimnasio
//  - QR personal de acceso
//  - Menú de opciones con chevron
//  - Botón de cierre de sesión con limpieza de pila de rutas
// ============================================================
class ProfileScreen extends StatelessWidget {
  final String role;
  const ProfileScreen({super.key, required this.role});

  String get _roleName {
    switch (role) {
      case "admin":   return "Administrador";
      case "trainer": return "Entrenador";
      default:        return "Cliente";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Stack(children: [
                const CircleAvatar(radius: 44, backgroundColor: Color(0xFFE63939),
                  child: Text("AD", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
                Positioned(right: 0, bottom: 0, child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF222222), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                )),
              ]),
              const SizedBox(height: 14),
              const Text("Luis Alberto García",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_roleName, style: const TextStyle(color: Color(0xFF888888), fontSize: 14)),
              const SizedBox(height: 2),
              const Text("admin@gymcontrolpro.pe",
                  style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63939).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("Gym Fitness Chimbote",
                    style: TextStyle(color: Color(0xFFE63939),
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Mini-estadísticas
          Row(children: [
            _mini("248",     "Clientes"),
            const SizedBox(width: 12),
            _mini("S/ 8,450","Ingresos"),
            const SizedBox(width: 12),
            _mini("94",      "Hoy"),
          ]),
          const SizedBox(height: 16),

          // QR personal
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              const Text("Tu código QR de acceso",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 16),
              Container(
                width: 160, height: 160, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.qr_code_2, size: 100, color: Colors.black),
                  Text("ID: #00001",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 12),
              const Text("Gym Fitness Chimbote • Membresía Anual",
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),

          // Menú
          _menuItem(Icons.settings_outlined,    "Configuración del Gimnasio", () {}),
          _menuItem(Icons.receipt_long_outlined, "Historial de Pagos",         () {}),
          _menuItem(Icons.people_outline,        "Gestión de Entrenadores",    () {}),
          _menuItem(Icons.bar_chart_outlined,    "Reportes y Estadísticas",    () {}),
          _menuItem(Icons.help_outline,          "Ayuda y Soporte",            () {}),
          const SizedBox(height: 8),

          // Cerrar sesión
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Color(0xFFE63939)),
              label: const Text("Cerrar Sesión",
                  style: TextStyle(color: Color(0xFFE63939), fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE63939)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
            ),
          ),
          const SizedBox(height: 24),
          const Text("GymControl Pro v2.1.0\n© 2025 Todos los derechos reservados",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF444444), fontSize: 11, height: 1.6)),
        ]),
      ),
    );
  }

  Widget _mini(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFE63939))),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
      ]),
    ),
  );

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF888888), size: 20),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        const Icon(Icons.chevron_right, color: Color(0xFF444444), size: 20),
      ]),
    ),
  );
}
