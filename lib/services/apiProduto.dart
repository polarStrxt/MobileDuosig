import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Referência à classe que criamos anteriormente

/// Serviço responsável por gerir operações relacionadas a produtos
class ProdutoService {
  final ApiClient _apiClient;

  /// Constantes para endpoints
  static const String _endpointBaseProduto = '/v1/produto';

  /// Construtor que aceita um cliente API customizado ou cria um padrão
  ProdutoService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            ApiClient(
              baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
              empresaId: '001',
              dataReferencia: '31.01.1980',
            );

  /// Retorna o endpoint com os parâmetros padrão
  String get _endpointPadrao =>
      '$_endpointBaseProduto/${_apiClient.empresaId}/${_apiClient.dataReferencia}';

  /// Busca todos os produtos disponíveis
///
/// Retorna um [ApiResult] contendo a lista de produtos ou um erro
Future<ApiResult<List<Produto>>> buscarProdutos() async {
  try {
    final response = await _apiClient.get(
      _endpointPadrao,
    );

    if (!response.isSuccess) {
      return ApiResult.error(response.errorMessage);
    }
    
    // Garantir que estamos lidando com uma lista
    final dynamic jsonData = response.data;
    if (jsonData is! List) {
      return ApiResult.error("Formato de resposta inválido: esperada lista de produtos");
    }
    
    // Converter manualmente para garantir o tipo correto
    final produtos = jsonData.map((item) => Produto.fromJson(item)).toList();
    return ApiResult<List<Produto>>.success(produtos);
  } catch (e) {
    return ApiResult.error("Erro ao processar produtos: $e");
  }
}

  /// Busca um produto específico pelo código
  ///
  /// [codigo] O código único do produto
  /// Retorna um [ApiResult] contendo o produto ou um erro
  Future<ApiResult<Produto?>> buscarProdutoPorCodigo(String codigo) async {
    final result = await _apiClient.get<Produto?>(
      '$_endpointPadrao/$codigo',
      fromJson: (json) => json != null ? Produto.fromJson(json) : null,
    );

    return result;
  }

  /// Busca produtos que contenham o termo especificado na descrição
  ///
  /// [termo] Termo a ser pesquisado nas descrições dos produtos
  /// Retorna um [ApiResult] contendo a lista de produtos encontrados ou um erro
  Future<ApiResult<List<Produto>>> buscarProdutosPorDescricao(String termo) async {
    final termoCodificado = Uri.encodeComponent(termo);
    
    final result = await _apiClient.get<List<Produto>>(
      '$_endpointPadrao/busca/$termoCodificado',
      fromJson: (json) {
        if (json is List) {
          return json.map((item) => Produto.fromJson(item)).toList();
        }
        return <Produto>[];
      },
    );

    return result;
  }
}
