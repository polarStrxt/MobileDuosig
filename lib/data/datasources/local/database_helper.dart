import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

class DatabaseHelper {
  static const String _databaseName = "docig_venda.db";
  static const int _databaseVersion = 9; // Incrementado para aplicar correções
  
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
  static const String tableClienteProduto = 'cliente_produto';

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
    _logger.i("Inicializando banco com estrutura da API em: $path");
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onOpen: _onOpen,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onOpen(Database db) async {
    _logger.i("Configurando banco para compatibilidade com API...");
    
    try {
      await db.execute('PRAGMA foreign_keys = OFF;');
      await db.execute('PRAGMA ignore_check_constraints = ON;');
      await db.execute('PRAGMA synchronous = OFF;');
      await db.rawQuery('PRAGMA journal_mode = MEMORY;');
      await db.execute('PRAGMA temp_store = MEMORY;');
      
      _logger.i("Banco configurado para aceitar dados da API");
      
    } catch (e) {
      _logger.w("Erro na configuração, mas continuando: $e");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    _logger.i("Criando todas as tabelas com estrutura da API...");
    
    // Tabelas da API com estrutura exata
    await _createProdutosTable(db);
    await _createClientesTable(db);
    await _createDuplicataTable(db);
    await _createCondicaoPagamentoTable(db);
    await _createClienteProdutoTable(db);
    
    // Tabelas locais do app
    await _createConfigTable(db);
    await _createCarrinhosTable(db);
    await _createCarrinhoItensTable(db);
    await _createPedidosTable(db);
    await _createPedidoItensTable(db);
    await _createPedidosParaEnvioTable(db);
    await _createSincronizacaoTable(db);
    
    await _createIndexes(db);
    
    _logger.i("Todas as tabelas criadas com estrutura correta");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _logger.i("Atualizando banco de versão $oldVersion para $newVersion");
    
    // Para simplificar, recria tudo
    await _dropAllTables(db);
    await _onCreate(db, newVersion);
  }

  Future<void> _dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS $tableProdutos');
    await db.execute('DROP TABLE IF EXISTS $tableClientes');
    await db.execute('DROP TABLE IF EXISTS $tableDuplicata');
    await db.execute('DROP TABLE IF EXISTS $tableCondicaoPagamento');
    await db.execute('DROP TABLE IF EXISTS $tableClienteProduto');
    await db.execute('DROP TABLE IF EXISTS $tableConfig');
    await db.execute('DROP TABLE IF EXISTS $tableCarrinhos');
    await db.execute('DROP TABLE IF EXISTS $tableCarrinhoItens');
    await db.execute('DROP TABLE IF EXISTS $tablePedidos');
    await db.execute('DROP TABLE IF EXISTS $tablePedidoItens');
    await db.execute('DROP TABLE IF EXISTS $tablePedidosParaEnvio');
    await db.execute('DROP TABLE IF EXISTS $tableSincronizacao');
  }

  // ============= TABELAS DA API COM ESTRUTURA EXATA =============

  /// Tabela PRODUTOS - Estrutura IDÊNTICA ao ProdutoModel
  Future<void> _createProdutosTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableProdutos (
        codprd INTEGER PRIMARY KEY NOT NULL,
        staati TEXT NOT NULL,
        dcrprd TEXT NOT NULL,
        qtdmulvda INTEGER NOT NULL,
        nommrc TEXT NOT NULL,
        vlrbasvda REAL NOT NULL,
        qtdetq INTEGER NOT NULL,
        vlrpmcprd REAL NOT NULL,
        dtaini TEXT,
        dtafin TEXT,
        vlrtab1 REAL NOT NULL,
        vlrtab2 REAL NOT NULL,
        peracrdsc1 REAL,
        peracrdsc2 REAL,
        codundprd TEXT NOT NULL,
        vol INTEGER NOT NULL,
        qtdvol INTEGER NOT NULL,
        perdscmxm REAL NOT NULL
      );
    ''');
    _logger.d("Tabela $tableProdutos criada (estrutura IDÊNTICA ao ProdutoModel)");
  }

  /// Tabela CLIENTES - Estrutura exata da API
  Future<void> _createClientesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableClientes (
        codcli INTEGER PRIMARY KEY,
        nomcli TEXT,
        cgccpfcli TEXT,
        ufdcli TEXT,
        endcli TEXT,
        baicli TEXT,
        muncli TEXT,
        numtel001 TEXT,
        numtel002 TEXT,
        nomfnt TEXT,
        emailcli TEXT,
        vlrlimcrd REAL,
        codtab INTEGER,
        codcndpgt INTEGER,
        vlrsldlimcrd REAL,
        vlrdplabe REAL,
        vlrdplats REAL,
        staati TEXT
      );
    ''');
    _logger.d("Tabela $tableClientes criada (estrutura exata da API)");
  }

  /// Tabela DUPLICATA - 4 campos exatos da API
  Future<void> _createDuplicataTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableDuplicata (
        numdoc TEXT,
        codcli INTEGER,
        dtavct TEXT,
        vlrdpl REAL
      );
    ''');
    _logger.d("Tabela $tableDuplicata criada (4 campos exatos da API)");
  }

  /// Tabela CONDIÇÃO PAGAMENTO - Para quando tivermos os dados da API
  Future<void> _createCondicaoPagamentoTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableCondicaoPagamento (
        codcndpgt INTEGER PRIMARY KEY,
        dcrcndpgt TEXT,
        qtd_parcelas INTEGER,
        dias_vencimento TEXT,
        perdsccel REAL,
        staati TEXT,
        tipo_pagamento TEXT
      );
    ''');
    _logger.d("Tabela $tableCondicaoPagamento criada");
  }

  /// Tabela CLIENTE-PRODUTO - Relação simples
  Future<void> _createClienteProdutoTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableClienteProduto (
        codcli INTEGER,
        codprd INTEGER
      );
    ''');
    _logger.d("Tabela $tableClienteProduto criada");
  }

  // ============= TABELAS LOCAIS DO APP =============

  Future<void> _createConfigTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableConfig (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cod_vendedor TEXT,
        nome_vendedor TEXT,
        endereco_api TEXT,
        usuario_duosig TEXT,
        usuario TEXT,
        senha TEXT,
        token_api TEXT,
        ultimo_sync TEXT,
        versao_app TEXT,
        dispositivo_id TEXT,
        created_at TEXT,
        updated_at TEXT
      );
    ''');
    _logger.d("Tabela $tableConfig criada");
  }

  Future<void> _createCarrinhosTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableCarrinhos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codcli INTEGER,
        data_criacao TEXT,
        data_ultima_modificacao TEXT,
        status TEXT,
        valor_total_bruto REAL,
        valor_total_descontos REAL,
        valor_total_liquido REAL,
        observacoes TEXT
      );
    ''');
    _logger.d("Tabela $tableCarrinhos criada");
  }

  Future<void> _createCarrinhoItensTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableCarrinhoItens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_carrinho INTEGER,
        codprd INTEGER,
        quantidade INTEGER,
        preco_unitario_registrado REAL,
        desconto_item REAL,
        data_adicao TEXT,
        observacoes TEXT
      );
    ''');
    _logger.d("Tabela $tableCarrinhoItens criada");
  }

  Future<void> _createPedidosTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablePedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_pedido_app TEXT,
        numero_pedido_erp TEXT,
        codcli INTEGER,
        codven TEXT,
        codcndpgt INTEGER,
        tabela_preco INTEGER,
        data_pedido TEXT,
        data_entrega TEXT,
        status TEXT,
        tipo_pedido TEXT,
        valor_total_bruto REAL,
        valor_total_descontos REAL,
        valor_frete REAL,
        valor_total_liquido REAL,
        observacoes TEXT,
        observacoes_internas TEXT,
        motivo_cancelamento TEXT,
        latitude REAL,
        longitude REAL,
        endereco_entrega TEXT,
        dispositivo_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        synchronized_at TEXT
      );
    ''');
    _logger.d("Tabela $tablePedidos criada");
  }

  Future<void> _createPedidoItensTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablePedidoItens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_pedido INTEGER,
        codprd INTEGER,
        sequencia INTEGER,
        quantidade REAL,
        preco_tabela REAL,
        preco_unitario REAL,
        desconto_percentual REAL,
        desconto_valor REAL,
        valor_total_item REAL,
        observacoes TEXT
      );
    ''');
    _logger.d("Tabela $tablePedidoItens criada");
  }

  Future<void> _createPedidosParaEnvioTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tablePedidosParaEnvio (
        id_pedido_local INTEGER PRIMARY KEY,
        codigo_pedido_app TEXT,
        json_pedido TEXT,
        status_envio TEXT,
        tentativas INTEGER,
        ultima_tentativa TEXT,
        erro_mensagem TEXT,
        prioridade INTEGER,
        data_criacao TEXT,
        data_ultima_tentativa TEXT
      );
    ''');
    _logger.d("Tabela $tablePedidosParaEnvio criada");
  }

  Future<void> _createSincronizacaoTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSincronizacao (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tabela TEXT,
        tipo_sync TEXT,
        status TEXT,
        registros_total INTEGER,
        registros_sincronizados INTEGER,
        data_inicio TEXT,
        data_fim TEXT,
        erro_mensagem TEXT,
        dispositivo_id TEXT
      );
    ''');
    _logger.d("Tabela $tableSincronizacao criada");
  }

  Future<void> _createIndexes(Database db) async {
    try {
      // Índices das tabelas da API
      await db.execute('CREATE INDEX IF NOT EXISTS idx_produtos_codprd ON $tableProdutos(codprd);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_clientes_codcli ON $tableClientes(codcli);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_duplicata_codcli ON $tableDuplicata(codcli);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_condicao_codcndpgt ON $tableCondicaoPagamento(codcndpgt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cliente_produto_codcli ON $tableClienteProduto(codcli);');
      
      // Índices das tabelas locais
      await db.execute('CREATE INDEX IF NOT EXISTS idx_carrinhos_codcli ON $tableCarrinhos(codcli);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_carrinho_itens_carrinho ON $tableCarrinhoItens(id_carrinho);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pedidos_codcli ON $tablePedidos(codcli);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pedido_itens_pedido ON $tablePedidoItens(id_pedido);');
      
      _logger.d("Índices criados");
    } catch (e) {
      _logger.w("Alguns índices falharam: $e");
    }
  }

  // ============= MÉTODOS DE INSERÇÃO PARA API =============

  /// Inserir produtos da API em lote - MÉTODO ATUALIZADO
  Future<int> inserirProdutosDaAPI(List<Map<String, dynamic>> produtos) async {
    final db = await database;
    int inseridos = 0;
    
    await db.transaction((txn) async {
      await txn.delete(tableProdutos);
      
      for (final produto in produtos) {
        try {
          // Preparar dados com conversão adequada de tipos
          final Map<String, dynamic> dadosParaInserir = {
            'codprd': produto['codprd'] ?? 0,
            'staati': produto['staati'] ?? '',
            'dcrprd': produto['dcrprd'] ?? '',
            'qtdmulvda': produto['qtdmulvda'] ?? 0,
            'nommrc': produto['nommrc'] ?? '',
            'vlrbasvda': _toDouble(produto['vlrbasvda']) ?? 0.0,
            'qtdetq': produto['qtdetq'] ?? 0,
            'vlrpmcprd': _toDouble(produto['vlrpmcprd']) ?? 0.0,
            'dtaini': produto['dtaini'], // Pode ser null
            'dtafin': produto['dtafin'], // Pode ser null
            'vlrtab1': _toDouble(produto['vlrtab1']) ?? 0.0,
            'vlrtab2': _toDouble(produto['vlrtab2']) ?? 0.0,
            'peracrdsc1': _toDouble(produto['peracrdsc1']), // Pode ser null
            'peracrdsc2': _toDouble(produto['peracrdsc2']), // Pode ser null
            'codundprd': produto['codundprd'] ?? '',
            'vol': produto['vol'] ?? 0,
            'qtdvol': produto['qtdvol'] ?? 0,
            'perdscmxm': _toDouble(produto['perdscmxm']) ?? 0.0,
          };
          
          await txn.insert(tableProdutos, dadosParaInserir);
          inseridos++;
        } catch (e) {
          _logger.w("Erro ao inserir produto ${produto['codprd']}: $e");
        }
      }
    });
    
    _logger.i("Produtos da API inseridos: $inseridos de ${produtos.length}");
    return inseridos;
  }

  /// Inserir clientes da API em lote
  Future<int> inserirClientesDaAPI(List<Map<String, dynamic>> clientes) async {
    final db = await database;
    int inseridos = 0;
    
    await db.transaction((txn) async {
      await txn.delete(tableClientes);
      
      for (final cliente in clientes) {
        try {
          await txn.insert(tableClientes, {
            'codcli': cliente['codcli'],
            'nomcli': cliente['nomcli'],
            'cgccpfcli': cliente['cgccpfcli'],
            'ufdcli': cliente['ufdcli'],
            'endcli': cliente['endcli'],
            'baicli': cliente['baicli'],
            'muncli': cliente['muncli'],
            'numtel001': cliente['numtel001'],
            'numtel002': cliente['numtel002'],
            'nomfnt': cliente['nomfnt'],
            'emailcli': cliente['emailcli'],
            'vlrlimcrd': cliente['vlrlimcrd'],
            'codtab': cliente['codtab'],
            'codcndpgt': cliente['codcndpgt'],
            'vlrsldlimcrd': cliente['vlrsldlimcrd'],
            'vlrdplabe': cliente['vlrdplabe'],
            'vlrdplats': cliente['vlrdplats'],
            'staati': cliente['staati'],
          });
          inseridos++;
        } catch (e) {
          _logger.w("Erro ao inserir cliente ${cliente['codcli']}: $e");
        }
      }
    });
    
    _logger.i("Clientes da API inseridos: $inseridos de ${clientes.length}");
    return inseridos;
  }

  /// Inserir duplicatas da API em lote
  Future<int> inserirDuplicatasDaAPI(List<Map<String, dynamic>> duplicatas) async {
    final db = await database;
    int inseridos = 0;
    
    await db.transaction((txn) async {
      await txn.delete(tableDuplicata);
      
      for (final duplicata in duplicatas) {
        try {
          await txn.insert(tableDuplicata, {
            'numdoc': duplicata['numdoc'],
            'codcli': duplicata['codcli'],
            'dtavct': duplicata['dtavct'],
            'vlrdpl': duplicata['vlrdpl'],
          });
          inseridos++;
        } catch (e) {
          _logger.w("Erro ao inserir duplicata ${duplicata['numdoc']}: $e");
        }
      }
    });
    
    _logger.i("Duplicatas da API inseridas: $inseridos de ${duplicatas.length}");
    return inseridos;
  }

  // ============= MÉTODOS AUXILIARES =============

  /// Converte qualquer valor para double, retornando null se não for possível
  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Buscar produto por código - MÉTODO OTIMIZADO
  Future<Map<String, dynamic>?> getProdutoByCodigo(int codprd) async {
    final db = await database;
    final result = await db.query(
      tableProdutos,
      where: 'codprd = ?',
      whereArgs: [codprd],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first : null;
  }

  /// Buscar produtos com filtros
  Future<List<Map<String, dynamic>>> getProdutos({
    String? filtroNome,
    String? filtroMarca,
    bool? apenasAtivos,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    List<String> conditions = [];
    
    if (apenasAtivos == true) {
      conditions.add("staati = ?");
      whereArgs.add('A');
    }
    
    if (filtroNome != null && filtroNome.isNotEmpty) {
      conditions.add("dcrprd LIKE ?");
      whereArgs.add('%$filtroNome%');
    }
    
    if (filtroMarca != null && filtroMarca.isNotEmpty) {
      conditions.add("nommrc LIKE ?");
      whereArgs.add('%$filtroMarca%');
    }
    
    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
    }
    
    return await db.query(
      tableProdutos,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'dcrprd ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getDuplicatasByCliente(int codcli) async {
    final db = await database;
    return await db.query(
      tableDuplicata,
      where: 'codcli = ?',
      whereArgs: [codcli],
      orderBy: 'dtavct DESC',
    );
  }

  Future<Map<String, dynamic>> getStatusBanco() async {
    final db = await database;
    
    final produtos = await db.rawQuery('SELECT COUNT(*) as count FROM $tableProdutos');
    final clientes = await db.rawQuery('SELECT COUNT(*) as count FROM $tableClientes');
    final duplicatas = await db.rawQuery('SELECT COUNT(*) as count FROM $tableDuplicata');
    
    return {
      'produtos': produtos.first['count'],
      'clientes': clientes.first['count'],
      'duplicatas': duplicatas.first['count'],
      'versao': _databaseVersion,
      'nome': _databaseName,
    };
  }

  Future<void> limparDadosAPI() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableProdutos);
      await txn.delete(tableClientes);
      await txn.delete(tableDuplicata);
      await txn.delete(tableCondicaoPagamento);
      await txn.delete(tableClienteProduto);
    });
    _logger.i("Dados da API limpos");
  }

  /// Insere qualquer dado em qualquer tabela
  Future<int> insertAnyData(String tableName, Map<String, dynamic> data) async {
    try {
      final db = await database;
      final id = await db.insert(tableName, data);
      _logger.d("Inserido em $tableName: ID $id");
      return id;
    } catch (e) {
      _logger.e("Erro ao inserir em $tableName: $e");
      rethrow;
    }
  }

  /// Busca dados de qualquer tabela
  Future<List<Map<String, dynamic>>> queryAnyTable(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    try {
      final db = await database;
      return await db.query(tableName, where: where, whereArgs: whereArgs);
    } catch (e) {
      _logger.e("Erro ao consultar $tableName: $e");
      return [];
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _logger.i("Banco de dados fechado");
    }
  }

  Future<void> deleteDatabase() async {
    try {
      await close();
      final path = join(await getDatabasesPath(), _databaseName);
      await databaseFactory.deleteDatabase(path);
      _logger.w("Banco de dados deletado: $path");
    } catch (e, stackTrace) {
      _logger.e("Erro ao deletar banco de dados", error: e, stackTrace: stackTrace);
    }
  }
}