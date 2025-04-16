import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Referência à classe que criamos anteriormente

/// Serviço responsável por gerir operações relacionadas a clientes
class ClienteService {
  final ApiClient _apiClient;

  /// Constantes para endpoints
  static const String _endpointBaseCliente = 'cliente';

  /// Construtor que aceita um cliente API customizado ou cria um padrão
  ClienteService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            ApiClient(
              baseUrl: 'http://duotectecnologia.com.br:8082/v1/',
              empresaId: '001',
              dataReferencia: '31.01.1980',
            );

  /// Retorna o endpoint com os parâmetros padrão
  String get _endpointPadrao =>
      '$_endpointBaseCliente/${_apiClient.empresaId}/${_apiClient.dataReferencia}';

  /// Busca um cliente específico pelo ID e data de nascimento
  ///
  /// [id] O código único do cliente
  /// [dataNascimento] A data de nascimento do cliente no formato DD.MM.AAAA
  /// Retorna um [ApiResult] contendo o cliente ou um erro
  Future<ApiResult<Cliente?>> buscarCliente(String id, String dataNascimento) async {
    final result = await _apiClient.get<Cliente?>(
      '$_endpointPadrao/$id/$dataNascimento',
      fromJson: (json) => json != null ? Cliente.fromJson(json) : null,
    );

    return result;
  }

  /// Busca todos os clientes disponíveis
  ///
  /// Retorna um [ApiResult] contendo a lista de clientes ou um erro
  Future<ApiResult<List<Cliente>>> buscarClientes() async {
    final result = await _apiClient.get<List<Cliente>>(
      _endpointPadrao,
      fromJson: (json) {
        if (json is List) {
          return json.map((item) => Cliente.fromJson(item)).toList();
        }
        return <Cliente>[];
      },
    );

    return result;
  }
}