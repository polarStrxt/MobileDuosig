// lib/services/produto_service.dart
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Certifique-se que este caminho está correto
import 'package:logger/logger.dart';
// Se ApiClient não importar 'package:http/http.dart' as http, adicione se precisar de tipos como http.Response aqui.

class ProdutoService {
  final ApiClient _apiClient;
  final Logger _logger = Logger(); // Instância do Logger para este serviço

  // Constantes para endpoints
  static const String _endpointBaseProduto = '/v1/produto';

  ProdutoService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            ApiClient(
              // ATENÇÃO: Verifique estes valores, especialmente dataReferencia
              baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
              empresaId: '001',
              dataReferencia: '31.01.1980', // <<--- SUSPEITO PRINCIPAL!
            );

  /// Retorna o endpoint padrão para buscar todos os produtos
  String get _endpointPadraoTodosProdutos {
    // Considere se a data de referência é realmente necessária para buscar TODOS os produtos.
    // Se não for, o endpoint poderia ser apenas: '$_endpointBaseProduto/${_apiClient.empresaId}'
    return '$_endpointBaseProduto/${_apiClient.empresaId}/${_apiClient.dataReferencia}';
  }

  /// Busca todos os produtos disponíveis da API
  Future<ApiResult<List<ProdutoModel>>> buscarProdutos() async {
    _logger.i("ProdutoService: Iniciando buscarProdutos(). Endpoint: $_endpointPadraoTodosProdutos");
    try {
      // A chamada _apiClient.get já deve logar statusCode e body através de _logResponse.
      // O 'response' aqui já é um ApiResult<dynamic> se fromJson não foi passado para o ApiClient.get.
      final ApiResult<dynamic> response = await _apiClient.get(_endpointPadraoTodosProdutos);

      if (!response.isSuccess) {
        _logger.e("ProdutoService: Falha na chamada da API. Status: ${response.statusCode}, Erro: ${response.errorMessage}");
        return ApiResult.error(response.errorMessage ?? "Erro desconhecido ao buscar produtos", statusCode: response.statusCode);
      }
      
      final dynamic jsonData = response.data; // Este é o corpo da resposta já decodificado pelo ApiClient
      
      _logger.d("ProdutoService: jsonData recebido do ApiClient.get: $jsonData");
      _logger.d("ProdutoService: Tipo do jsonData: ${jsonData.runtimeType}");

      if (jsonData == null) {
          _logger.w("ProdutoService: jsonData é nulo após chamada bem-sucedida à API.");
          return ApiResult.error("Resposta da API nula ou inesperada (jsonData é null)", statusCode: response.statusCode);
      }

      List<dynamic> listaDeItensJson;

      // Verifica se o jsonData é uma lista diretamente
      if (jsonData is List) {
        listaDeItensJson = jsonData;
        _logger.i("ProdutoService: jsonData é uma lista com ${listaDeItensJson.length} elementos.");
      } 
      // Se não for uma lista, verifica se é um mapa e tenta encontrar a lista dentro de chaves comuns
      else if (jsonData is Map<String, dynamic>) {
        _logger.i("ProdutoService: jsonData é um Map. Procurando lista de produtos dentro dele...");
        if (jsonData.containsKey('produtos') && jsonData['produtos'] is List) {
          listaDeItensJson = jsonData['produtos'];
          _logger.i("ProdutoService: Encontrada lista na chave 'produtos' com ${listaDeItensJson.length} elementos.");
        } else if (jsonData.containsKey('data') && jsonData['data'] is List) {
          listaDeItensJson = jsonData['data'];
          _logger.i("ProdutoService: Encontrada lista na chave 'data' com ${listaDeItensJson.length} elementos.");
        } else if (jsonData.containsKey('items') && jsonData['items'] is List) {
          listaDeItensJson = jsonData['items'];
           _logger.i("ProdutoService: Encontrada lista na chave 'items' com ${listaDeItensJson.length} elementos.");
        } 
        // ADICIONE MAIS 'ELSE IF' AQUI PARA OUTRAS CHAVES POSSÍVEIS QUE SUA API PODE USAR
        else {
          _logger.e("ProdutoService: jsonData é um Map, mas não contém uma chave esperada ('produtos', 'data', 'items') com a lista de produtos. Conteúdo: $jsonData");
          return ApiResult.error("Formato de resposta JSON não reconhecido (Map sem lista de produtos)", statusCode: response.statusCode);
        }
      } 
      // Se não for nem Lista nem Mapa
      else {
        _logger.e("ProdutoService: Formato de resposta inválido. Esperava List ou Map, recebeu ${jsonData.runtimeType}. Conteúdo: $jsonData");
        return ApiResult.error("Formato de resposta inválido: esperada lista ou objeto de produtos, mas recebeu ${jsonData.runtimeType}", statusCode: response.statusCode);
      }
      
      if (listaDeItensJson.isEmpty) {
          _logger.i("ProdutoService: A lista de itens JSON para produtos está vazia.");
      }

      // Tenta converter a lista de JSON para Lista de ProdutoModel
      try {
        final produtos = listaDeItensJson
            .map((item) => ProdutoModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _logger.i("ProdutoService: ${produtos.length} produtos convertidos com sucesso para ProdutoModel.");
        return ApiResult.success(produtos); // Usa o construtor nomeado correto
      } catch (e, s) {
        _logger.e("ProdutoService: Erro CRÍTICO ao converter JSON dos produtos para ProdutoModel. Verifique o método ProdutoModel.fromJson e a estrutura do JSON do item.", error: e, stackTrace: s);
        _logger.d("ProdutoService: Primeiro item da listaDeItensJson (se não vazia): ${listaDeItensJson.isNotEmpty ? listaDeItensJson.first : 'Lista vazia'}");
        return ApiResult.error("Erro ao processar os dados dos produtos recebidos: $e", statusCode: response.statusCode);
      }

    } catch (e, s) { // Captura geral para o método buscarProdutos
      _logger.e("ProdutoService: Erro inesperado em buscarProdutos()", error: e, stackTrace: s);
      return ApiResult.error("Erro ao processar busca de produtos: $e");
    }
  }

  /// Busca um produto específico pelo código
  Future<ApiResult<ProdutoModel?>> buscarProdutoPorCodigo(String codigo) async {
    // Monta o endpoint específico para buscar por código
    final String endpointProdutoEspecifico = '${_endpointPadraoTodosProdutos}/$codigo';
    _logger.i("ProdutoService: Buscando produto por código. Endpoint: $endpointProdutoEspecifico");
    
    // O ApiClient.get<T> espera um T Function(dynamic json) fromJson.
    // Para ProdutoModel?, o T é ProdutoModel?.
    final result = await _apiClient.get<ProdutoModel?>(
      endpointProdutoEspecifico,
      fromJson: (json) {
        if (json == null) {
          _logger.w("ProdutoService: buscarProdutoPorCodigo - JSON nulo recebido para código $codigo.");
          return null; 
        }
        if (json is Map<String, dynamic>) { // Verifica se é um mapa antes de converter
          try {
            return ProdutoModel.fromJson(json);
          } catch(e,s) {
            _logger.e("ProdutoService: buscarProdutoPorCodigo - Erro ao converter JSON para ProdutoModel para código $codigo.", error: e, stackTrace: s);
            _logger.d("JSON com erro: $json");
            return null; // Ou lançar um erro específico
          }
        } else {
           _logger.w("ProdutoService: buscarProdutoPorCodigo - JSON recebido não é um Map para código $codigo. JSON: $json");
           return null;
        }
      },
    );

    if(result.isSuccess && result.data != null){
        _logger.i("ProdutoService: Produto com código $codigo encontrado.");
    } else if (result.isSuccess && result.data == null) {
        _logger.w("ProdutoService: Produto com código $codigo não encontrado (API retornou sucesso mas data nula).");
    } else {
        _logger.e("ProdutoService: Falha ao buscar produto por código $codigo. Erro: ${result.errorMessage}");
    }
    return result;
  }

  /// Busca produtos que contenham o termo especificado na descrição
  Future<ApiResult<List<ProdutoModel>>> buscarProdutosPorDescricao(String termo) async {
    final termoCodificado = Uri.encodeComponent(termo);
    final String endpointBusca = '${_endpointPadraoTodosProdutos}/busca/$termoCodificado';
    _logger.i("ProdutoService: Buscando produto por descrição. Endpoint: $endpointBusca");

    final result = await _apiClient.get<List<ProdutoModel>>(
      endpointBusca,
      fromJson: (json) {
        if (json is List) {
          try {
            final produtos = json.map((item) => ProdutoModel.fromJson(item as Map<String, dynamic>)).toList();
            _logger.i("ProdutoService: ${produtos.length} produtos encontrados por descrição para o termo '$termo'.");
            return produtos;
          } catch (e,s) {
            _logger.e("ProdutoService: buscarProdutosPorDescricao - Erro ao converter JSON para List<ProdutoModel> para termo '$termo'.", error: e, stackTrace: s);
            _logger.d("JSON com erro: $json");
            return <ProdutoModel>[]; // Retorna lista vazia em caso de erro de parsing
          }
        }
        _logger.w("ProdutoService: buscarProdutosPorDescricao - Resposta da API não é uma lista para termo '$termo'. JSON: $json");
        return <ProdutoModel>[]; // Retorna lista vazia se não for uma lista
      },
    );
    return result;
  }
}