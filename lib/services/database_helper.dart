import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart'; // Adicionado para logging interno

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  // Verifique se esta versão é maior que a anterior no dispositivo do usuário
  // se você já distribuiu o app antes com o erro.
  static const int _databaseVersion = 8; // Mantenha ou incremente conforme necessário

  // --- Constantes com Nomes de Tabelas ---
  static const String tableProdutos = 'produtos';
  static const String tableClientes = 'clientes';
  static const String tableDuplicata = 'duplicata';
  static const String tableCondicaoPagamento = 'condicao_pagamento';
  static const String tableConfig = 'config';
  static const String tableCarrinhos = 'carrinhos';
  static const String tableCarrinhoItens = 'carrinho_itens';
  static const String tablePedidosParaEnvio = 'pedidos_para_envio';
  // static const String tableCupons = 'cupons'; // Se existir

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final Logger _logger = Logger(); // Instância do Logger

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), _databaseName);
    _logger.i("Abrindo banco de dados em: $path");
    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onDowngrade: onDatabaseDowngradeDelete, // Estratégia para downgrade
    );
  }

  Future<void> _onConfigure(Database db) async {
    _logger.i("Configurando banco de dados - Habilitando chaves estrangeiras.");
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    _logger.i("Criando banco de dados versão $version...");
    // Usar Batch para executar múltiplos comandos de uma vez (mais eficiente)
    var batch = db.batch();

    _createProdutosTable(batch);
    _createClientesTable(batch); // Chamando método corrigido
    _createDuplicataTable(batch);
    _createCondicaoPagamentoTable(batch);
    _createConfigTable(batch);
    _createCarrinhosTable(batch);
    _createCarrinhoItensTable(batch);
    _createPedidosParaEnvioTable(batch);

    await batch.commit();
    _logger.i("Banco de dados criado com sucesso.");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.w("Atualizando banco de dados da versão $oldVersion para $newVersion...");
    // Implemente a lógica de migração baseada nas versões.
    // Exemplo: Se as tabelas de carrinho foram adicionadas na versão 6.
    if (oldVersion < 6) {
       _logger.i("Aplicando migração para versão 6: Criando tabelas de carrinho...");
       var batch = db.batch();
      _createCarrinhosTable(batch);
      _createCarrinhoItensTable(batch);
      await batch.commit();
       _logger.i("Tabelas de carrinho criadas.");
    }
    if (oldVersion < 5) {
        _logger.i("Aplicando migração para versão 5: Criando tabela config...");
         var batch = db.batch();
        _createConfigTable(batch);
        await batch.commit();
         _logger.i("Tabela config criada.");
    }
    if (oldVersion < 4) {
         _logger.i("Aplicando migração para versão 4: Criando tabela condicao_pagamento...");
         var batch = db.batch();
        _createCondicaoPagamentoTable(batch);
        await batch.commit();
         _logger.i("Tabela condicao_pagamento criada.");
    }
    // Adicione outras migrações conforme necessário
     _logger.w("Atualização do banco de dados concluída.");
  }

  // --- Métodos de Criação de Tabela (usando Batch) ---

  void _createProdutosTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableProdutos (
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
    _logger.d("Comando CREATE TABLE $tableProdutos adicionado ao batch.");
  }

  // ----- CORREÇÃO APLICADA AQUI -----
  void _createClientesTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableClientes (
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
      -- Comentário inválido // FOREIGN KEY... foi REMOVIDO daqui.
      -- Se quiser adicionar a FK corretamente no futuro:
      -- , FOREIGN KEY (codcndpgt) REFERENCES $tableCondicaoPagamento(codcndpgt)
    );
    ''');
     _logger.d("Comando CREATE TABLE $tableClientes adicionado ao batch.");
  }
  // ---------------------------------

  void _createDuplicataTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableDuplicata (
      numdoc TEXT PRIMARY KEY,
      codcli INTEGER NOT NULL,
      dtavct TEXT NOT NULL,
      vlrdpl REAL NOT NULL,
      FOREIGN KEY (codcli) REFERENCES $tableClientes (codcli) ON DELETE CASCADE
    );
    ''');
     _logger.d("Comando CREATE TABLE $tableDuplicata adicionado ao batch.");
  }

  void _createCondicaoPagamentoTable(Batch batch) {
    batch.execute('''
    CREATE TABLE IF NOT EXISTS $tableCondicaoPagamento (
      codcndpgt INTEGER PRIMARY KEY,
      dcrcndpgt TEXT NOT NULL,
      perdsccel REAL NOT NULL,
      staati TEXT NOT NULL
    );
    ''');
     _logger.d("Comando CREATE TABLE IF NOT EXISTS $tableCondicaoPagamento adicionado ao batch.");
  }

  void _createConfigTable(Batch batch) {
    batch.execute('''
    CREATE TABLE IF NOT EXISTS $tableConfig (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_vendedor TEXT NOT NULL,
      endereco_api TEXT NOT NULL,
      usuario_duosig TEXT NOT NULL,
      usuario TEXT NOT NULL,
      senha TEXT NOT NULL
    );
    ''');
     _logger.d("Comando CREATE TABLE IF NOT EXISTS $tableConfig adicionado ao batch.");
  }

  void _createCarrinhosTable(Batch batch) {
    batch.execute('''
    CREATE TABLE IF NOT EXISTS $tableCarrinhos (
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
      FOREIGN KEY (codcli) REFERENCES $tableClientes(codcli) ON DELETE RESTRICT ON UPDATE CASCADE
      
    );
    ''');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_carrinhos_codcli_status ON $tableCarrinhos (codcli, status);');
     _logger.d("Comando CREATE TABLE IF NOT EXISTS $tableCarrinhos e INDEX adicionados ao batch.");
  }

  void _createCarrinhoItensTable(Batch batch) {
    batch.execute('''
    CREATE TABLE IF NOT EXISTS $tableCarrinhoItens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_carrinho INTEGER NOT NULL,
      codprd INTEGER NOT NULL,
      quantidade INTEGER NOT NULL CHECK (quantidade > 0),
      preco_unitario_registrado REAL NOT NULL,
      desconto_item REAL NOT NULL DEFAULT 0 CHECK (desconto_item >= 0),
      data_adicao TEXT NOT NULL,
      FOREIGN KEY (id_carrinho) REFERENCES $tableCarrinhos(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (codprd) REFERENCES $tableProdutos(codprd) ON DELETE RESTRICT ON UPDATE CASCADE
    );
    ''');
    batch.execute('CREATE INDEX IF NOT EXISTS idx_carrinho_itens_id_carrinho ON $tableCarrinhoItens (id_carrinho);');
     _logger.d("Comando CREATE TABLE IF NOT EXISTS $tableCarrinhoItens e INDEX adicionados ao batch.");
  }

  void _createPedidosParaEnvioTable(Batch batch) {
  batch.execute('''
  CREATE TABLE $tablePedidosParaEnvio (
    id_pedido_local INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo_pedido_app TEXT NOT NULL UNIQUE, 
    json_do_pedido TEXT NOT NULL,
    status_envio TEXT NOT NULL DEFAULT 'PENDENTE',
    data_criacao TEXT NOT NULL
  );
  ''');
  batch.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_status ON $tablePedidosParaEnvio (status_envio);');
  _logger.d("Comando CREATE TABLE $tablePedidosParaEnvio e INDEX adicionados ao batch.");
}
}