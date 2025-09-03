import 'dart:math' as math;
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_produto_model.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';
import 'package:flutter_docig_venda/data/models/condicao_pagamento_model.dart';
import 'package:flutter_docig_venda/data/models/registrar_pedido_local.dart';
import 'package:logger/logger.dart';

/// Serviço de vendas otimizado e compatível com nova API
class VendasService {
  final UnifiedApiClient apiClient;
  final Logger _logger = Logger();
  
  // Data de corte padrão (pode ser configurada)
  final String _dataCorte = '31.01.1980';

  VendasService({required this.apiClient});

  /// Obtém o código do vendedor configurado
  String get codigoVendedor => apiClient.codigoVendedor;

  /// Formata data para o padrão da API (DD.MM.AAAA)
  String _formatarData(DateTime? data) {
    if (data == null) return _dataCorte;
    
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    
    return '$dia.$mes.$ano';
  }

  // ===== PRODUTOS - CORRIGIDO =====
  
  /// Busca todos os produtos - ENDPOINT CORRIGIDO
  /// O endpoint correto parece ser: /v1/produto/{codigoVendedor}/{dataCorte}
  Future<ApiResult<List<ProdutoModel>>> buscarProdutos({
    bool useCache = true,
    DateTime? dataCorte,
  }) async {
    final dataFormatada = _formatarData(dataCorte);
    _logger.i("Buscando produtos para vendedor: $codigoVendedor com data: $dataFormatada");
    
    return await apiClient.get<List<ProdutoModel>>(
      '/v1/produto/$codigoVendedor/$dataFormatada',  // ENDPOINT CORRIGIDO
      fromJson: (json) => _parseListWithLogging(json, ProdutoModel.fromJson, 'produtos'),
      useCache: useCache,
    );
  }

  /// Busca produto específico por código - ENDPOINT ALTERNATIVO
  /// Primeiro tenta buscar produto específico, se não funcionar usa busca geral
  Future<ApiResult<ProdutoModel?>> buscarProdutoPorCodigo(
    int codigo, {
    bool useCache = true,
  }) async {
    _logger.i("Buscando produto: $codigo para vendedor: $codigoVendedor");
    
    // Tenta endpoint específico primeiro
    try {
      final resultEspecifico = await apiClient.get<ProdutoModel?>(
        '/v1/produto/$codigoVendedor/$codigo',
        fromJson: (json) {
          if (json == null || (json is Map && json.isEmpty)) {
            _logger.w("Produto $codigo não encontrado no endpoint específico");
            return null;
          }
          return ProdutoModel.fromJson(json as Map<String, dynamic>);
        },
        useCache: useCache,
      );
      
      if (resultEspecifico.isSuccess && resultEspecifico.data != null) {
        return resultEspecifico;
      }
    } catch (e) {
      _logger.w("Endpoint específico falhou para produto $codigo: $e");
    }
    
    // Se endpoint específico falhou, busca todos os produtos e filtra
    _logger.i("Buscando produto $codigo via busca geral");
    final todosProdutosResult = await buscarProdutos(useCache: useCache);
    
    if (!todosProdutosResult.isSuccess) {
      return ApiResult.error("Erro ao buscar produto: ${todosProdutosResult.errorMessage}");
    }
    
    final produto = todosProdutosResult.data!
        .where((p) => p.codprd == codigo)
        .firstOrNull;
    
    if (produto == null) {
      return ApiResult.error("Produto $codigo não encontrado");
    }
    
    return ApiResult.success(produto);
  }

  /// NOVO: Método para testar conectividade da API de produtos
  Future<ApiResult<bool>> testarConectividadeProdutos() async {
    _logger.i("Testando conectividade da API de produtos");
    
    try {
      // Faz uma requisição simples para testar se a API responde
      final response = await apiClient.get(
        '/v1/produto/$codigoVendedor/$_dataCorte',
        useCache: false,
        customTimeout: const Duration(seconds: 15),
        maxRetries: 2,
      );
      
      if (response.isSuccess) {
        _logger.i("API de produtos está respondendo");
        return ApiResult.success(true);
      } else {
        _logger.w("API responde mas com erro: ${response.errorMessage}");
        return ApiResult.success(false);
      }
    } catch (e) {
      _logger.e("Erro ao testar conectividade", error: e);
      return ApiResult.error("Falha na conectividade: $e");
    }
  }

  /// NOVO: Método para obter informações de debug da API
  Future<Map<String, dynamic>> obterInfoDebugProdutos() async {
    final info = {
      'endpoint': '/v1/produto/$codigoVendedor/$_dataCorte',
      'baseUrl': apiClient.getClientInfo()['baseUrl'],
      'codigoVendedor': codigoVendedor,
      'dataCorte': _dataCorte,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Testa conectividade
    final conectividadeResult = await testarConectividadeProdutos();
    info['conectividade'] = {
      'sucesso': conectividadeResult.isSuccess,
      'resposta': conectividadeResult.data,
      'erro': conectividadeResult.errorMessage,
    };
    
    return info;
  }

  // ===== CLIENTES =====
  
  /// Busca todos os clientes com data de corte
  /// Endpoint: /v1/cliente/{codigoVendedor}/{dataCorte}
  Future<ApiResult<List<Cliente>>> buscarClientes({
    bool useCache = true,
    DateTime? dataCorte,
  }) async {
    final dataFormatada = _formatarData(dataCorte);
    _logger.i("Buscando clientes para vendedor: $codigoVendedor com data: $dataFormatada");
    
    return await apiClient.get<List<Cliente>>(
      '/v1/cliente/$codigoVendedor/$dataFormatada',
      fromJson: (json) => _parseListWithLogging(json, Cliente.fromJson, 'clientes'),
      useCache: useCache,
    );
  }

  /// Busca cliente específico por código
  /// Endpoint: /v1/cliente/{codigoVendedor}/{codigo}
  Future<ApiResult<Cliente?>> buscarClientePorCodigo(
    int codigo, {
    bool useCache = true,
  }) async {
    _logger.i("Buscando cliente: $codigo para vendedor: $codigoVendedor");
    
    return await apiClient.get<Cliente?>(
      '/v1/cliente/$codigoVendedor/$codigo',
      fromJson: (json) {
        if (json == null || (json is Map && json.isEmpty)) {
          _logger.w("Cliente $codigo não encontrado");
          return null;
        }
        return Cliente.fromJson(json as Map<String, dynamic>);
      },
      useCache: useCache,
    );
  }

  // ===== CLIENTE-PRODUTO =====
  
  /// Busca relação cliente-produto
  /// Endpoint: /v1/cliente_produto/{codigoVendedor}
  Future<ApiResult<List<ClienteProdutoModel>>> buscarClienteProdutos({
    bool useCache = true,
  }) async {
    _logger.i("Buscando relação cliente-produto para vendedor: $codigoVendedor");
    
    return await apiClient.get<List<ClienteProdutoModel>>(
      '/v1/cliente_produto/$codigoVendedor',
      fromJson: (json) => _parseListWithLogging(json, ClienteProdutoModel.fromJson, 'cliente-produtos'),
      useCache: useCache,
    );
  }

  /// Busca produtos específicos de um cliente
  /// Esta é uma versão filtrada localmente, pois a API não parece ter endpoint específico por cliente
  Future<ApiResult<List<ClienteProdutoModel>>> buscarProdutosDoCliente(
    String codigoCliente, {
    bool useCache = true,
  }) async {
    _logger.i("Buscando produtos do cliente: $codigoCliente");
    
    // Primeiro busca todos os cliente-produtos
    final todosProdutosResult = await buscarClienteProdutos(useCache: useCache);
    
    if (!todosProdutosResult.isSuccess) {
      return ApiResult.error("Erro ao buscar produtos do cliente: ${todosProdutosResult.errorMessage}");
    }
    
    // Filtra pelos produtos do cliente específico
    final produtosDoCliente = todosProdutosResult.data!
        .where((cp) => cp.codcli.toString() == codigoCliente)
        .toList();
    
    _logger.i("Encontrados ${produtosDoCliente.length} produtos para cliente $codigoCliente");
    return ApiResult.success(produtosDoCliente);
  }

  // ===== CONDIÇÕES DE PAGAMENTO =====
  
  /// Busca condições de pagamento com data de corte
  /// Endpoint: /v1/condicao_pagto/{codigoVendedor}/{dataCorte}
  Future<ApiResult<List<CondicaoPagamentoModel>>> buscarCondicoesPagamento({
    bool useCache = true,
    DateTime? dataCorte,
  }) async {
    final dataFormatada = _formatarData(dataCorte);
    _logger.i("Buscando condições de pagamento para vendedor: $codigoVendedor com data: $dataFormatada");
    
    return await apiClient.get<List<CondicaoPagamentoModel>>(
      '/v1/condicao_pagto/$codigoVendedor/$dataFormatada',
      fromJson: (json) => _parseListWithLogging(json, CondicaoPagamentoModel.fromJson, 'condições de pagamento'),
      useCache: useCache,
    );
  }

  // ===== FINANCEIRO/DUPLICATAS =====
  
  /// Busca duplicatas (financeiro) com data de corte
  /// Endpoint: /v1/financeiro/{codigoVendedor}/{dataCorte}
  Future<ApiResult<List<Duplicata>>> buscarDuplicatas({
    bool useCache = true,
    DateTime? dataCorte,
  }) async {
    final dataFormatada = _formatarData(dataCorte);
    _logger.i("Buscando duplicatas para vendedor: $codigoVendedor com data: $dataFormatada");
    
    return await apiClient.get<List<Duplicata>>(
      '/v1/financeiro/$codigoVendedor/$dataFormatada',
      fromJson: (json) => _parseListWithLogging(json, Duplicata.fromJson, 'duplicatas'),
      useCache: useCache,
    );
  }

  /// Busca duplicatas de um cliente específico
  /// Esta versão filtra as duplicatas por cliente após buscar todas
  Future<ApiResult<List<Duplicata>>> buscarDuplicatasCliente(
    int codigoCliente, {
    bool useCache = true,
    DateTime? dataCorte,
  }) async {
    _logger.i("Buscando duplicatas do cliente: $codigoCliente");
    
    // Busca todas as duplicatas
    final todasDuplicatasResult = await buscarDuplicatas(
      useCache: useCache,
      dataCorte: dataCorte,
    );
    
    if (!todasDuplicatasResult.isSuccess) {
      return ApiResult.error("Erro ao buscar duplicatas: ${todasDuplicatasResult.errorMessage}");
    }
    
    // Filtra pelas duplicatas do cliente específico
    final duplicatasDoCliente = todasDuplicatasResult.data!
        .where((d) => d.codcli == codigoCliente)
        .toList();
    
    _logger.i("Encontradas ${duplicatasDoCliente.length} duplicatas para cliente $codigoCliente");
    return ApiResult.success(duplicatasDoCliente);
  }

  // ===== PEDIDOS (se necessário) =====
  
  /// Cria um pedido (exemplo)
  /// Endpoint seria algo como: /v1/pedido/{codigoVendedor}
  Future<ApiResult<Map<String, dynamic>>> criarPedido(Map<String, dynamic> dadosPedido) async {
    _logger.i("Criando pedido para vendedor: $codigoVendedor");
    
    return await apiClient.post<Map<String, dynamic>>(
      '/v1/pedido/$codigoVendedor',
      body: dadosPedido,
      fromJson: (json) => json as Map<String, dynamic>,
    );
  }

  // ===== MÉTODOS AUXILIARES - MELHORADOS =====
  
  /// Helper otimizado para parsear listas com logging detalhado e tratamento robusto
  List<T> _parseListWithLogging<T>(
    dynamic json, 
    T Function(Map<String, dynamic>) fromJson, 
    String tipoItem,
  ) {
    try {
      _logger.d("Parsing JSON para $tipoItem: ${json.runtimeType}");
      
      if (json is List) {
        _logger.d("JSON é lista direta com ${json.length} itens");
        final resultado = <T>[];
        
        for (int i = 0; i < json.length; i++) {
          try {
            final item = json[i];
            if (item is Map<String, dynamic>) {
              resultado.add(fromJson(item));
            } else {
              _logger.w("Item $i em $tipoItem não é um Map válido: ${item.runtimeType}");
            }
          } catch (e) {
            _logger.e("Erro ao parsear item $i de $tipoItem", error: e);
          }
        }
        
        _logger.i("Parseados ${resultado.length}/${json.length} itens de $tipoItem");
        return resultado;
        
      } else if (json is Map<String, dynamic>) {
        _logger.d("JSON é objeto Map, procurando lista dentro");
        
        // Tenta diferentes chaves comuns para encontrar a lista
        final possibleKeys = [
          'data', 'items', 'results', 'content', 'response',
          'list', 'array', tipoItem.toLowerCase(),
          // Chaves específicas para seu domínio
          'produtos', 'clientes', 'duplicatas', 'condicoes'
        ];
        
        for (final key in possibleKeys) {
          if (json.containsKey(key)) {
            final value = json[key];
            if (value is List) {
              _logger.d("Encontrada lista na chave '$key' com ${value.length} itens");
              return _parseListWithLogging(value, fromJson, tipoItem);
            }
          }
        }
        
        // Se não encontrou uma lista, talvez seja um objeto único
        _logger.d("Não encontrou lista no Map, tratando como objeto único");
        try {
          return [fromJson(json)];
        } catch (e) {
          _logger.e("Erro ao parsear objeto único de $tipoItem", error: e);
          return [];
        }
        
      } else if (json == null) {
        _logger.w("JSON é null para $tipoItem");
        return [];
        
      } else {
        _logger.w("Formato de JSON não reconhecido para $tipoItem: ${json.runtimeType}");
        _logger.d("Conteúdo: ${json.toString().substring(0, math.min(200, json.toString().length))}");
        return [];
      }
      
    } catch (e, stackTrace) {
      _logger.e("Erro crítico ao parsear $tipoItem", error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Validação de conectividade específica para vendas - MELHORADA
  Future<ApiResult<bool>> verificarConectividadeVendas() async {
    _logger.i("Verificando conectividade com API de vendas");
    
    try {
      // Primeiro testa endpoint mais leve (clientes)
      final clienteResponse = await apiClient.get(
        '/v1/cliente/$codigoVendedor/$_dataCorte',
        useCache: false,
        customTimeout: const Duration(seconds: 10),
        maxRetries: 1,
      );
      
      if (clienteResponse.isSuccess) {
        _logger.i("Conectividade confirmada via endpoint de clientes");
        return ApiResult.success(true);
      }
      
      // Se clientes falhou, testa produtos
      final produtoResponse = await testarConectividadeProdutos();
      if (produtoResponse.isSuccess && produtoResponse.data == true) {
        _logger.i("Conectividade confirmada via endpoint de produtos");
        return ApiResult.success(true);
      }
      
      _logger.w("Ambos endpoints falharam");
      return ApiResult.success(false);
      
    } catch (e) {
      _logger.e("Erro na verificação de conectividade", error: e);
      return ApiResult.error("Falha na conectividade: $e");
    }
  }

  /// Limpa cache específico do serviço
  void limparCache() {
    apiClient.clearCache();
    _logger.i("Cache do VendasService limpo");
  }

  /// Obtém estatísticas do serviço - MELHORADAS
  Map<String, dynamic> obterEstatisticas() {
    return {
      'codigoVendedor': codigoVendedor,
      'dataCorte': _dataCorte,
      'endpoints': {
        'produtos': '/v1/produto/$codigoVendedor/$_dataCorte',
        'clientes': '/v1/cliente/$codigoVendedor/$_dataCorte',
        'condicoesPagamento': '/v1/condicao_pagto/$codigoVendedor/$_dataCorte',
        'duplicatas': '/v1/financeiro/$codigoVendedor/$_dataCorte',
        'clienteProdutos': '/v1/cliente_produto/$codigoVendedor',
      },
      'clientInfo': apiClient.getClientInfo(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Sincronização em lote otimizada - COM DIAGNÓSTICOS
  Future<Map<String, ApiResult<dynamic>>> sincronizarTudo({
    DateTime? dataCorte,
    bool useCache = false,
  }) async {
    _logger.i("Iniciando sincronização completa");
    
    // Primeiro verifica conectividade
    final conectividadeResult = await verificarConectividadeVendas();
    if (!conectividadeResult.isSuccess || !conectividadeResult.data!) {
      _logger.w("Conectividade falhou: ${conectividadeResult.errorMessage}");
      return {
        'conectividade': conectividadeResult,
        'produtos': ApiResult.error("Sem conectividade"),
        'clientes': ApiResult.error("Sem conectividade"),
        'condicoesPagamento': ApiResult.error("Sem conectividade"),
        'clienteProdutos': ApiResult.error("Sem conectividade"),
        'duplicatas': ApiResult.error("Sem conectividade"),
      };
    }
    
    // Log dos endpoints que serão chamados
    final stats = obterEstatisticas();
    _logger.i("Endpoints a serem chamados:");
    (stats['endpoints'] as Map).forEach((key, value) {
      _logger.i("  $key: $value");
    });
    
    // Executa todas as chamadas em paralelo para máxima eficiência
    final futures = await Future.wait([
      buscarProdutos(useCache: useCache, dataCorte: dataCorte),
      buscarClientes(useCache: useCache, dataCorte: dataCorte),
      buscarCondicoesPagamento(useCache: useCache, dataCorte: dataCorte),
      buscarClienteProdutos(useCache: useCache),
      buscarDuplicatas(useCache: useCache, dataCorte: dataCorte),
    ]);
    
    final resultados = <String, ApiResult<dynamic>>{
      'produtos': futures[0],
      'clientes': futures[1],
      'condicoesPagamento': futures[2],
      'clienteProdutos': futures[3],
      'duplicatas': futures[4],
    };
    
    // Log detalhado dos resultados
    final sucessos = resultados.values.where((r) => r.isSuccess).length;
    final falhas = resultados.length - sucessos;
    
    _logger.i("Sincronização completa: $sucessos sucessos, $falhas falhas");
    
    resultados.forEach((key, result) {
      if (result.isSuccess) {
        final count = result.data is List ? result.data!.length : 'N/A';
        _logger.i("  ✅ $key: $count itens");
      } else {
        _logger.e("  ❌ $key: ${result.errorMessage}");
      }
    });
    
    return resultados;
  }

  /// Configuração de data de corte personalizada
  void configurarDataCorte(DateTime novaData) {
    final dataFormatada = _formatarData(novaData);
    _logger.i("Data de corte configurada para: $dataFormatada");
    // Aqui você poderia armazenar em um campo da classe se necessário
  }
}