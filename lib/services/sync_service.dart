import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Importar o VendasService otimizado
import 'package:flutter_docig_venda/services/vendas_service.dart';

// Importar os modelos necessários
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/condicao_pagamento_model.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_produto_model.dart';

/// Resultado da sincronização otimizado com métricas detalhadas
class SyncResult {
  final Map<String, int> counts;
  final bool isSuccess;
  final String? errorMessage;
  final DateTime timestamp;
  final Duration duration;
  final Map<String, dynamic>? metrics;
  
  const SyncResult._({
    required this.counts,
    required this.isSuccess,
    this.errorMessage,
    required this.timestamp,
    required this.duration,
    this.metrics,
  });
  
  factory SyncResult.success(
    Map<String, int> counts, 
    DateTime startTime, {
    Map<String, dynamic>? metrics,
  }) {
    return SyncResult._(
      counts: counts,
      isSuccess: true,
      timestamp: DateTime.now(),
      duration: DateTime.now().difference(startTime),
      metrics: metrics,
    );
  }
        
  factory SyncResult.error(
    String errorMessage,
    DateTime startTime,
  ) {
    return SyncResult._(
      counts: const {},
      isSuccess: false,
      errorMessage: errorMessage,
      timestamp: DateTime.now(),
      duration: DateTime.now().difference(startTime),
    );
  }
        
  int get totalCount => counts.values.fold(0, (prev, count) => prev + count);
  
  double get recordsPerSecond => totalCount / (duration.inMilliseconds / 1000.0);
  
  @override
  String toString() {
    if (!isSuccess) return 'SyncResult(error: $errorMessage, duration: ${duration.inSeconds}s)';
    return 'SyncResult(counts: $counts, total: $totalCount, duration: ${duration.inSeconds}s, rps: ${recordsPerSecond.toStringAsFixed(2)})';
  }
}

/// Configurações de sincronização
class SyncConfig {
  final DateTime? dataCorte;
  final bool forcarSincronizacao;
  final bool usarCache;
  final List<String> entidadesEspecificas;
  final int batchSize;
  final bool sincronizacaoCompleta;
  
  const SyncConfig({
    this.dataCorte,
    this.forcarSincronizacao = false,
    this.usarCache = true,
    this.entidadesEspecificas = const [],
    this.batchSize = 1000,
    this.sincronizacaoCompleta = true,
  });
}

/// Serviço de sincronização otimizado com nova API
class SyncService {
  // Service único otimizado
  final VendasService _vendasService;
  final Logger _logger;
  
  // Repositories - inicializados de forma lazy
  late final RepositoryManager _repositories;
  bool _repositoriesInitialized = false;
  
  // Métricas de performance
  final Map<String, Duration> _metricas = {};
  DateTime? _ultimaSincronizacao;
  
  /// Construtor otimizado com injeção de dependência
  SyncService({
    VendasService? vendasService,
    Logger? logger,
    RepositoryManager? repositories,
    String? baseUrl,
    String? codigoVendedor,
  }) : _vendasService = vendasService ?? VendasService(
         apiClient: UnifiedApiClient(
           baseUrl: baseUrl ?? 'http://duotecsuprilev.ddns.com.br:8082',
           codigoVendedor: codigoVendedor ?? '001',
         )
       ),
       _logger = logger ?? Logger(
         printer: PrettyPrinter(
           methodCount: 2,
           errorMethodCount: 8,
           lineLength: 120,
           colors: true,
           printEmojis: true,
           dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
         )
       ) {
    if (repositories != null) {
      _repositories = repositories;
      _repositoriesInitialized = true;
    }
  }
  
  /// Inicializa os repositories de forma otimizada
  Future<void> _ensureRepositories() async {
    if (!_repositoriesInitialized) {
      final stopwatch = Stopwatch()..start();
      
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.database; // Garante que o banco está inicializado
      _repositories = RepositoryManager(dbHelper);
      _repositoriesInitialized = true;
      
      stopwatch.stop();
      _metricas['database_init'] = stopwatch.elapsed;
      _logger.d("Database inicializado em ${stopwatch.elapsedMilliseconds}ms");
    }
  }

  /// Verifica conectividade otimizada
  Future<ApiResult<bool>> verificarConexaoInternet() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Primeiro verifica conectividade básica
      final conectividade = await Connectivity().checkConnectivity();
      if (conectividade.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet
      )) {
        _logger.d("Conectividade de rede disponível");
        
        // Tenta uma requisição simples para verificar se a API responde
        // Usando endpoint de clientes sem especificar tipo de retorno
        try {
          final testResult = await _vendasService.apiClient.get(
            '/v1/cliente/${_vendasService.codigoVendedor}/31.01.1980',
            useCache: false,
            customTimeout: const Duration(seconds: 10),
            maxRetries: 1,
          );
          
          stopwatch.stop();
          _metricas['connectivity_check'] = stopwatch.elapsed;
          
          // Se recebeu qualquer resposta (lista ou objeto), considera conectado
          if (testResult.isSuccess && testResult.data != null) {
            _logger.i("Conexão com API confirmada (${stopwatch.elapsedMilliseconds}ms)");
            return ApiResult.success(true);
          } else {
            _logger.w("API não responde adequadamente: ${testResult.errorMessage}");
            return ApiResult.success(false);
          }
        } catch (e) {
          _logger.w("Erro ao testar API: $e");
          return ApiResult.success(false);
        }
      } else {
        stopwatch.stop();
        _logger.w("Sem conectividade de rede");
        return ApiResult.success(false);
      }
    } catch (e) {
      stopwatch.stop();
      _logger.e("Erro ao verificar conexão", error: e);
      return ApiResult.error("Falha ao verificar conexão: $e");
    }
  }

  /// Sincronização completa otimizada
  Future<SyncResult> sincronizarTodosDados({SyncConfig? config}) async {
    final startTime = DateTime.now();
    final syncConfig = config ?? const SyncConfig();
    
    await _ensureRepositories();
    
    _logger.i("🚀 Iniciando sincronização completa...");
    _logger.d("Config: forçar=${syncConfig.forcarSincronizacao}, cache=${syncConfig.usarCache}");
    
    // Verifica conectividade apenas se não forçada
    if (!syncConfig.forcarSincronizacao) {
      final internetResult = await verificarConexaoInternet();
      if (!internetResult.isSuccess || !internetResult.data!) {
        return SyncResult.error(
          internetResult.errorMessage ?? "Sem conexão com a internet",
          startTime
        );
      }
    }
    
    try {
      // Usa sincronização em lote do VendasService para máxima eficiência
      final resultados = await _vendasService.sincronizarTudo(
        dataCorte: syncConfig.dataCorte,
        useCache: syncConfig.usarCache,
      );
      
      final counts = <String, int>{};
      final errors = <String>[];
      
      // Processa resultados em paralelo
      await Future.wait([
        if (resultados['produtos']!.isSuccess) _processarProdutos(resultados['produtos']!.data! as List<ProdutoModel>, counts),
        if (resultados['clientes']!.isSuccess) _processarClientes(resultados['clientes']!.data! as List<Cliente>, counts),
        if (resultados['condicoesPagamento']!.isSuccess) _processarCondicoesPagamento(resultados['condicoesPagamento']!.data! as List<CondicaoPagamentoModel>, counts),
        if (resultados['clienteProdutos']!.isSuccess) _processarClienteProdutos(resultados['clienteProdutos']!.data! as List<ClienteProdutoModel>, counts),
        if (resultados['duplicatas']!.isSuccess) _processarDuplicatas(resultados['duplicatas']!.data! as List<Duplicata>, counts),
      ]);
      
      // Coleta erros
      resultados.forEach((key, result) {
        if (!result.isSuccess) {
          errors.add('$key: ${result.errorMessage}');
        }
      });
      
      if (errors.isNotEmpty && counts.isEmpty) {
        return SyncResult.error("Erros na sincronização: ${errors.join('; ')}", startTime);
      }
      
      _ultimaSincronizacao = DateTime.now();
      
      final metrics = {
        'errors': errors,
        'connectivity_time': _metricas['connectivity_check']?.inMilliseconds ?? 0,
        'database_time': _metricas['database_init']?.inMilliseconds ?? 0,
        'config': syncConfig.toString(),
      };
      
      _logger.i("✅ Sincronização concluída!");
      _logger.i("📊 Total sincronizado: ${counts.values.fold(0, (a, b) => a + b)} registros");
      if (errors.isNotEmpty) {
        _logger.w("⚠️ Alguns erros ocorreram: ${errors.length} falhas");
      }
      
      return SyncResult.success(counts, startTime, metrics: metrics);
    } catch (e, stackTrace) {
      _logger.e("💥 Erro crítico durante a sincronização", error: e, stackTrace: stackTrace);
      return SyncResult.error("Falha crítica na sincronização: $e", startTime);
    }
  }

  /// Processamento otimizado de produtos
  Future<void> _processarProdutos(List<ProdutoModel> produtos, Map<String, int> counts) async {
    if (produtos.isEmpty) {
      _logger.w("Nenhum produto retornado da API");
      counts['Produtos'] = 0;
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    
    // Limpa e insere em lote para máxima performance
    await _repositories.produtos.deleteAll();
    await _repositories.produtos.upsertBatch(produtos);
    
    stopwatch.stop();
    counts['Produtos'] = produtos.length;
    _metricas['produtos_processing'] = stopwatch.elapsed;
    
    _logger.d("✅ Produtos processados: ${produtos.length} em ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Processamento otimizado de clientes (sem validações)
  Future<void> _processarClientes(List<Cliente> clientes, Map<String, int> counts) async {
    if (clientes.isEmpty) {
      _logger.w("Nenhum cliente retornado da API");
      counts['Clientes'] = 0;
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    
    try {
      // Limpa tabela antes de inserir
      await _repositories.clientes.deleteAll();
      
      // Insere clientes sem qualquer validação
      await _repositories.clientes.upsertBatch(clientes);
      
      stopwatch.stop();
      counts['Clientes'] = clientes.length;
      _metricas['clientes_processing'] = stopwatch.elapsed;
      
      _logger.d("Clientes processados: ${clientes.length} em ${stopwatch.elapsedMilliseconds}ms");
    } catch (e, stackTrace) {
      _logger.e("Erro ao processar clientes", error: e, stackTrace: stackTrace);
    }
  }

  // Cache para armazenar qual constraint está ativa no banco - REMOVIDO
  // Todos os métodos de validação removidos - banco agora aceita qualquer valor

  /// Processa clientes individualmente para identificar problemas - MÉTODO REMOVIDO
  /// Com banco sem restrições, este método não é mais necessário

  /// Processamento otimizado de condições de pagamento
  Future<void> _processarCondicoesPagamento(List<CondicaoPagamentoModel> condicoes, Map<String, int> counts) async {
    if (condicoes.isEmpty) {
      _logger.w("Nenhuma condição de pagamento retornada da API");
      counts['Condições Pagamento'] = 0;
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    
    await _repositories.condicoesPagamento.deleteAll();
    await _repositories.condicoesPagamento.upsertBatch(condicoes);
    
    stopwatch.stop();
    counts['Condições Pagamento'] = condicoes.length;
    _metricas['condicoes_processing'] = stopwatch.elapsed;
    
    _logger.d("✅ Condições de pagamento processadas: ${condicoes.length} em ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Processamento otimizado de cliente-produtos
  Future<void> _processarClienteProdutos(List<ClienteProdutoModel> clienteProdutos, Map<String, int> counts) async {
    if (clienteProdutos.isEmpty) {
      _logger.w("Nenhuma relação cliente-produto retornada da API");
      counts['Cliente-Produtos'] = 0;
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    
    // Limpa tabela cliente_produto
    final db = await _repositories.dbHelper.database;
    await db.delete(DatabaseHelper.tableClienteProduto);
    
    // Insere novos registros em lote
    final batch = db.batch();
    for (final cp in clienteProdutos) {
      batch.insert(DatabaseHelper.tableClienteProduto, cp.toJson());
    }
    await batch.commit(noResult: true);
    
    stopwatch.stop();
    counts['Cliente-Produtos'] = clienteProdutos.length;
    _metricas['cliente_produtos_processing'] = stopwatch.elapsed;
    
    _logger.d("✅ Cliente-produtos processados: ${clienteProdutos.length} em ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Processamento otimizado de duplicatas
  Future<void> _processarDuplicatas(List<Duplicata> duplicatas, Map<String, int> counts) async {
    if (duplicatas.isEmpty) {
      _logger.w("Nenhuma duplicata retornada da API");
      counts['Duplicatas'] = 0;
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    
    await _repositories.duplicatas.deleteAll();
    await _repositories.duplicatas.upsertBatch(duplicatas);
    
    stopwatch.stop();
    counts['Duplicatas'] = duplicatas.length;
    _metricas['duplicatas_processing'] = stopwatch.elapsed;
    
    _logger.d("✅ Duplicatas processadas: ${duplicatas.length} em ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Métodos de sincronização individual otimizados
  
  Future<ApiResult<int>> sincronizarProdutos({SyncConfig? config}) async {
    final syncConfig = config ?? const SyncConfig();
    
    try {
      await _ensureRepositories();
      _logger.i("🔄 Sincronizando produtos...");
      
      final result = await _vendasService.buscarProdutos(
        useCache: syncConfig.usarCache,
        dataCorte: syncConfig.dataCorte,
      );
      
      if (!result.isSuccess) {
        return ApiResult.error("Falha ao buscar produtos: ${result.errorMessage}");
      }
      
      final produtos = result.data ?? [];
      if (produtos.isEmpty) {
        return ApiResult.success(0);
      }
      
      await _repositories.produtos.deleteAll();
      await _repositories.produtos.upsertBatch(produtos);
      
      _logger.i("✅ Produtos sincronizados: ${produtos.length}");
      return ApiResult.success(produtos.length);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao sincronizar produtos", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao sincronizar produtos: $e");
    }
  }

  Future<ApiResult<int>> sincronizarClientes({SyncConfig? config}) async {
    final syncConfig = config ?? const SyncConfig();
    
    try {
      await _ensureRepositories();
      _logger.i("🔄 Sincronizando clientes...");
      
      final result = await _vendasService.buscarClientes(
        useCache: syncConfig.usarCache,
        dataCorte: syncConfig.dataCorte,
      );
      
      if (!result.isSuccess) {
        return ApiResult.error("Falha ao buscar clientes: ${result.errorMessage}");
      }
      
      final clientes = result.data ?? [];
      if (clientes.isEmpty) {
        return ApiResult.success(0);
      }
      
      await _repositories.clientes.deleteAll();
      await _repositories.clientes.upsertBatch(clientes);
      
      _logger.i("✅ Clientes sincronizados: ${clientes.length}");
      return ApiResult.success(clientes.length);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao sincronizar clientes", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao sincronizar clientes: $e");
    }
  }

  Future<ApiResult<int>> sincronizarCondicoesPagamento({SyncConfig? config}) async {
    final syncConfig = config ?? const SyncConfig();
    
    try {
      await _ensureRepositories();
      _logger.i("🔄 Sincronizando condições de pagamento...");
      
      final result = await _vendasService.buscarCondicoesPagamento(
        useCache: syncConfig.usarCache,
        dataCorte: syncConfig.dataCorte,
      );
      
      if (!result.isSuccess) {
        return ApiResult.error("Falha ao buscar condições de pagamento: ${result.errorMessage}");
      }
      
      final condicoes = result.data ?? [];
      if (condicoes.isEmpty) {
        return ApiResult.success(0);
      }
      
      await _repositories.condicoesPagamento.deleteAll();
      await _repositories.condicoesPagamento.upsertBatch(condicoes);
      
      _logger.i("✅ Condições de pagamento sincronizadas: ${condicoes.length}");
      return ApiResult.success(condicoes.length);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao sincronizar condições de pagamento", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao sincronizar condições de pagamento: $e");
    }
  }

  /// Busca específica otimizada
  Future<ApiResult<dynamic>> buscarProdutoPorCodigo(int codigo) async {
    try {
      _logger.i("🔍 Buscando produto: $codigo");
      
      final result = await _vendasService.buscarProdutoPorCodigo(codigo);
      
      if (!result.isSuccess) {
        return ApiResult.error("Falha ao buscar produto: ${result.errorMessage}");
      }
      
      if (result.data == null) {
        return ApiResult.error("Produto não encontrado");
      }
      
      _logger.i("✅ Produto encontrado: ${result.data!.dcrprd}");
      return ApiResult.success(result.data);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao buscar produto", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao buscar produto: $e");
    }
  }

  Future<ApiResult<dynamic>> buscarClientePorCodigo(int codigo) async {
    try {
      _logger.i("🔍 Buscando cliente: $codigo");
      
      final result = await _vendasService.buscarClientePorCodigo(codigo);
      
      if (!result.isSuccess) {
        return ApiResult.error("Falha ao buscar cliente: ${result.errorMessage}");
      }
      
      if (result.data == null) {
        return ApiResult.error("Cliente não encontrado");
      }
      
      _logger.i("✅ Cliente encontrado: ${result.data!.nomcli}");
      return ApiResult.success(result.data);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao buscar cliente", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao buscar cliente: $e");
    }
  }

  /// Limpeza otimizada
  Future<ApiResult<bool>> limparTodasTabelas() async {
    await _ensureRepositories();
    
    try {
      _logger.i("🧹 Limpando todas as tabelas...");
      final stopwatch = Stopwatch()..start();
      
      // Executa limpeza em paralelo
      await Future.wait([
        _repositories.produtos.deleteAll(),
        _repositories.clientes.deleteAll(),
        _repositories.condicoesPagamento.deleteAll(),
        _repositories.duplicatas.deleteAll(),
        _repositories.carrinhos.deleteAll(),
        _repositories.carrinhoItens.deleteAll(),
        _repositories.pedidosParaEnvio.deleteAll(),
      ]);
      
      // Limpeza adicional
      final db = await _repositories.dbHelper.database;
      await db.delete(DatabaseHelper.tableClienteProduto);
      
      stopwatch.stop();
      _logger.i("✅ Tabelas limpas em ${stopwatch.elapsedMilliseconds}ms");
      return ApiResult.success(true);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao limpar tabelas", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao limpar tabelas: $e");
    }
  }

  /// Estatísticas detalhadas
  Future<Map<String, dynamic>> obterEstatisticasDetalhadas() async {
    await _ensureRepositories();
    
    try {
      final countResult = await obterContagemRegistros();
      final hasInternet = await verificarConexaoInternet();
      final hasLocalData = await temDadosLocais();
      
      return {
        'contagens': countResult.isSuccess ? countResult.data : {},
        'temInternet': hasInternet.isSuccess ? hasInternet.data : false,
        'temDadosLocais': hasLocalData,
        'totalRegistros': countResult.isSuccess 
            ? countResult.data!.values.fold(0, (a, b) => a + b) 
            : 0,
        'ultimaSincronizacao': _ultimaSincronizacao?.toIso8601String(),
        'metricas': _metricas.map((k, v) => MapEntry(k, v.inMilliseconds)),
        'vendasServiceStats': _vendasService.obterEstatisticas(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e("❌ Erro ao obter estatísticas", error: e);
      return {
        'erro': 'Falha ao obter estatísticas: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Contagem otimizada de registros
  Future<ApiResult<Map<String, int>>> obterContagemRegistros() async {
    await _ensureRepositories();
    
    try {
      final stopwatch = Stopwatch()..start();
      
      // Executa contagens em paralelo
      final results = await Future.wait([
        _repositories.produtos.count(),
        _repositories.clientes.count(),
        _repositories.condicoesPagamento.count(),
        _repositories.duplicatas.count(),
        _repositories.carrinhos.count(),
        _repositories.carrinhoItens.count(),
        _repositories.pedidosParaEnvio.count(),
      ]);
      
      // Contagem de cliente_produto
      final db = await _repositories.dbHelper.database;
      final clienteProdutoResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableClienteProduto}'
      );
      final clienteProdutoCount = Sqflite.firstIntValue(clienteProdutoResult) ?? 0;
      
      final counts = <String, int>{
        'Produtos': results[0],
        'Clientes': results[1],
        'Condições Pagamento': results[2],
        'Duplicatas': results[3],
        'Carrinhos': results[4],
        'Itens Carrinho': results[5],
        'Pedidos Pendentes': results[6],
        'Cliente-Produtos': clienteProdutoCount,
      };
      
      stopwatch.stop();
      _metricas['count_query'] = stopwatch.elapsed;
      
      _logger.d("📊 Contagem obtida em ${stopwatch.elapsedMilliseconds}ms: $counts");
      return ApiResult.success(counts);
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao contar registros", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao obter contagem: $e");
    }
  }

  /// Verifica se tem dados locais
  Future<bool> temDadosLocais() async {
    await _ensureRepositories();
    
    try {
      final countResult = await obterContagemRegistros();
      if (!countResult.isSuccess) return false;
      
      final mainTables = ['Produtos', 'Clientes', 'Condições Pagamento'];
      int total = 0;
      
      countResult.data?.forEach((key, value) {
        if (mainTables.contains(key)) {
          total += value;
        }
      });
      
      return total > 0;
    } catch (e) {
      _logger.e("❌ Erro ao verificar dados locais", error: e);
      return false;
    }
  }

  /// Sincroniza apenas dados essenciais (produtos e clientes)
  Future<SyncResult> sincronizarDadosEssenciais({SyncConfig? config}) async {
    final startTime = DateTime.now();
    final syncConfig = config ?? const SyncConfig();
    
    await _ensureRepositories();
    
    _logger.i("🚀 Sincronizando dados essenciais (produtos e clientes)...");
    
    // Verifica conectividade apenas se não forçada
    if (!syncConfig.forcarSincronizacao) {
      final internetResult = await verificarConexaoInternet();
      if (!internetResult.isSuccess || !internetResult.data!) {
        return SyncResult.error("Sem conexão com a internet", startTime);
      }
    }
    
    try {
      final results = await Future.wait([
        sincronizarProdutos(config: syncConfig),
        sincronizarClientes(config: syncConfig),
      ]);
      
      final produtosResult = results[0];
      final clientesResult = results[1];
      
      if (!produtosResult.isSuccess || !clientesResult.isSuccess) {
        final errors = <String>[];
        if (!produtosResult.isSuccess) errors.add("Produtos: ${produtosResult.errorMessage}");
        if (!clientesResult.isSuccess) errors.add("Clientes: ${clientesResult.errorMessage}");
        return SyncResult.error("Falha na sincronização essencial: ${errors.join('; ')}", startTime);
      }
      
      final counts = <String, int>{
        'Produtos': produtosResult.data ?? 0,
        'Clientes': clientesResult.data ?? 0,
      };
      
      _ultimaSincronizacao = DateTime.now();
      
      _logger.i("✅ Sincronização essencial concluída!");
      _logger.i("📊 Total: ${counts.values.fold(0, (a, b) => a + b)} registros essenciais");
      
      return SyncResult.success(counts, startTime);
    } catch (e, stackTrace) {
      _logger.e("💥 Erro na sincronização essencial", error: e, stackTrace: stackTrace);
      return SyncResult.error("Falha na sincronização essencial: $e", startTime);
    }
  }

  /// Configuração do serviço
  void configurar({
    String? novoCodigoVendedor,
    DateTime? novaDataCorte,
  }) {
    if (novaDataCorte != null) {
      _vendasService.configurarDataCorte(novaDataCorte);
    }
    
    _logger.i("⚙️ Configuração atualizada");
  }
}