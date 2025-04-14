import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  static const int _databaseVersion = 5; // Atualizado para versão 5

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
      onUpgrade: _onUpgrade,
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

    await _createCarrinhoItens(db);
    await _createCondicaoPagamento(db);
    await _createConfig(db); // Nova tabela campos
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _createCarrinhoItens(db);
    }

    if (oldVersion < 4) {
      await _createCondicaoPagamento(db);
    }
    
    if (oldVersion < 5) {
      await _createConfig(db);
    }
  }

  Future<void> _createCarrinhoItens(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS carrinho_itens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codprd INTEGER NOT NULL,
      codcli INTEGER NOT NULL,
      quantidade INTEGER NOT NULL CHECK (quantidade > 0),
      desconto REAL NOT NULL CHECK (desconto >= 0),
      finalizado INTEGER NOT NULL DEFAULT 0,
      data_criacao TEXT NOT NULL
    );
    ''');
  }

  Future<void> _createCondicaoPagamento(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS condicao_pagamento (
      codcndpgt INTEGER PRIMARY KEY,
      dcrcndpgt TEXT NOT NULL,
      perdsccel REAL NOT NULL,
      staati TEXT NOT NULL
    );
    ''');
  }
  
  Future<void> _createConfig(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS config (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_vendedor TEXT NOT NULL,
      endereco_api TEXT NOT NULL,
      usuario_duosig TEXT NOT NULL,
      usuario TEXT NOT NULL,
      senha TEXT NOT NULL
    );
    ''');
  }
}