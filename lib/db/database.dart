
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DB {
  static Database? _db;

  static Future<Database> init() async {
    if (_db != null) return _db!;

    String path = join(await getDatabasesPath(), 'kety.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            puntos INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE servicios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            precio REAL
          )
        ''');
      },
    );

    return _db!;
  }
}
