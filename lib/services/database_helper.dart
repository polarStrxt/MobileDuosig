import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  // Vamos assumir que a introdução correta das tabelas do carrinho
  // acontecerá a partir da versão 6 para simplificar o exemplo de upgrade.
  // Se você já liberou a versão 5 e ela não tinha as tabelas de carrinho corretas,
  // você precisará de uma lógica de upgrade mais cuidadosa.
  // Por agora, vou manter como 5, mas tenha em mente a lógica de _onUpgrade.
  static const int _databaseVersion = 5; // Ou 6 se você estiver introduzindo as tabelas de carrinho agora

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
      // Habilitar chaves estrangeiras é importante para ON DELETE CASCADE funcionar
      onConfigure: _onConfigure,
    );
  }

  // É uma boa prática habilitar o suporte a chaves estrangeiras explicitamente.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Criação das tabelas existentes
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
      -- Considere adicionar: FOREIGN KEY (codcndpgt) REFERENCES condicao_pagamento(codcndpgt)
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

    // Chamadas para criar as tabelas mais recentes
    await _createCondicaoPagamento(db);
    await _createConfig(db); // Adicionada na versão 5 no seu código original

    // Criação das tabelas do Carrinho
    await _createCarrinhos(db);       // Tabela de cabeçalho do carrinho
    await _createCarrinhoItens(db);   // Tabela de itens do carrinho
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // A lógica de upgrade deve ser sequencial e cuidadosa.
    // Cada 'if' deve conter apenas as alterações daquela versão específica.

    if (oldVersion < 2) {
        // Se havia algo na versão 2 (não especificado no seu código, mas seguindo seu padrão)
        // await _upgradeToVersion2(db);
    }
    if (oldVersion < 3) {
      // Na sua lógica original, oldVersion < 3 criava 'carrinho_itens' (que era 'carrinhos').
      // Vamos assumir que as tabelas de carrinho são introduzidas "corretamente" numa versão posterior
      // ou que estamos corrigindo agora. Se for uma correção, você pode precisar
      // de DROP TABLE IF EXISTS para a antiga 'carrinhos' se ela foi criada erroneamente como itens.
      // Por simplicidade, vamos criar se não existir, como se fosse uma nova adição.
      await _createCarrinhos(db); // Adicionando a tabela de cabeçalho do carrinho
      await _createCarrinhoItens(db); // Adicionando a tabela de itens do carrinho
    }
    if (oldVersion < 4) {
      await _createCondicaoPagamento(db);
    }
    if (oldVersion < 5) {
      await _createConfig(db);
    }

    // Exemplo: Se as tabelas de carrinho fossem novas na versão 6:
    // if (oldVersion < 6) {
    //   await _createCarrinhos(db);
    //   await _createCarrinhoItens(db);
    // }
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

  // CORRIGIDO: Função para criar a tabela 'carrinhos' (cabeçalho)
  Future<void> _createCarrinhos(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS carrinhos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codcli INTEGER NOT NULL,
      data_criacao TEXT NOT NULL,
      data_ultima_modificacao TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'aberto',
      cupom_desconto_id INTEGER,
      valor_total_bruto REAL,
      valor_total_descontos REAL,
      valor_total_liquido REAL,
      observacoes TEXT,
      FOREIGN KEY (codcli) REFERENCES clientes(codcli) ON DELETE RESTRICT ON UPDATE CASCADE
      -- FOREIGN KEY (cupom_desconto_id) REFERENCES cupons(id) -- Descomente se tiver tabela 'cupons'
    );
    ''');
    // Adicionar um índice em codcli e status pode ser bom para performance se você consultar muito por eles
    await db.execute('CREATE INDEX IF NOT EXISTS idx_carrinhos_codcli_status ON carrinhos (codcli, status);');
  }

  // CORRIGIDO: Função para criar a tabela 'carrinho_itens'
  Future<void> _createCarrinhoItens(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS carrinho_itens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_carrinho INTEGER NOT NULL,
      codprd INTEGER NOT NULL,
      quantidade INTEGER NOT NULL CHECK (quantidade > 0),
      preco_unitario_registrado REAL NOT NULL,
      desconto_item REAL NOT NULL DEFAULT 0 CHECK (desconto_item >= 0),
      data_adicao TEXT NOT NULL,
      FOREIGN KEY (id_carrinho) REFERENCES carrinhos(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (codprd) REFERENCES produtos(codprd) ON DELETE RESTRICT ON UPDATE CASCADE
    );
    ''');
    // Índice para buscar itens de um carrinho específico rapidamente
    await db.execute('CREATE INDEX IF NOT EXISTS idx_carrinho_itens_id_carrinho ON carrinho_itens (id_carrinho);');
  }
}