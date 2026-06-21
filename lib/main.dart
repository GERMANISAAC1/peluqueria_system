// DOMÓTICA PRO v6.0 — HTTP via MethodChannel nativo
// Usa Android nativo para HTTP, garantiza que funcione igual que el navegador

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════ COLORES ════════════
class C {
  static const bg      = Color(0xFF070B14);
  static const surface = Color(0xFF0D1220);
  static const card    = Color(0xFF131A2E);
  static const cardHi  = Color(0xFF1A2340);
  static const border  = Color(0xFF1E2845);
  static const blue    = Color(0xFF4F8EF7);
  static const blueGlow= Color(0x264F8EF7);
  static const green   = Color(0xFF2ECC8E);
  static const greenGlow=Color(0x262ECC8E);
  static const orange  = Color(0xFFFF9142);
  static const orangeGlow=Color(0x26FF9142);
  static const red     = Color(0xFFFF4D6A);
  static const redGlow = Color(0x26FF4D6A);
  static const purple  = Color(0xFF9B6DFF);
  static const yellow  = Color(0xFFFFCC44);
  static const t1      = Color(0xFFF0F4FF);
  static const t2      = Color(0xFF7B8DB8);
  static const t3      = Color(0xFF3D4E78);
}

class R {
  static const xs = BorderRadius.all(Radius.circular(8));
  static const sm = BorderRadius.all(Radius.circular(12));
  static const md = BorderRadius.all(Radius.circular(18));
  static const xl = BorderRadius.all(Radius.circular(32));
}

// ════════════ ENUMS ════════════
enum ModoConexion { lan, movil, url }
extension ModoConexionX on ModoConexion {
  String get label => const ['LAN / WiFi','IP directa','URL completa'][index];
  String get hint  => const ['192.168.1.100','10.44.38.3','https://mi-tunel.ngrok.io'][index];
  String get desc  => const ['Misma red WiFi','IP pública + puerto','ngrok, Cloudflare, DDNS'][index];
  IconData get icon => [Icons.wifi_rounded,Icons.signal_cellular_alt_rounded,Icons.public_rounded][index];
  Color get color  => [C.green,C.orange,C.purple][index];
  static ModoConexion fromStr(String s) =>
      ModoConexion.values.firstWhere((e)=>e.name==s, orElse:()=>ModoConexion.lan);
}

enum TipoD { tasmota, sonoff, shelly, celular, otro }
extension TipoDX on TipoD {
  String get label => const ['Tasmota','Sonoff','Shelly','Celular','Genérico'][index];
  IconData get icon => [Icons.electrical_services_rounded,Icons.bolt_rounded,
      Icons.router_rounded,Icons.smartphone_rounded,Icons.settings_input_hdmi_rounded][index];
  Color get color  => [C.blue,C.orange,C.green,C.yellow,C.t2][index];
  String get pathOn => const ['/cm?cmnd=Power+On','/control?cmd=on',
      '/relay/0?turn=on','/flash/on','/on'][index];
  String get pathOff=> const ['/cm?cmnd=Power+Off','/control?cmd=off',
      '/relay/0?turn=off','/flash/off','/off'][index];
  static TipoD fromStr(String s) =>
      TipoD.values.firstWhere((e)=>e.name==s.toLowerCase(), orElse:()=>TipoD.otro);
}

enum CatArtefacto { luz, ventilador, televisor, aire, enchufe, calefactor, otro }
extension CatX on CatArtefacto {
  String get label => const ['Luz','Ventilador','Televisor','A/C','Enchufe','Calefactor','Otro'][index];
  IconData get icon => [Icons.light_rounded,Icons.air_rounded,Icons.tv_rounded,
      Icons.ac_unit_rounded,Icons.power_rounded,Icons.local_fire_department_rounded,
      Icons.device_unknown_rounded][index];
  Color get color  => [C.yellow,C.blue,C.purple,C.blue,C.green,C.orange,C.t2][index];
  static CatArtefacto fromStr(String s) =>
      CatArtefacto.values.firstWhere((e)=>e.name==s, orElse:()=>CatArtefacto.otro);
}

// ════════════ MODELOS ════════════
class LogEntry {
  final DateTime ts; final String msg; final bool ok;
  LogEntry(this.ts, this.msg, this.ok);
}

class Dispositivo {
  final int id; String nombre; TipoD tipo; CatArtefacto cat;
  ModoConexion modo; String ip; int puerto; String urlBase;
  String habitacion; bool encendido; DateTime? ultimaAccion; int toggleCount;

  Dispositivo({required this.id, required this.nombre, required this.tipo,
    this.cat=CatArtefacto.enchufe, this.modo=ModoConexion.lan,
    this.ip='', this.puerto=80, this.urlBase='', this.habitacion='General',
    this.encendido=false, this.ultimaAccion, this.toggleCount=0});

  String get urlOn {
    if (modo==ModoConexion.url) return urlBase.trim().replaceAll(RegExp(r'/$'),'')+tipo.pathOn;
    return 'http://${ip.trim()}:$puerto${tipo.pathOn}';
  }
  String get urlOff {
    if (modo==ModoConexion.url) return urlBase.trim().replaceAll(RegExp(r'/$'),'')+tipo.pathOff;
    return 'http://${ip.trim()}:$puerto${tipo.pathOff}';
  }
  String get conexionDisplay =>
      modo==ModoConexion.url ? (urlBase.isEmpty?'—':urlBase) : '${ip.trim()}:$puerto';

  Map<String,dynamic> toJson() => {'id':id,'nombre':nombre,'tipo':tipo.name,'cat':cat.name,
    'modo':modo.name,'ip':ip,'puerto':puerto,'urlBase':urlBase,'habitacion':habitacion,
    'encendido':encendido,'toggleCount':toggleCount,'ultimaAccion':ultimaAccion?.toIso8601String()};

  factory Dispositivo.fromJson(Map<String,dynamic> j) => Dispositivo(
    id:j['id'] as int, nombre:j['nombre'] as String,
    tipo:TipoDX.fromStr(j['tipo'] as String?? 'otro'),
    cat:CatX.fromStr(j['cat'] as String?? 'otro'),
    modo:ModoConexionX.fromStr(j['modo'] as String?? 'lan'),
    ip:j['ip'] as String?? '', puerto:j['puerto'] as int?? 80,
    urlBase:j['urlBase'] as String?? '', habitacion:j['habitacion'] as String?? 'General',
    encendido:j['encendido'] as bool?? false, toggleCount:j['toggleCount'] as int?? 0,
    ultimaAccion:j['ultimaAccion']!=null?DateTime.tryParse(j['ultimaAccion'] as String):null);

  Dispositivo copyWith({bool? encendido, DateTime? ultimaAccion, int? toggleCount}) =>
      Dispositivo(id:id,nombre:nombre,tipo:tipo,cat:cat,modo:modo,ip:ip,puerto:puerto,
        urlBase:urlBase,habitacion:habitacion,
        encendido:encendido??this.encendido,
        ultimaAccion:ultimaAccion??this.ultimaAccion,
        toggleCount:toggleCount??this.toggleCount);
}

// ════════════════════════════════════════════════════════════════
// CONTROLADOR DE RED — USA METHODCHANNEL NATIVO DE ANDROID
// ════════════════════════════════════════════════════════════════
// Por qué MethodChannel:
// El navegador de Android usa OkHttp directamente (stack nativo).
// Flutter en release usa su propio cliente HTTP que tiene restricciones
// adicionales en redes hotspot. Al llamar código nativo Android via
// MethodChannel usamos OkHttp igual que el navegador — garantiza
// el mismo comportamiento.
// ════════════════════════════════════════════════════════════════
class NetCtrl {
  static const _ch = MethodChannel('domotica/http');
  static const _timeout = 8; // segundos

  static Future<bool> _get(String url) async {
    try {
      final result = await _ch.invokeMethod<bool>('get', {
        'url': url,
        'timeout': _timeout,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[Net] PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[Net] Error: $e');
      return false;
    }
  }

  static Future<bool> _cmd(String url) async {
    if (await _get(url)) return true;
    await Future.delayed(const Duration(milliseconds: 600));
    return _get(url);
  }

  static Future<bool> encender(Dispositivo d) {
    debugPrint('[Net] ENCENDER ${d.nombre} → ${d.urlOn}');
    return _cmd(d.urlOn);
  }

  static Future<bool> apagar(Dispositivo d) {
    debugPrint('[Net] APAGAR ${d.nombre} → ${d.urlOff}');
    return _cmd(d.urlOff);
  }

  static Future<bool> pingRaw({
    required ModoConexion modo, required String ip,
    required int puerto, required String urlBase, required TipoD tipo,
  }) async {
    final url = modo==ModoConexion.url
        ? urlBase.trim()
        : 'http://${ip.trim()}:$puerto/';
    if (url.isEmpty) return false;
    return _get(url);
  }
}

// ════════════ REPOSITORIO ════════════
class DispositivoRepo {
  static const _k = 'domotica_v6';
  static List<Dispositivo> cargar(SharedPreferences p) {
    try {
      final raw = p.getString(_k);
      if (raw==null) return [];
      return (jsonDecode(raw) as List)
          .map((e)=>Dispositivo.fromJson(e as Map<String,dynamic>)).toList();
    } catch(_) { return []; }
  }
  static void guardar(SharedPreferences p, List<Dispositivo> items) =>
      p.setString(_k, jsonEncode(items.map((d)=>d.toJson()).toList()));
}

// ════════════ NOTIFIER ════════════
class DispositivosNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  List<Dispositivo> _items;
  int _nextId=1; bool _demo=false;
  final List<LogEntry> _log=[];
  final Set<int> _enProceso={};

  DispositivosNotifier(List<Dispositivo> items, this._prefs): _items=List.of(items) {
    if (_items.isNotEmpty)
      _nextId=_items.map((d)=>d.id).reduce((a,b)=>a>b?a:b)+1;
  }

  List<Dispositivo> get items => List.unmodifiable(_items);
  bool get demo => _demo;
  List<LogEntry> get log => List.unmodifiable(_log.reversed.toList());
  int get encendidos => _items.where((d)=>d.encendido).length;

  List<String> get habitaciones {
    final s=_items.map((d)=>d.habitacion).toSet().toList()..sort();
    return ['Todas',...s];
  }
  List<Dispositivo> porHabitacion(String h) =>
      h=='Todas'?_items:_items.where((d)=>d.habitacion==h).toList();

  Future<bool> toggle(int id) async {
    if (_enProceso.contains(id)) return false;
    _enProceso.add(id);
    try {
      final idx=_items.indexWhere((d)=>d.id==id);
      if (idx==-1) return false;
      final d=_items[idx];
      final estadoAntes=d.encendido;
      bool ok;
      if (_demo) {
        await Future.delayed(const Duration(milliseconds:300));
        ok=true;
      } else {
        if (estadoAntes) {
          ok=await NetCtrl.apagar(d);
        } else {
          ok=await NetCtrl.encender(d);
        }
      }
      if (ok) {
        _items[idx]=d.copyWith(
          encendido:!estadoAntes,
          ultimaAccion:DateTime.now(),
          toggleCount:d.toggleCount+1,
        );
        _log_(d.nombre+' → '+(!estadoAntes?'ENCENDIDO':'APAGADO'), ok:true);
      } else {
        _log_('Sin respuesta de '+d.nombre, ok:false);
      }
      notifyListeners(); _save(); return ok;
    } finally { _enProceso.remove(id); }
  }

  Future<void> toggleTodos(bool enc) async {
    for (final d in List.of(_items)) if (d.encendido!=enc) await toggle(d.id);
  }

  Future<bool> agregar({required String nombre, required TipoD tipo,
    required CatArtefacto cat, required ModoConexion modo,
    required String ip, required int puerto, required String urlBase,
    required String habitacion}) async {
    _items.add(Dispositivo(id:_nextId++, nombre:nombre.trim(), tipo:tipo,
      cat:cat, modo:modo, ip:ip.trim(), puerto:puerto, urlBase:urlBase.trim(),
      habitacion:habitacion.trim().isEmpty?'General':habitacion.trim()));
    _log_('Dispositivo "'+nombre+'" agregado', ok:true);
    notifyListeners(); _save(); return true;
  }

  void eliminar(int id) {
    final d=_items.firstWhere((x)=>x.id==id);
    _items.removeWhere((x)=>x.id==id);
    _log_('"'+d.nombre+'" eliminado', ok:true);
    notifyListeners(); _save();
  }

  void toggleDemo() { _demo=!_demo; notifyListeners(); }
  void _log_(String msg, {required bool ok}) {
    _log.add(LogEntry(DateTime.now(),msg,ok));
    if (_log.length>200) _log.removeAt(0);
  }
  void _save() => DispositivoRepo.guardar(_prefs,_items);
}

// ════════════ MAIN ════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light,
    systemNavigationBarColor:Color(0xFF070B14),systemNavigationBarIconBrightness:Brightness.light));
  final prefs=await SharedPreferences.getInstance();
  runApp(DomoticaApp(notifier:DispositivosNotifier(DispositivoRepo.cargar(prefs),prefs)));
}

void snack(BuildContext ctx, String msg, {bool error=false}) {
  ScaffoldMessenger.of(ctx).clearSnackBars();
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content:Row(children:[
      Icon(error?Icons.error_rounded:Icons.check_circle_rounded,
          color:error?C.red:C.green,size:18),
      const SizedBox(width:10),
      Expanded(child:Text(msg,style:const TextStyle(color:C.t1))),
    ]),
    backgroundColor:C.cardHi,margin:const EdgeInsets.all(14),
    behavior:SnackBarBehavior.floating,
    shape:const RoundedRectangleBorder(borderRadius:R.sm),
    duration:const Duration(seconds:4)));
}

// ════════════ APP ROOT ════════════
class DomoticaApp extends StatelessWidget {
  final DispositivosNotifier notifier;
  const DomoticaApp({super.key,required this.notifier});
  @override
  Widget build(BuildContext ctx)=>AnimatedBuilder(
    animation:notifier,
    builder:(_,__)=>MaterialApp(
      debugShowCheckedModeBanner:false, title:'Domótica Pro',
      theme:ThemeData(
        useMaterial3:true, brightness:Brightness.dark,
        scaffoldBackgroundColor:C.bg,
        colorScheme:const ColorScheme.dark(primary:C.blue,secondary:C.green,
            surface:C.surface,onSurface:C.t1,onPrimary:Colors.white),
        cardTheme:const CardThemeData(color:C.card,elevation:0),
        dividerColor:C.border,
        inputDecorationTheme:InputDecorationTheme(
          filled:true,fillColor:C.surface,
          contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
          border:OutlineInputBorder(borderRadius:R.xs,borderSide:const BorderSide(color:C.border)),
          enabledBorder:OutlineInputBorder(borderRadius:R.xs,borderSide:const BorderSide(color:C.border)),
          focusedBorder:OutlineInputBorder(borderRadius:R.xs,borderSide:const BorderSide(color:C.blue,width:1.5)),
          errorBorder:OutlineInputBorder(borderRadius:R.xs,borderSide:const BorderSide(color:C.red)),
          labelStyle:const TextStyle(color:C.t2),hintStyle:const TextStyle(color:C.t3)),
        elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(
          backgroundColor:C.blue,foregroundColor:Colors.white,
          shape:const RoundedRectangleBorder(borderRadius:R.xs),
          padding:const EdgeInsets.symmetric(horizontal:24,vertical:14),
          textStyle:const TextStyle(fontWeight:FontWeight.w700,fontSize:15)))),
      home:Shell(notifier:notifier)));
}

// ════════════ SHELL ════════════
class Shell extends StatefulWidget {
  final DispositivosNotifier notifier;
  const Shell({super.key,required this.notifier});
  @override State<Shell> createState()=>_ShellState();
}
class _ShellState extends State<Shell> {
  int _tab=0;
  @override
  Widget build(BuildContext ctx) {
    final pages=[
      ControlPage(notifier:widget.notifier),
      HabitacionesPage(notifier:widget.notifier),
      DispositivosPage(notifier:widget.notifier),
      HistorialPage(notifier:widget.notifier),
    ];
    return Scaffold(
      body:AnimatedSwitcher(duration:const Duration(milliseconds:200),
          child:KeyedSubtree(key:ValueKey(_tab),child:pages[_tab])),
      bottomNavigationBar:_BottomNav(current:_tab,onTap:(i)=>setState(()=>_tab=i)));
  }
}

class _BottomNav extends StatelessWidget {
  final int current; final void Function(int) onTap;
  const _BottomNav({required this.current,required this.onTap});
  @override
  Widget build(BuildContext ctx) {
    const items=[(Icons.power_settings_new_rounded,'Control'),
      (Icons.home_rounded,'Habitaciones'),(Icons.devices_rounded,'Dispositivos'),
      (Icons.history_rounded,'Historial')];
    return Container(
      decoration:const BoxDecoration(color:C.surface,
          border:Border(top:BorderSide(color:C.border,width:0.5))),
      child:SafeArea(child:Padding(
        padding:const EdgeInsets.symmetric(vertical:6),
        child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,
          children:List.generate(4,(i){
            final sel=i==current;
            return GestureDetector(onTap:()=>onTap(i),
              child:AnimatedContainer(duration:const Duration(milliseconds:180),
                padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
                decoration:BoxDecoration(color:sel?C.blueGlow:Colors.transparent,borderRadius:R.md),
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Icon(items[i].$1,size:22,color:sel?C.blue:C.t3),
                  const SizedBox(height:3),
                  Text(items[i].$2,style:TextStyle(fontSize:10,fontWeight:FontWeight.w600,
                      color:sel?C.blue:C.t3)),
                ])));
          })),
      )));
  }
}

// ════════════ CONTROL PAGE ════════════
class ControlPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const ControlPage({super.key,required this.notifier});
  @override State<ControlPage> createState()=>_ControlPageState();
}
class _ControlPageState extends State<ControlPage> {
  final Set<int> _busy={};
  Future<void> _toggle(int id) async {
    if (_busy.contains(id)) return;
    setState(()=>_busy.add(id));
    final ok=await widget.notifier.toggle(id);
    if (mounted) {
      setState(()=>_busy.remove(id));
      if (!ok) {
        final d=widget.notifier.items.firstWhere((x)=>x.id==id);
        snack(context,'Sin respuesta de "${d.nombre}"',error:true);
      }
    }
  }
  @override
  Widget build(BuildContext ctx)=>AnimatedBuilder(
    animation:widget.notifier,
    builder:(_,__){
      final n=widget.notifier; final enc=n.encendidos; final tot=n.items.length;
      return Scaffold(
        backgroundColor:C.bg,
        body:CustomScrollView(slivers:[
          SliverAppBar(
            pinned:true,expandedHeight:110,backgroundColor:C.surface,
            flexibleSpace:FlexibleSpaceBar(background:_Header(enc:enc,total:tot)),
            title:Row(children:[
              const Text('Control',style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,color:C.t1)),
              const SizedBox(width:8),
              if(n.demo) Container(
                padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                decoration:BoxDecoration(color:C.orangeGlow,borderRadius:R.xl,
                    border:Border.all(color:C.orange)),
                child:const Text('DEMO',style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:C.orange))),
            ]),
            actions:[
              if(tot>0)...[
                _IconBtn(icon:Icons.power_off_rounded,color:C.red,tooltip:'Apagar todo',onTap:()=>n.toggleTodos(false)),
                const SizedBox(width:6),
                _IconBtn(icon:Icons.power_rounded,color:C.green,tooltip:'Encender todo',onTap:()=>n.toggleTodos(true)),
                const SizedBox(width:4),
              ],
              GestureDetector(onTap:n.toggleDemo,
                child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                  child:Icon(Icons.science_rounded,size:20,color:n.demo?C.orange:C.t3))),
              const SizedBox(width:6),
            ]),
          if(n.items.isEmpty) const SliverFillRemaining(child:_EmptyControl())
          else SliverPadding(
            padding:const EdgeInsets.fromLTRB(14,14,14,100),
            sliver:SliverList(delegate:SliverChildBuilderDelegate(
              (_,i){final d=n.items[i]; return _ControlCard(
                key:ValueKey(d.id),d:d,busy:_busy.contains(d.id),onToggle:()=>_toggle(d.id));},
              childCount:n.items.length))),
        ]));
    });
}

class _Header extends StatelessWidget {
  final int enc,total;
  const _Header({required this.enc,required this.total});
  @override
  Widget build(BuildContext ctx) {
    final pct=total==0?0.0:enc/total;
    return Container(
      decoration:const BoxDecoration(gradient:LinearGradient(
        begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[Color(0xFF0D1528),C.bg])),
      padding:const EdgeInsets.fromLTRB(18,58,18,12),
      child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
          mainAxisAlignment:MainAxisAlignment.end,children:[
          Text('$enc de $total encendidos',
              style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:C.t1)),
          const SizedBox(height:6),
          ClipRRect(borderRadius:R.xl,
            child:TweenAnimationBuilder<double>(
              tween:Tween(begin:0,end:pct),duration:const Duration(milliseconds:600),
              builder:(_,v,__)=>LinearProgressIndicator(value:v,minHeight:6,
                  backgroundColor:C.border,valueColor:const AlwaysStoppedAnimation(C.blue)))),
        ])),
        const SizedBox(width:16),
        SizedBox(width:52,height:52,child:Stack(alignment:Alignment.center,children:[
          CircularProgressIndicator(value:total==0?0:enc/total,
              backgroundColor:C.border,valueColor:const AlwaysStoppedAnimation(C.blue),
              strokeWidth:4,strokeCap:StrokeCap.round),
          Text('${total==0?0:enc*100~/total}%',
              style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:C.t1)),
        ])),
      ]));
  }
}

class _ControlCard extends StatelessWidget {
  final Dispositivo d; final bool busy; final VoidCallback onToggle;
  const _ControlCard({super.key,required this.d,required this.busy,required this.onToggle});
  @override
  Widget build(BuildContext ctx) {
    final col=d.encendido?d.tipo.color:C.t3;
    return AnimatedContainer(
      duration:const Duration(milliseconds:280),
      margin:const EdgeInsets.only(bottom:10),
      decoration:BoxDecoration(
        color:d.encendido?d.tipo.color.withOpacity(0.10):C.card,borderRadius:R.sm,
        border:Border.all(color:d.encendido?d.tipo.color.withOpacity(0.45):C.border,
            width:d.encendido?1.5:0.5)),
      child:InkWell(onTap:busy?null:onToggle,borderRadius:R.sm,
        child:Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
          child:Row(children:[
            AnimatedContainer(duration:const Duration(milliseconds:280),
              width:50,height:50,
              decoration:BoxDecoration(
                color:d.encendido?d.tipo.color.withOpacity(0.18):C.surface,borderRadius:R.sm),
              child:Icon(d.cat.icon,size:26,color:col)),
            const SizedBox(width:14),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(d.nombre,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,
                      color:d.encendido?C.t1:C.t2)),
              const SizedBox(height:4),
              Row(children:[
                _Badge(d.tipo.label,col:d.tipo.color),
                const SizedBox(width:6),
                _Badge(d.habitacion,col:C.t3),
              ]),
              const SizedBox(height:4),
              Text(d.conexionDisplay,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:10,color:C.t3)),
            ])),
            const SizedBox(width:12),
            _PwrBtn(on:d.encendido,busy:busy,color:d.tipo.color,onTap:busy?null:onToggle),
          ]))));
  }
}

class _PwrBtn extends StatelessWidget {
  final bool on,busy; final Color color; final VoidCallback? onTap;
  const _PwrBtn({required this.on,required this.busy,required this.color,required this.onTap});
  @override
  Widget build(BuildContext ctx) {
    if (busy) return SizedBox(width:56,height:56,
        child:Center(child:SizedBox(width:28,height:28,
            child:CircularProgressIndicator(strokeWidth:3,color:color))));
    return GestureDetector(onTap:onTap,
      child:AnimatedContainer(duration:const Duration(milliseconds:280),
        width:56,height:56,
        decoration:BoxDecoration(
          color:on?color:C.surface,shape:BoxShape.circle,
          border:Border.all(color:on?color:C.border,width:1.5),
          boxShadow:on?[BoxShadow(color:color.withOpacity(0.35),blurRadius:14,spreadRadius:2)]:[]),
        child:Icon(Icons.power_settings_new_rounded,size:24,
            color:on?Colors.white:C.t3)));
  }
}

class _EmptyControl extends StatelessWidget {
  const _EmptyControl();
  @override
  Widget build(BuildContext ctx)=>Center(child:Padding(padding:const EdgeInsets.all(40),
    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(padding:const EdgeInsets.all(24),
          decoration:const BoxDecoration(color:C.blueGlow,shape:BoxShape.circle),
          child:const Icon(Icons.devices_other_rounded,size:48,color:C.blue)),
      const SizedBox(height:20),
      const Text('Sin dispositivos',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:C.t1)),
      const SizedBox(height:8),
      const Text('Toca "Dispositivos" y agrega el primero.',
          textAlign:TextAlign.center,style:TextStyle(fontSize:14,color:C.t2)),
    ])));
}

// ════════════ HABITACIONES ════════════
class HabitacionesPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const HabitacionesPage({super.key,required this.notifier});
  @override State<HabitacionesPage> createState()=>_HabPageState();
}
class _HabPageState extends State<HabitacionesPage> {
  String _sel='Todas'; final Set<int> _busy={};
  Future<void> _toggle(int id) async {
    if (_busy.contains(id)) return;
    setState(()=>_busy.add(id));
    final ok=await widget.notifier.toggle(id);
    if (mounted) {
      setState(()=>_busy.remove(id));
      if (!ok) { final d=widget.notifier.items.firstWhere((x)=>x.id==id);
        snack(context,'Sin respuesta de "${d.nombre}"',error:true); }
    }
  }
  @override
  Widget build(BuildContext ctx)=>AnimatedBuilder(
    animation:widget.notifier,builder:(_,__){
      final n=widget.notifier; final habs=n.habitaciones;
      if (!habs.contains(_sel)) _sel='Todas';
      final items=n.porHabitacion(_sel);
      return Scaffold(backgroundColor:C.bg,body:CustomScrollView(slivers:[
        SliverAppBar(pinned:true,backgroundColor:C.surface,
          title:const Text('Habitaciones',style:TextStyle(fontWeight:FontWeight.w700,color:C.t1)),
          bottom:PreferredSize(preferredSize:const Size.fromHeight(52),
            child:SizedBox(height:46,child:ListView.separated(
              scrollDirection:Axis.horizontal,
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
              itemCount:habs.length,
              separatorBuilder:(_,__)=>const SizedBox(width:8),
              itemBuilder:(_,i){
                final h=habs[i]; final a=h==_sel;
                return GestureDetector(onTap:()=>setState(()=>_sel=h),
                  child:AnimatedContainer(duration:const Duration(milliseconds:160),
                    padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),
                    decoration:BoxDecoration(color:a?C.blue:C.surface,borderRadius:R.xl,
                        border:Border.all(color:a?C.blue:C.border)),
                    child:Text(h,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                        color:a?Colors.white:C.t2))));
              })))),
        if(items.isEmpty) SliverFillRemaining(child:Center(child:Text(
          _sel=='Todas'?'Sin dispositivos':'No hay dispositivos en $_sel',
          style:const TextStyle(color:C.t2))))
        else SliverPadding(
          padding:const EdgeInsets.fromLTRB(14,14,14,100),
          sliver:SliverGrid(
            delegate:SliverChildBuilderDelegate(
              (_,i)=>_DevTile(key:ValueKey(items[i].id),d:items[i],
                  busy:_busy.contains(items[i].id),onToggle:()=>_toggle(items[i].id)),
              childCount:items.length),
            gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:0.82))),
      ]));
    });
}

class _DevTile extends StatelessWidget {
  final Dispositivo d; final bool busy; final VoidCallback onToggle;
  const _DevTile({super.key,required this.d,required this.busy,required this.onToggle});
  @override
  Widget build(BuildContext ctx) {
    final col=d.tipo.color;
    return AnimatedContainer(
      duration:const Duration(milliseconds:280),
      decoration:BoxDecoration(
        color:d.encendido?col.withOpacity(0.12):C.card,borderRadius:R.md,
        border:Border.all(color:d.encendido?col.withOpacity(0.45):C.border,
            width:d.encendido?1.5:0.5)),
      child:InkWell(onTap:busy?null:onToggle,borderRadius:R.md,
        child:Padding(padding:const EdgeInsets.all(14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
              AnimatedContainer(duration:const Duration(milliseconds:280),
                width:44,height:44,
                decoration:BoxDecoration(
                  color:d.encendido?col.withOpacity(0.22):C.surface,borderRadius:R.sm),
                child:Icon(d.cat.icon,size:22,color:d.encendido?col:C.t3)),
              _PwrBtn(on:d.encendido,busy:busy,color:col,onTap:busy?null:onToggle),
            ]),
            const Spacer(),
            Text(d.nombre,maxLines:2,overflow:TextOverflow.ellipsis,
                style:TextStyle(fontSize:14,fontWeight:FontWeight.w600,
                    color:d.encendido?C.t1:C.t2)),
            const SizedBox(height:4),
            Row(children:[
              _Badge(d.tipo.label,col:col),const SizedBox(width:6),
              Text(d.encendido?'ON':'OFF',style:TextStyle(fontSize:10,
                  fontWeight:FontWeight.w800,color:d.encendido?col:C.t3)),
            ]),
          ]))));
  }
}

// ════════════ DISPOSITIVOS ════════════
class DispositivosPage extends StatefulWidget {
  final DispositivosNotifier notifier;
  const DispositivosPage({super.key,required this.notifier});
  @override State<DispositivosPage> createState()=>_DispPageState();
}
class _DispPageState extends State<DispositivosPage> {
  String _q='';
  @override
  Widget build(BuildContext ctx)=>AnimatedBuilder(
    animation:widget.notifier,builder:(_,__){
      final n=widget.notifier;
      final filtered=n.items.where((d)=>
        d.nombre.toLowerCase().contains(_q)||d.ip.contains(_q)||
        d.urlBase.toLowerCase().contains(_q)||d.habitacion.toLowerCase().contains(_q)).toList();
      return Scaffold(backgroundColor:C.bg,
        body:CustomScrollView(slivers:[
          SliverAppBar(pinned:true,backgroundColor:C.surface,
            title:const Text('Dispositivos',style:TextStyle(fontWeight:FontWeight.w700,color:C.t1)),
            bottom:PreferredSize(preferredSize:const Size.fromHeight(56),
              child:Padding(padding:const EdgeInsets.fromLTRB(14,0,14,10),
                child:TextField(
                  onChanged:(v)=>setState(()=>_q=v.toLowerCase()),
                  style:const TextStyle(color:C.t1,fontSize:14),
                  decoration:InputDecoration(
                    hintText:'Buscar...',
                    prefixIcon:const Icon(Icons.search_rounded,color:C.t3,size:20),
                    suffixIcon:_q.isNotEmpty?IconButton(
                      icon:const Icon(Icons.clear_rounded,color:C.t3,size:18),
                      onPressed:()=>setState(()=>_q='')):null))))),
          if(filtered.isEmpty) SliverFillRemaining(child:Center(child:Text(
            n.items.isEmpty?'Sin dispositivos aún':'Sin resultados',
            style:const TextStyle(color:C.t2))))
          else SliverPadding(
            padding:const EdgeInsets.fromLTRB(14,14,14,100),
            sliver:SliverList(delegate:SliverChildBuilderDelegate(
              (_,i)=>_DispCard(d:filtered[i],notifier:n),childCount:filtered.length))),
        ]),
        floatingActionButton:FloatingActionButton.extended(
          onPressed:()=>showModalBottomSheet(context:ctx,backgroundColor:C.surface,
            isScrollControlled:true,
            shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
            builder:(_)=>_AddForm(notifier:widget.notifier)),
          backgroundColor:C.blue,
          icon:const Icon(Icons.add_rounded),
          label:const Text('Agregar',style:TextStyle(fontWeight:FontWeight.w700))));
    });
}

class _DispCard extends StatefulWidget {
  final Dispositivo d; final DispositivosNotifier notifier;
  const _DispCard({required this.d,required this.notifier});
  @override State<_DispCard> createState()=>_DispCardState();
}
class _DispCardState extends State<_DispCard> {
  bool _busy=false;
  Future<void> _toggle() async {
    if (_busy) return; setState(()=>_busy=true);
    final ok=await widget.notifier.toggle(widget.d.id);
    if (mounted) { setState(()=>_busy=false);
      if (!ok) snack(context,'Sin respuesta de "${widget.d.nombre}"',error:true); }
  }
  @override
  Widget build(BuildContext ctx) {
    final d=widget.d; final col=d.tipo.color;
    return AnimatedContainer(duration:const Duration(milliseconds:280),
      margin:const EdgeInsets.only(bottom:10),
      decoration:BoxDecoration(color:C.card,borderRadius:R.sm,
        border:Border.all(color:d.encendido?col.withOpacity(0.4):C.border,
            width:d.encendido?1.5:0.5)),
      child:Padding(padding:const EdgeInsets.all(14),
        child:Column(children:[
          Row(children:[
            AnimatedContainer(duration:const Duration(milliseconds:280),
              width:44,height:44,
              decoration:BoxDecoration(
                color:d.encendido?col.withOpacity(0.18):C.surface,borderRadius:R.xs),
              child:Icon(d.cat.icon,size:22,color:d.encendido?col:C.t3)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(d.nombre,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,color:C.t1)),
              const SizedBox(height:4),
              Row(children:[
                _Badge(d.tipo.label,col:col),const SizedBox(width:6),
                _Badge(d.habitacion,col:C.t2),const SizedBox(width:6),
                _Badge(d.modo.label,col:d.modo.color),
              ]),
            ])),
            _busy
                ? SizedBox(width:28,height:28,child:CircularProgressIndicator(strokeWidth:2,color:col))
                : Switch(value:d.encendido,onChanged:(_)=>_toggle(),
                    activeColor:Colors.white,activeTrackColor:col,
                    inactiveThumbColor:C.t3,inactiveTrackColor:C.surface,
                    trackOutlineColor:WidgetStateProperty.resolveWith(
                        (s)=>d.encendido?col.withOpacity(0.4):C.border)),
          ]),
          const SizedBox(height:8),
          const Divider(height:1,color:C.border),
          const SizedBox(height:8),
          Row(children:[
            Icon(d.modo.icon,size:12,color:d.modo.color),const SizedBox(width:4),
            Expanded(child:Text(d.conexionDisplay,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:11,color:C.t3))),
            const SizedBox(width:8),
            Text('${d.toggleCount} ops',style:const TextStyle(fontSize:11,color:C.t3)),
            const SizedBox(width:10),
            GestureDetector(
              onTap:()=>showDialog(context:ctx,builder:(_)=>_DelDialog(
                nombre:d.nombre,
                onConfirm:(){ widget.notifier.eliminar(d.id); Navigator.pop(ctx); })),
              child:Container(padding:const EdgeInsets.all(5),
                decoration:BoxDecoration(color:C.redGlow,borderRadius:R.xs),
                child:const Icon(Icons.delete_outline_rounded,size:15,color:C.red))),
          ]),
        ])));
  }
}

// ════════════ FORMULARIO ════════════
class _AddForm extends StatefulWidget {
  final DispositivosNotifier notifier;
  const _AddForm({required this.notifier});
  @override State<_AddForm> createState()=>_AddFormState();
}
class _AddFormState extends State<_AddForm> {
  final _fk=GlobalKey<FormState>();
  final _cN=TextEditingController();
  final _cI=TextEditingController();
  final _cP=TextEditingController(text:'80');
  final _cU=TextEditingController();
  final _cH=TextEditingController(text:'General');
  TipoD _tipo=TipoD.celular;
  CatArtefacto _cat=CatArtefacto.enchufe;
  ModoConexion _modo=ModoConexion.lan;
  bool _saving=false; bool _pinging=false; bool? _pingOk;

  @override void dispose(){_cN.dispose();_cI.dispose();_cP.dispose();_cU.dispose();_cH.dispose();super.dispose();}

  String get _preview {
    if (_modo==ModoConexion.url) {
      final b=_cU.text.trim().replaceAll(RegExp(r'/$'),'');
      return b.isEmpty?'(ingresa URL)':'$b${_tipo.pathOn}';
    }
    final i=_cI.text.trim(); final p=_cP.text.trim();
    return i.isEmpty?'(ingresa IP)':'http://$i:$p${_tipo.pathOn}';
  }

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding:EdgeInsets.only(bottom:MediaQuery.of(ctx).viewInsets.bottom,left:20,right:20,top:20),
      child:Form(key:_fk,child:SingleChildScrollView(child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        Center(child:Container(width:36,height:4,
            decoration:BoxDecoration(color:C.border,borderRadius:R.xl))),
        const SizedBox(height:16),
        const Text('Agregar dispositivo',style:TextStyle(fontSize:17,fontWeight:FontWeight.w700,color:C.t1)),
        const SizedBox(height:18),

        const _L('Nombre'),
        TextFormField(controller:_cN,style:const TextStyle(color:C.t1),
          textCapitalization:TextCapitalization.words,
          decoration:const InputDecoration(hintText:'Ej: Lámpara sala'),
          validator:(v)=>v==null||v.trim().isEmpty?'Requerido':null),
        const SizedBox(height:14),

        const _L('Habitación'),
        TextFormField(controller:_cH,style:const TextStyle(color:C.t1),
          textCapitalization:TextCapitalization.words,
          decoration:const InputDecoration(hintText:'Sala, Cocina, Dormitorio...')),
        const SizedBox(height:14),

        const _L('Tipo de artefacto'),
        Wrap(spacing:8,runSpacing:8,children:CatArtefacto.values.map((c){
          final sel=c==_cat; final col=c.color;
          return GestureDetector(onTap:()=>setState(()=>_cat=c),
            child:AnimatedContainer(duration:const Duration(milliseconds:150),
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:sel?col.withOpacity(0.18):C.surface,
                  borderRadius:R.xs,border:Border.all(color:sel?col:C.border)),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                Icon(c.icon,size:13,color:sel?col:C.t3),const SizedBox(width:5),
                Text(c.label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:sel?col:C.t2)),
              ])));
        }).toList()),
        const SizedBox(height:14),

        const _L('Firmware / Tipo'),
        Wrap(spacing:8,runSpacing:8,children:TipoD.values.map((t){
          final sel=t==_tipo;
          return GestureDetector(
            onTap:()=>setState((){_tipo=t;_pingOk=null;
              if(t==TipoD.celular)_cP.text='8888';
              else if(_modo!=ModoConexion.url)_cP.text='80';}),
            child:AnimatedContainer(duration:const Duration(milliseconds:150),
              padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
              decoration:BoxDecoration(color:sel?t.color.withOpacity(0.2):C.surface,
                  borderRadius:R.xs,border:Border.all(color:sel?t.color:C.border)),
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                Icon(t.icon,size:13,color:sel?t.color:C.t3),const SizedBox(width:5),
                Text(t.label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:sel?t.color:C.t2)),
              ])));
        }).toList()),
        const SizedBox(height:16),

        const _L('Modo de conexión'),
        ...ModoConexion.values.map((m){
          final sel=m==_modo;
          return GestureDetector(
            onTap:()=>setState((){_modo=m;_pingOk=null;}),
            child:AnimatedContainer(duration:const Duration(milliseconds:150),
              margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:sel?m.color.withOpacity(0.10):C.surface,
                  borderRadius:R.sm,border:Border.all(color:sel?m.color:C.border,width:sel?1.5:0.5)),
              child:Row(children:[
                Container(width:32,height:32,
                  decoration:BoxDecoration(color:sel?m.color.withOpacity(0.18):C.card,borderRadius:R.xs),
                  child:Icon(m.icon,size:16,color:sel?m.color:C.t3)),
                const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(m.label,style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:sel?m.color:C.t1)),
                  Text(m.desc,style:const TextStyle(fontSize:10,color:C.t2)),
                ])),
                if(sel) Icon(Icons.check_circle_rounded,size:18,color:m.color),
              ])));
        }),

        if(_modo==ModoConexion.url)...[
          const _L('URL base'),
          TextFormField(controller:_cU,style:const TextStyle(color:C.t1),
            keyboardType:TextInputType.url,
            decoration:const InputDecoration(hintText:'https://abc123.ngrok.io'),
            onChanged:(_)=>setState(()=>_pingOk=null),
            validator:(v){
              if(v==null||v.trim().isEmpty) return 'URL requerida';
              if(!v.trim().startsWith('http')) return 'Debe empezar con http';
              return null;
            }),
        ] else ...[
          const _L('IP del dispositivo'),
          Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:C.orangeGlow,borderRadius:R.xs,
                border:Border.all(color:C.orange.withOpacity(0.4))),
            child:Row(children:[
              const Icon(Icons.info_outline_rounded,size:14,color:C.orange),
              const SizedBox(width:8),
              Expanded(child:Text(
                _tipo==TipoD.celular
                    ? 'Abre Web Remote Droid con WiFi activo y copia la IP que muestra'
                    : 'Busca la IP en la interfaz del dispositivo o en tu router',
                style:const TextStyle(fontSize:10,color:C.orange))),
            ])),
          TextFormField(controller:_cI,style:const TextStyle(color:C.t1),
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            decoration:InputDecoration(hintText:_modo.hint),
            onChanged:(_)=>setState(()=>_pingOk=null),
            validator:(v){
              if(v==null||v.trim().isEmpty) return 'IP requerida';
              if(v.trim()=='0.0.0.0') return 'IP inválida';
              return null;
            }),
          const SizedBox(height:12),
          const _L('Puerto'),
          TextFormField(controller:_cP,keyboardType:TextInputType.number,
            style:const TextStyle(color:C.t1),
            decoration:InputDecoration(hintText:_tipo==TipoD.celular?'8888':'80'),
            validator:(v){
              if(v==null||v.trim().isEmpty) return 'Requerido';
              if(int.tryParse(v.trim())==null) return 'Solo números';
              return null;
            }),
        ],
        const SizedBox(height:16),

        Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:C.blueGlow,borderRadius:R.xs,
              border:Border.all(color:C.blue.withOpacity(0.3))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('URL al encender:',style:TextStyle(fontSize:10,fontWeight:FontWeight.w600,color:C.blue)),
            const SizedBox(height:4),
            Text(_preview,style:const TextStyle(fontSize:11,color:C.t2)),
          ])),
        const SizedBox(height:14),

        OutlinedButton.icon(
          onPressed:_pinging?null:_doPing,
          icon:_pinging
              ? const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:C.blue))
              : Icon(_pingOk==null?Icons.network_check_rounded:_pingOk!?Icons.check_circle_rounded:Icons.error_rounded,
                  size:16,color:_pingOk==null?C.t2:_pingOk!?C.green:C.red),
          label:Text(
            _pinging?'Verificando...':_pingOk==null?'Probar conexión (opcional)':_pingOk!?'Responde OK':'Sin respuesta — puedes agregar igual',
            style:TextStyle(fontSize:13,color:_pingOk==null?C.t2:_pingOk!?C.green:C.orange)),
          style:OutlinedButton.styleFrom(
            minimumSize:const Size.fromHeight(44),
            side:BorderSide(color:_pingOk==null?C.border:_pingOk!?C.green:C.orange),
            shape:const RoundedRectangleBorder(borderRadius:R.xs))),
        const SizedBox(height:10),

        SizedBox(width:double.infinity,
          child:ElevatedButton(
            onPressed:_saving?null:_doSave,
            child:_saving
                ? const SizedBox(height:20,width:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Text('Agregar dispositivo'))),
        const SizedBox(height:24),
      ]))));
  }

  Future<void> _doPing() async {
    if(!_fk.currentState!.validate()) return;
    setState((){_pinging=true;_pingOk=null;});
    final ok=await NetCtrl.pingRaw(modo:_modo,ip:_cI.text.trim(),
        puerto:int.tryParse(_cP.text.trim())??80,urlBase:_cU.text.trim(),tipo:_tipo);
    if(mounted) setState((){_pinging=false;_pingOk=ok;});
  }

  Future<void> _doSave() async {
    if(!_fk.currentState!.validate()) return;
    setState(()=>_saving=true);
    await widget.notifier.agregar(nombre:_cN.text,tipo:_tipo,cat:_cat,modo:_modo,
        ip:_cI.text,puerto:int.tryParse(_cP.text.trim())??80,
        urlBase:_cU.text,habitacion:_cH.text);
    if(mounted) { setState(()=>_saving=false); Navigator.pop(context); snack(context,'Dispositivo agregado ✓'); }
  }
}

// ════════════ HISTORIAL ════════════
class HistorialPage extends StatelessWidget {
  final DispositivosNotifier notifier;
  const HistorialPage({super.key,required this.notifier});
  @override
  Widget build(BuildContext ctx)=>AnimatedBuilder(
    animation:notifier,builder:(_,__){
      final log=notifier.log;
      return Scaffold(backgroundColor:C.bg,
        appBar:AppBar(backgroundColor:C.surface,
            title:const Text('Historial',style:TextStyle(fontWeight:FontWeight.w700,color:C.t1))),
        body:log.isEmpty
            ? const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Icon(Icons.history_rounded,size:46,color:C.t3),SizedBox(height:12),
                Text('Sin actividad aún',style:TextStyle(color:C.t2))]))
            : ListView.builder(padding:const EdgeInsets.all(14),itemCount:log.length,
                itemBuilder:(_,i)=>_LogTile(e:log[i])));
    });
}

class _LogTile extends StatelessWidget {
  final LogEntry e; const _LogTile({required this.e});
  @override
  Widget build(BuildContext ctx)=>Container(
    margin:const EdgeInsets.only(bottom:8),
    padding:const EdgeInsets.symmetric(horizontal:14,vertical:11),
    decoration:BoxDecoration(color:C.card,borderRadius:R.xs,border:Border.all(color:C.border)),
    child:Row(children:[
      Container(width:30,height:30,
        decoration:BoxDecoration(color:(e.ok?C.green:C.red).withOpacity(0.15),shape:BoxShape.circle),
        child:Icon(e.ok?Icons.check_rounded:Icons.close_rounded,size:15,color:e.ok?C.green:C.red)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(e.msg,style:const TextStyle(fontSize:13,color:C.t1)),
        const SizedBox(height:2),
        Text(_fmt(e.ts),style:const TextStyle(fontSize:11,color:C.t3)),
      ])),
    ]));
  static String _fmt(DateTime t) {
    final d=DateTime.now().difference(t);
    if(d.inSeconds<60) return 'hace ${d.inSeconds}s';
    if(d.inMinutes<60) return 'hace ${d.inMinutes}m';
    if(d.inHours<24)   return 'hace ${d.inHours}h';
    return '${t.day}/${t.month}/${t.year} ${t.hour}:${t.minute.toString().padLeft(2,'0')}';
  }
}

// ════════════ WIDGETS ════════════
class _Badge extends StatelessWidget {
  final String text; final Color col;
  const _Badge(this.text,{required this.col});
  @override
  Widget build(BuildContext ctx)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
    decoration:BoxDecoration(color:col.withOpacity(0.14),borderRadius:R.xl),
    child:Text(text,style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:col)));
}

class _L extends StatelessWidget {
  final String text; const _L(this.text);
  @override
  Widget build(BuildContext ctx)=>Padding(padding:const EdgeInsets.only(bottom:6),
    child:Text(text,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:C.t2)));
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final String tooltip; final VoidCallback onTap;
  const _IconBtn({required this.icon,required this.color,required this.tooltip,required this.onTap});
  @override
  Widget build(BuildContext ctx)=>Tooltip(message:tooltip,
    child:GestureDetector(onTap:onTap,
      child:Container(width:34,height:34,
        decoration:BoxDecoration(color:color.withOpacity(0.15),borderRadius:R.xs,
            border:Border.all(color:color.withOpacity(0.3))),
        child:Icon(icon,size:17,color:color))));
}

class _DelDialog extends StatelessWidget {
  final String nombre; final VoidCallback onConfirm;
  const _DelDialog({required this.nombre,required this.onConfirm});
  @override
  Widget build(BuildContext ctx)=>AlertDialog(
    backgroundColor:C.card,shape:const RoundedRectangleBorder(borderRadius:R.md),
    title:const Text('Eliminar dispositivo',style:TextStyle(color:C.t1,fontSize:16)),
    content:Text('¿Eliminar "$nombre"?\nNo se puede deshacer.',style:const TextStyle(color:C.t2)),
    actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
      TextButton(onPressed:onConfirm,style:TextButton.styleFrom(foregroundColor:C.red),
          child:const Text('Eliminar')),
    ]);
}
