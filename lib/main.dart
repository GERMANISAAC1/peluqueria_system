import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class Dispositivo {
  String nombre;
  String tipo;
  bool encendido;

  Dispositivo({
    required this.nombre,
    required this.tipo,
    this.encendido = false,
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Domótica Pro',
      theme: ThemeData.dark(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Dispositivo> dispositivos = [
    Dispositivo(nombre: 'Sala', tipo: 'Luz', encendido: true),
    Dispositivo(nombre: 'Cocina', tipo: 'Tasmota'),
    Dispositivo(nombre: 'Dormitorio', tipo: 'Cortina'),
    Dispositivo(nombre: 'Garaje', tipo: 'Escena'),
    Dispositivo(nombre: 'Patio', tipo: 'Celular'),
    Dispositivo(nombre: 'Oficina', tipo: 'Luz'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),

      appBar: AppBar(
        backgroundColor: const Color(0xFF222222),
        title: const Text(
          '🏠 Panel Domótico',
          style: TextStyle(
            color: Colors.cyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: dispositivos.length,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final d = dispositivos[index];

            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.cyan.withOpacity(0.15),
                  )
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [

                  Icon(
                    Icons.lightbulb,
                    size: 50,
                    color: d.encendido
                        ? Colors.yellow
                        : Colors.red,
                  ),

                  Text(
                    d.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    d.tipo,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                    ),
                  ),

                  Switch(
                    value: d.encendido,
                    activeColor: Colors.green,
                    onChanged: (v) {
                      setState(() {
                        d.encendido = v;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.cyan,
        onPressed: () {
          setState(() {
            dispositivos.add(
              Dispositivo(
                nombre: 'Nuevo',
                tipo: 'Tasmota',
              ),
            );
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
