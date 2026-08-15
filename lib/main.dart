// ============================================================================
// FocusMind — MVP (Pomodoro + Tareas)
// Single-file Flutter app, producción-ready, sin placeholders.
//
// Dependencias (agregar en pubspec.yaml):
//   dependencies:
//     flutter:
//       sdk: flutter
//     shared_preferences: ^2.2.3
//     uuid: ^4.4.0
//
// Ejecutar:
//   flutter create focusmind && reemplazar lib/main.dart con este archivo
//   flutter run
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FocusMindApp());
}

// ============================================================================
// MODELOS
// ============================================================================

enum TaskPriority { baja, media, alta }

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.baja:
        return 'Baja';
      case TaskPriority.media:
        return 'Media';
      case TaskPriority.alta:
        return 'Alta';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.baja:
        return const Color(0xFF4CAF50);
      case TaskPriority.media:
        return const Color(0xFFFFA726);
      case TaskPriority.alta:
        return const Color(0xFFEF5350);
    }
  }
}

class Task {
  final String id;
  String title;
  TaskPriority priority;
  DateTime? dueDate;
  bool completed;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.priority = TaskPriority.media,
    this.dueDate,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priority': priority.index,
        'dueDate': dueDate?.toIso8601String(),
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        priority: TaskPriority.values[json['priority'] ?? 1],
        dueDate:
            json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        completed: json['completed'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class FocusSession {
  final DateTime date;
  final int minutes;

  FocusSession({required this.date, required this.minutes});

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minutes': minutes,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        date: DateTime.parse(json['date']),
        minutes: json['minutes'],
      );
}

// ============================================================================
// REPOSITORIO (persistencia local con SharedPreferences)
// ============================================================================

class FocusMindRepository {
  static const _kTasks = 'fm_tasks';
  static const _kSessions = 'fm_sessions';
  static const _kFocusMinutes = 'fm_focus_minutes';
  static const _kBreakMinutes = 'fm_break_minutes';
  static const _kDarkMode = 'fm_dark_mode';

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kTasks) ?? [];
    return raw.map((e) => Task.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kTasks,
      tasks.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  Future<List<FocusSession>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessions) ?? [];
    return raw.map((e) => FocusSession.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addSession(FocusSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessions) ?? [];
    raw.add(jsonEncode(session.toJson()));
    await prefs.setStringList(_kSessions, raw);
  }

  Future<int> getFocusMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kFocusMinutes) ?? 25;
  }

  Future<void> setFocusMinutes(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kFocusMinutes, v);
  }

  Future<int> getBreakMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kBreakMinutes) ?? 5;
  }

  Future<void> setBreakMinutes(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBreakMinutes, v);
  }

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkMode) ?? true;
  }

  Future<void> setDarkMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, v);
  }
}

// ============================================================================
// APP ROOT
// ============================================================================

class FocusMindApp extends StatefulWidget {
  const FocusMindApp({super.key});

  @override
  State<FocusMindApp> createState() => _FocusMindAppState();
}

class _FocusMindAppState extends State<FocusMindApp> {
  final _repo = FocusMindRepository();
  bool _darkMode = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _repo.getDarkMode().then((v) {
      setState(() {
        _darkMode = v;
        _loaded = true;
      });
    });
  }

  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
    _repo.setDarkMode(_darkMode);
  }

  static const _seed = Color(0xFF3B82F6); // azul
  static const _accent = Color(0xFF22C55E); // verde

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(secondary: _accent);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.dark ? const Color(0xFF0F1115) : const Color(0xFFF7F9FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark
            ? const Color(0xFF1A1D24)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'FocusMind',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeShell(repo: _repo, onToggleDarkMode: _toggleDarkMode, darkMode: _darkMode),
    );
  }
}

// ============================================================================
// HOME SHELL (navegación por pestañas)
// ============================================================================

class HomeShell extends StatefulWidget {
  final FocusMindRepository repo;
  final VoidCallback onToggleDarkMode;
  final bool darkMode;

  const HomeShell({
    super.key,
    required this.repo,
    required this.onToggleDarkMode,
    required this.darkMode,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      FocusPage(repo: widget.repo),
      TasksPage(repo: widget.repo),
      StatsPage(repo: widget.repo),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusMind', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(widget.darkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleDarkMode,
            tooltip: 'Cambiar tema',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.gps_fixed), label: 'Enfoque'),
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Progreso'),
        ],
      ),
    );
  }
}

// ============================================================================
// PÁGINA: ENFOQUE (Pomodoro Timer)
// ============================================================================

enum TimerPhase { focus, breakTime }

class FocusPage extends StatefulWidget {
  final FocusMindRepository repo;
  const FocusPage({super.key, required this.repo});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> with SingleTickerProviderStateMixin {
  int focusMinutes = 25;
  int breakMinutes = 5;
  TimerPhase phase = TimerPhase.focus;

  late int totalSeconds;
  late int remainingSeconds;
  Timer? _ticker;
  bool running = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final f = await widget.repo.getFocusMinutes();
    final b = await widget.repo.getBreakMinutes();
    setState(() {
      focusMinutes = f;
      breakMinutes = b;
      totalSeconds = focusMinutes * 60;
      remainingSeconds = totalSeconds;
    });
  }

  void _start() {
    if (running) return;
    setState(() => running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSeconds <= 1) {
        _completePhase();
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      running = false;
      phase = TimerPhase.focus;
      totalSeconds = focusMinutes * 60;
      remainingSeconds = totalSeconds;
    });
  }

  Future<void> _completePhase() async {
    _ticker?.cancel();
    if (phase == TimerPhase.focus) {
      await widget.repo.addSession(
        FocusSession(date: DateTime.now(), minutes: focusMinutes),
      );
      setState(() {
        phase = TimerPhase.breakTime;
        totalSeconds = breakMinutes * 60;
        remainingSeconds = totalSeconds;
        running = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Sesión completada! Hora de un descanso.')),
        );
      }
    } else {
      setState(() {
        phase = TimerPhase.focus;
        totalSeconds = focusMinutes * 60;
        remainingSeconds = totalSeconds;
        running = false;
      });
    }
  }

  Future<void> _openSettings() async {
    int tempFocus = focusMinutes;
    int tempBreak = breakMinutes;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Duración de sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Enfoque: $tempFocus min'),
                Slider(
                  value: tempFocus.toDouble(),
                  min: 5,
                  max: 90,
                  divisions: 17,
                  onChanged: (v) => setModalState(() => tempFocus = v.round()),
                ),
                Text('Descanso: $tempBreak min'),
                Slider(
                  value: tempBreak.toDouble(),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  onChanged: (v) => setModalState(() => tempBreak = v.round()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.repo.setFocusMinutes(tempFocus);
                      await widget.repo.setBreakMinutes(tempBreak);
                      Navigator.pop(ctx);
                      setState(() {
                        focusMinutes = tempFocus;
                        breakMinutes = tempBreak;
                        _reset();
                      });
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _mmss {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds == 0 ? 0.0 : 1 - (remainingSeconds / totalSeconds);
    final color = phase == TimerPhase.focus
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                phase == TimerPhase.focus ? 'Sesión de enfoque' : 'Descanso',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      height: 260,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _mmss,
                          style: const TextStyle(
                              fontSize: 52, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        const SizedBox(height: 4),
                        Text(running ? 'En curso...' : 'Sesión preparada'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 180,
                    child: ElevatedButton.icon(
                      onPressed: running ? _pause : _start,
                      icon: Icon(running ? Icons.pause : Icons.play_arrow),
                      label: Text(running ? 'Pausar' : 'Iniciar enfoque'),
                      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PÁGINA: TAREAS
// ============================================================================

class TasksPage extends StatefulWidget {
  final FocusMindRepository repo;
  const TasksPage({super.key, required this.repo});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Task> _tasks = [];
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await widget.repo.loadTasks();
    setState(() => _tasks = tasks);
  }

  Future<void> _persist() => widget.repo.saveTasks(_tasks);

  Future<void> _addTaskDialog() async {
    final controller = TextEditingController();
    TaskPriority priority = TaskPriority.media;
    DateTime? due;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nueva tarea'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Título de la tarea'),
              ),
              const SizedBox(height: 12),
              DropdownButton<TaskPriority>(
                value: priority,
                isExpanded: true,
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(value: p, child: Text('Prioridad: ${p.label}')))
                    .toList(),
                onChanged: (v) => setDialogState(() => priority = v ?? TaskPriority.media),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(due == null ? 'Sin fecha límite' : due.toString().split(' ').first),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => due = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                setState(() {
                  _tasks.add(Task(
                    id: _uuid.v4(),
                    title: controller.text.trim(),
                    priority: priority,
                    dueDate: due,
                  ));
                });
                _persist();
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(Task t) {
    setState(() => t.completed = !t.completed);
    _persist();
  }

  void _delete(Task t) {
    setState(() => _tasks.removeWhere((e) => e.id == t.id));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => !t.completed).toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    final done = _tasks.where((t) => t.completed).toList();

    return Scaffold(
      body: SafeArea(
        child: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.checklist_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No tienes tareas todavía'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addTaskDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar tarea'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pending.isNotEmpty) ...[
                  Text('Pendientes (${pending.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...pending.map((t) => _TaskTile(task: t, onToggle: () => _toggle(t), onDelete: () => _delete(t))),
                ],
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Completadas (${done.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...done.map((t) => _TaskTile(task: t, onToggle: () => _toggle(t), onDelete: () => _delete(t))),
                ],
                const SizedBox(height: 80),
              ],
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tarea'),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({required this.task, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(value: task.completed, onChanged: (_) => onToggle()),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),
        subtitle: task.dueDate != null
            ? Text('Vence: ${task.dueDate.toString().split(' ').first}')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: task.priority.color, shape: BoxShape.circle),
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PÁGINA: PROGRESO (Estadísticas)
// ============================================================================

class StatsPage extends StatefulWidget {
  final FocusMindRepository repo;
  const StatsPage({super.key, required this.repo});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<FocusSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.repo.loadSessions();
    setState(() => _sessions = s);
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _sessions.fold<int>(0, (sum, s) => sum + s.minutes);
    final totalSessions = _sessions.length;
    final today = DateTime.now();
    final todaySessions = _sessions.where((s) =>
        s.date.year == today.year && s.date.month == today.month && s.date.day == today.day).length;

    // Últimos 7 días
    final last7 = List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final mins = _sessions
          .where((s) => s.date.year == day.year && s.date.month == day.month && s.date.day == day.day)
          .fold<int>(0, (sum, s) => sum + s.minutes);
      return MapEntry(day, mins);
    });
    final maxMinutes = last7.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Sesiones totales', value: '$totalSessions')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Minutos totales', value: '$totalMinutes')),
            ],
          ),
          const SizedBox(height: 12),
          _StatCard(label: 'Sesiones hoy', value: '$todaySessions', wide: true),
          const SizedBox(height: 24),
          Text('Últimos 7 días', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: last7.map((e) {
                    final h = maxMinutes == 0 ? 0.0 : (e.value / maxMinutes) * 120;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${e.value}', style: const TextStyle(fontSize: 10)),
                            const SizedBox(height: 4),
                            Container(
                              height: h < 4 ? 4 : h,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_weekdayLabel(e.key.weekday), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[weekday - 1];
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool wide;

  const _StatCard({required this.label, required this.value, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
