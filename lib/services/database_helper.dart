import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  static const int _databaseVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE produtos (
        codprd INTEGER PRIMARY KEY AUTOINCREMENT,
        staati TEXT NOT NULL,
        dcrprd TEXT NOT NULL,
        qtdmulvda INTEGER NOT NULL,
        nommrc TEXT NOT NULL,
        vlrbasvda REAL NOT NULL,
        qtdetq INTEGER,
        vlrpmcprd REAL NOT NULL,
        dtaini TEXT,
        dtafin TEXT,
        vlrtab1 REAL NOT NULL,
        vlrtab2 REAL NOT NULL,
        peracrdsc1 REAL NOT NULL,
        peracrdsc2 REAL NOT NULL,
        codundprd TEXT NOT NULL,
        vol INTEGER NOT NULL,
        qtdvol INTEGER NOT NULL,
        perdscmxm REAL NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE clientes (
        codcli INTEGER PRIMARY KEY AUTOINCREMENT,
        nomcli TEXT NOT NULL,
        cgccpfcli TEXT NOT NULL,
        ufdcli TEXT NOT NULL,
        endcli TEXT NOT NULL,
        baicli TEXT NOT NULL,
        muncli TEXT NOT NULL,
        numtel001 TEXT NOT NULL,
        numtel002 TEXT,
        nomfnt TEXT NOT NULL,
        emailcli TEXT NOT NULL,
        vlrlimcrd REAL NOT NULL,
        codtab INTEGER NOT NULL,
        codcndpgt INTEGER NOT NULL,
        vlrsldlimcrd REAL NOT NULL,
        vlrdplabe REAL NOT NULL,
        vlrdplats REAL NOT NULL,
        staati TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE duplicata (
        numdoc TEXT PRIMARY KEY,
        codcli INTEGER NOT NULL,
        dtavct TEXT NOT NULL,
        vlrdpl REAL NOT NULL,
        FOREIGN KEY (codcli) REFERENCES clientes (codcli) ON DELETE CASCADE
      );
    ''');
  }
}
