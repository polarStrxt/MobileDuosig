import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  static const int _databaseVersion = 1; // Reiniciando para nova estrutura
  
  // --- Constantes com Nomes de Tabelas ---
  static const String tableCondicaoPagamento = 'condicao_pagamento';
  static const String tableProdutos = 'produtos';
  static const String tableClientes = 'clientes';
  static const String tableDuplicata = 'duplicata';
  static const String tableConfig = 'config';
  static const String tableCarrinhos = 'carrinhos';
  static const String tableCarrinhoItens = 'carrinho_itens';
  static const String tablePedidos = 'pedidos';
  static const String tablePedidoItens = 'pedido_itens';
  static const String tablePedidosParaEnvio = 'pedidos_para_envio';
  static const String tableSincronizacao = 'sincronizacao';

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final Logger _logger = Logger();

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
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  Future<void> _onConfigure(Database db) async {
    _logger.i("Configurando banco de dados...");
    // Habilitar chaves estrangeiras
    await db.execute('PRAGMA foreign_keys = ON');
    // Otimizações de performance
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA cache_size = 10000');
    await db.execute('PRAGMA temp_store = MEMORY');
  }

  Future<void> _onCreate(Database db, int version) async {
    _logger.i("Criando banco de dados versão $version...");
    
    var batch = db.batch();
    
    // ORDEM IMPORTANTE: Tabelas sem FK primeiro
    _createConfigTable(batch);
    _createCondicaoPagamentoTable(batch);
    _createProdutosTable(batch);
    
    // Tabelas com FK depois
    _createClientesTable(batch);
    _createDuplicataTable(batch);
    _createCarrinhosTable(batch);
    _createCarrinhoItensTable(batch);
    _createPedidosTable(batch);
    _createPedidoItensTable(batch);
    _createPedidosParaEnvioTable(batch);
    _createSincronizacaoTable(batch);
    
    // Criar todos os índices
    _createIndexes(batch);
    
    await batch.commit(noResult: true, continueOnError: false);
    _logger.i("Banco de dados criado com sucesso.");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.w("Atualizando banco de dados da versão $oldVersion para $newVersion...");
    
    // Implementar migrações incrementais
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _runMigration(db, version);
    }
    
    _logger.i("Atualização do banco de dados concluída.");
  }

  Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 2:
        // Exemplo de migração futura
        // await db.execute('ALTER TABLE produtos ADD COLUMN novo_campo TEXT');
        break;
      default:
        _logger.w("Nenhuma migração definida para versão $version");
    }
  }

  // ============= CRIAÇÃO DE TABELAS =============

  void _createConfigTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableConfig (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cod_vendedor TEXT NOT NULL,
      nome_vendedor TEXT,
      endereco_api TEXT NOT NULL,
      usuario_duosig TEXT NOT NULL,
      usuario TEXT NOT NULL UNIQUE,
      senha TEXT NOT NULL,
      token_api TEXT,
      ultimo_sync INTEGER,
      versao_app TEXT,
      dispositivo_id TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
    ''');
    _logger.d("Tabela $tableConfig criada.");
  }

  void _createCondicaoPagamentoTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableCondicaoPagamento (
      codcndpgt INTEGER PRIMARY KEY,
      dcrcndpgt TEXT NOT NULL,
      qtd_parcelas INTEGER NOT NULL DEFAULT 1,
      dias_vencimento TEXT, -- JSON array [30, 60, 90]
      perdsccel REAL NOT NULL DEFAULT 0 CHECK (perdsccel >= 0 AND perdsccel <= 100),
      staati TEXT NOT NULL DEFAULT 'A' CHECK (staati IN ('A', 'I')),
      tipo_pagamento TEXT CHECK (tipo_pagamento IN ('DINHEIRO', 'CARTAO', 'BOLETO', 'PIX', 'CHEQUE')),
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
    ''');
    _logger.d("Tabela $tableCondicaoPagamento criada.");
  }

  void _createProdutosTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableProdutos (
      codprd INTEGER PRIMARY KEY,
      staati TEXT NOT NULL DEFAULT 'A' CHECK (staati IN ('A', 'I')),
      dcrprd TEXT NOT NULL,
      codigo_barras TEXT UNIQUE,
      qtdmulvda INTEGER NOT NULL DEFAULT 1 CHECK (qtdmulvda > 0),
      nommrc TEXT,
      categoria TEXT,
      subcategoria TEXT,
      vlrbasvda REAL NOT NULL CHECK (vlrbasvda >= 0),
      qtdetq INTEGER NOT NULL DEFAULT 0 CHECK (qtdetq >= 0),
      qtd_reservada INTEGER NOT NULL DEFAULT 0 CHECK (qtd_reservada >= 0),
      vlrpmcprd REAL NOT NULL DEFAULT 0 CHECK (vlrpmcprd >= 0),
      dtaini INTEGER, -- Timestamp início promoção
      dtafin INTEGER, -- Timestamp fim promoção
      vlrtab1 REAL NOT NULL DEFAULT 0 CHECK (vlrtab1 >= 0),
      vlrtab2 REAL NOT NULL DEFAULT 0 CHECK (vlrtab2 >= 0),
      peracrdsc1 REAL NOT NULL DEFAULT 0 CHECK (peracrdsc1 >= 0 AND peracrdsc1 <= 100),
      peracrdsc2 REAL NOT NULL DEFAULT 0 CHECK (peracrdsc2 >= 0 AND peracrdsc2 <= 100),
      codundprd TEXT NOT NULL DEFAULT 'UN',
      vol INTEGER NOT NULL DEFAULT 1,
      qtdvol INTEGER NOT NULL DEFAULT 1,
      perdscmxm REAL NOT NULL DEFAULT 0 CHECK (perdscmxm >= 0 AND perdscmxm <= 100),
      url_imagem TEXT,
      observacoes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
    ''');
    _logger.d("Tabela $tableProdutos criada.");
  }

  void _createClientesTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableClientes (
      codcli INTEGER PRIMARY KEY,
      nomcli TEXT NOT NULL,
      tipo_pessoa TEXT NOT NULL DEFAULT 'F' CHECK (tipo_pessoa IN ('F', 'J')),
      cgccpfcli TEXT NOT NULL UNIQUE,
      inscricao_estadual TEXT,
      ufdcli TEXT NOT NULL CHECK (length(ufdcli) = 2),
      cep TEXT,
      endcli TEXT NOT NULL,
      numero_endereco TEXT,
      complemento TEXT,
      baicli TEXT NOT NULL,
      muncli TEXT NOT NULL,
      numtel001 TEXT NOT NULL,
      numtel002 TEXT,
      whatsapp TEXT,
      nomfnt TEXT,
      emailcli TEXT,
      vlrlimcrd REAL NOT NULL DEFAULT 0 CHECK (vlrlimcrd >= 0),
      codtab INTEGER NOT NULL DEFAULT 1,
      codcndpgt INTEGER NOT NULL,
      vlrsldlimcrd REAL NOT NULL DEFAULT 0,
      vlrdplabe REAL NOT NULL DEFAULT 0 CHECK (vlrdplabe >= 0),
      vlrdplats REAL NOT NULL DEFAULT 0 CHECK (vlrdplats >= 0),
      data_ultimo_pedido INTEGER,
      observacoes TEXT,
      staati TEXT NOT NULL DEFAULT 'A' CHECK (staati IN ('A', 'I', 'B')), -- B=Bloqueado
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (codcndpgt) REFERENCES $tableCondicaoPagamento(codcndpgt) ON UPDATE CASCADE
    );
    ''');
    _logger.d("Tabela $tableClientes criada.");
  }

  void _createDuplicataTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableDuplicata (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      numdoc TEXT NOT NULL UNIQUE,
      codcli INTEGER NOT NULL,
      codped INTEGER,
      parcela INTEGER NOT NULL DEFAULT 1,
      total_parcelas INTEGER NOT NULL DEFAULT 1,
      dtaemi INTEGER NOT NULL,
      dtavct INTEGER NOT NULL,
      vlrdpl REAL NOT NULL CHECK (vlrdpl > 0),
      vlrpag REAL DEFAULT 0 CHECK (vlrpag >= 0),
      dtapag INTEGER,
      status TEXT NOT NULL DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'PAGO', 'PARCIAL', 'CANCELADO', 'VENCIDO')),
      tipo_documento TEXT CHECK (tipo_documento IN ('BOLETO', 'DUPLICATA', 'PROMISSORIA', 'CHEQUE')),
      observacoes TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (codcli) REFERENCES $tableClientes(codcli) ON DELETE RESTRICT ON UPDATE CASCADE,
      FOREIGN KEY (codped) REFERENCES $tablePedidos(id) ON DELETE SET NULL ON UPDATE CASCADE
    );
    ''');
    _logger.d("Tabela $tableDuplicata criada.");
  }

  void _createCarrinhosTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableCarrinhos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codcli INTEGER NOT NULL,
      codcndpgt INTEGER,
      tabela_preco INTEGER NOT NULL DEFAULT 1,
      data_criacao INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      data_ultima_modificacao INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      status TEXT NOT NULL DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'FINALIZADO', 'CANCELADO', 'CONVERTIDO')),
      cupom_desconto TEXT,
      valor_cupom_desconto REAL DEFAULT 0,
      valor_total_bruto REAL NOT NULL DEFAULT 0 CHECK (valor_total_bruto >= 0),
      valor_total_descontos REAL NOT NULL DEFAULT 0 CHECK (valor_total_descontos >= 0),
      valor_total_liquido REAL NOT NULL DEFAULT 0 CHECK (valor_total_liquido >= 0),
      observacoes TEXT,
      dispositivo_id TEXT,
      FOREIGN KEY (codcli) REFERENCES $tableClientes(codcli) ON DELETE RESTRICT ON UPDATE CASCADE,
      FOREIGN KEY (codcndpgt) REFERENCES $tableCondicaoPagamento(codcndpgt) ON DELETE SET NULL ON UPDATE CASCADE
    );
    ''');
    _logger.d("Tabela $tableCarrinhos criada.");
  }

  void _createCarrinhoItensTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableCarrinhoItens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_carrinho INTEGER NOT NULL,
      codprd INTEGER NOT NULL,
      quantidade REAL NOT NULL CHECK (quantidade > 0),
      preco_tabela REAL NOT NULL CHECK (preco_tabela >= 0),
      preco_unitario REAL NOT NULL CHECK (preco_unitario >= 0),
      desconto_percentual REAL NOT NULL DEFAULT 0 CHECK (desconto_percentual >= 0 AND desconto_percentual <= 100),
      desconto_valor REAL NOT NULL DEFAULT 0 CHECK (desconto_valor >= 0),
      valor_total_item REAL NOT NULL CHECK (valor_total_item >= 0),
      observacoes TEXT,
      data_adicao INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      data_modificacao INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (id_carrinho) REFERENCES $tableCarrinhos(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (codprd) REFERENCES $tableProdutos(codprd) ON DELETE RESTRICT ON UPDATE CASCADE,
      UNIQUE(id_carrinho, codprd)
    );
    ''');
    _logger.d("Tabela $tableCarrinhoItens criada.");
  }

  void _createPedidosTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tablePedidos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      codigo_pedido_app TEXT NOT NULL UNIQUE,
      numero_pedido_erp TEXT,
      codcli INTEGER NOT NULL,
      codven TEXT NOT NULL,
      codcndpgt INTEGER NOT NULL,
      tabela_preco INTEGER NOT NULL DEFAULT 1,
      data_pedido INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      data_entrega INTEGER,
      status TEXT NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'ENVIADO', 'CONFIRMADO', 'FATURADO', 'CANCELADO', 'ERRO')),
      tipo_pedido TEXT NOT NULL DEFAULT 'VENDA' CHECK (tipo_pedido IN ('VENDA', 'ORCAMENTO', 'CONSIGNACAO')),
      valor_total_bruto REAL NOT NULL CHECK (valor_total_bruto >= 0),
      valor_total_descontos REAL NOT NULL CHECK (valor_total_descontos >= 0),
      valor_frete REAL DEFAULT 0 CHECK (valor_frete >= 0),
      valor_total_liquido REAL NOT NULL CHECK (valor_total_liquido >= 0),
      observacoes TEXT,
      observacoes_internas TEXT,
      motivo_cancelamento TEXT,
      latitude REAL,
      longitude REAL,
      endereco_entrega TEXT,
      dispositivo_id TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      synchronized_at INTEGER,
      FOREIGN KEY (codcli) REFERENCES $tableClientes(codcli) ON DELETE RESTRICT ON UPDATE CASCADE,
      FOREIGN KEY (codcndpgt) REFERENCES $tableCondicaoPagamento(codcndpgt) ON DELETE RESTRICT ON UPDATE CASCADE
    );
    ''');
    _logger.d("Tabela $tablePedidos criada.");
  }

  void _createPedidoItensTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tablePedidoItens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_pedido INTEGER NOT NULL,
      codprd INTEGER NOT NULL,
      sequencia INTEGER NOT NULL,
      quantidade REAL NOT NULL CHECK (quantidade > 0),
      preco_tabela REAL NOT NULL CHECK (preco_tabela >= 0),
      preco_unitario REAL NOT NULL CHECK (preco_unitario >= 0),
      desconto_percentual REAL NOT NULL DEFAULT 0 CHECK (desconto_percentual >= 0 AND desconto_percentual <= 100),
      desconto_valor REAL NOT NULL DEFAULT 0 CHECK (desconto_valor >= 0),
      valor_total_item REAL NOT NULL CHECK (valor_total_item >= 0),
      observacoes TEXT,
      FOREIGN KEY (id_pedido) REFERENCES $tablePedidos(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (codprd) REFERENCES $tableProdutos(codprd) ON DELETE RESTRICT ON UPDATE CASCADE,
      UNIQUE(id_pedido, sequencia)
    );
    ''');
    _logger.d("Tabela $tablePedidoItens criada.");
  }

  void _createPedidosParaEnvioTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tablePedidosParaEnvio (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      id_pedido INTEGER NOT NULL,
      codigo_pedido_app TEXT NOT NULL,
      json_pedido TEXT NOT NULL,
      status_envio TEXT NOT NULL DEFAULT 'PENDENTE' CHECK (status_envio IN ('PENDENTE', 'ENVIANDO', 'ENVIADO', 'ERRO', 'CANCELADO')),
      tentativas INTEGER NOT NULL DEFAULT 0,
      ultima_tentativa INTEGER,
      erro_mensagem TEXT,
      prioridade INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (id_pedido) REFERENCES $tablePedidos(id) ON DELETE CASCADE ON UPDATE CASCADE
    );
    ''');
    _logger.d("Tabela $tablePedidosParaEnvio criada.");
  }

  void _createSincronizacaoTable(Batch batch) {
    batch.execute('''
    CREATE TABLE $tableSincronizacao (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tabela TEXT NOT NULL,
      tipo_sync TEXT NOT NULL CHECK (tipo_sync IN ('COMPLETA', 'INCREMENTAL', 'UPLOAD', 'DOWNLOAD')),
      status TEXT NOT NULL CHECK (status IN ('INICIADO', 'SUCESSO', 'ERRO', 'PARCIAL')),
      registros_total INTEGER DEFAULT 0,
      registros_sincronizados INTEGER DEFAULT 0,
      data_inicio INTEGER NOT NULL,
      data_fim INTEGER,
      erro_mensagem TEXT,
      dispositivo_id TEXT
    );
    ''');
    _logger.d("Tabela $tableSincronizacao criada.");
  }

  // ============= CRIAÇÃO DE ÍNDICES =============
  
  void _createIndexes(Batch batch) {
    // Índices para Clientes
    batch.execute('CREATE INDEX idx_clientes_cgccpf ON $tableClientes(cgccpfcli);');
    batch.execute('CREATE INDEX idx_clientes_nome ON $tableClientes(nomcli);');
    batch.execute('CREATE INDEX idx_clientes_status ON $tableClientes(staati);');
    batch.execute('CREATE INDEX idx_clientes_municipio ON $tableClientes(muncli);');
    
    // Índices para Produtos
    batch.execute('CREATE INDEX idx_produtos_descricao ON $tableProdutos(dcrprd);');
    batch.execute('CREATE INDEX idx_produtos_codigo_barras ON $tableProdutos(codigo_barras);');
    batch.execute('CREATE INDEX idx_produtos_marca ON $tableProdutos(nommrc);');
    batch.execute('CREATE INDEX idx_produtos_status ON $tableProdutos(staati);');
    batch.execute('CREATE INDEX idx_produtos_categoria ON $tableProdutos(categoria);');
    
    // Índices para Duplicatas
    batch.execute('CREATE INDEX idx_duplicata_cliente ON $tableDuplicata(codcli);');
    batch.execute('CREATE INDEX idx_duplicata_vencimento ON $tableDuplicata(dtavct);');
    batch.execute('CREATE INDEX idx_duplicata_status ON $tableDuplicata(status);');
    batch.execute('CREATE INDEX idx_duplicata_pedido ON $tableDuplicata(codped);');
    
    // Índices para Carrinhos
    batch.execute('CREATE INDEX idx_carrinhos_cliente_status ON $tableCarrinhos(codcli, status);');
    batch.execute('CREATE INDEX idx_carrinhos_data ON $tableCarrinhos(data_ultima_modificacao);');
    
    // Índices para Carrinho Itens
    batch.execute('CREATE INDEX idx_carrinho_itens_carrinho ON $tableCarrinhoItens(id_carrinho);');
    batch.execute('CREATE INDEX idx_carrinho_itens_produto ON $tableCarrinhoItens(codprd);');
    
    // Índices para Pedidos
    batch.execute('CREATE INDEX idx_pedidos_cliente ON $tablePedidos(codcli);');
    batch.execute('CREATE INDEX idx_pedidos_status ON $tablePedidos(status);');
    batch.execute('CREATE INDEX idx_pedidos_data ON $tablePedidos(data_pedido);');
    batch.execute('CREATE INDEX idx_pedidos_codigo_app ON $tablePedidos(codigo_pedido_app);');
    batch.execute('CREATE INDEX idx_pedidos_numero_erp ON $tablePedidos(numero_pedido_erp);');
    
    // Índices para Pedido Itens
    batch.execute('CREATE INDEX idx_pedido_itens_pedido ON $tablePedidoItens(id_pedido);');
    batch.execute('CREATE INDEX idx_pedido_itens_produto ON $tablePedidoItens(codprd);');
    
    // Índices para Pedidos Para Envio
    batch.execute('CREATE INDEX idx_pedidos_envio_status ON $tablePedidosParaEnvio(status_envio, prioridade);');
    batch.execute('CREATE INDEX idx_pedidos_envio_pedido ON $tablePedidosParaEnvio(id_pedido);');
    
    // Índices para Sincronização
    batch.execute('CREATE INDEX idx_sync_tabela_status ON $tableSincronizacao(tabela, status);');
    batch.execute('CREATE INDEX idx_sync_data ON $tableSincronizacao(data_inicio DESC);');
    
    _logger.d("Todos os índices criados.");
  }

  // ============= MÉTODOS AUXILIARES =============
  
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
    _logger.i("Banco de dados fechado.");
  }

  Future<void> deleteDatabase() async {
    final path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
    _logger.w("Banco de dados deletado.");
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final List<Map<String, dynamic>> tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    );
    
    Map<String, int> tableCounts = {};
    for (var table in tables) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM ${table['name']}')
      );
      tableCounts[table['name'] as String] = count ?? 0;
    }
    
    return {
      'version': _databaseVersion,
      'path': await getDatabasesPath(),
      'tables': tables.map((t) => t['name']).toList(),
      'counts': tableCounts,
    };
  }
}