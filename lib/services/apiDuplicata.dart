import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Serviço responsável pelas operações relacionadas a duplicatas
class DuplicataService {
  final ApiClient _apiClient;
  final bool usarDadosExemplo;

  /// Constantes para endpoints
  static const String _endpointBaseFinanceiro = '/v1/financeiro';
  static const String _endpointBaseDuplicata = '/v1/duplicata';

  /// Construtor que aceita um cliente API customizado ou cria um padrão
  DuplicataService({
    ApiClient? apiClient,
    this.usarDadosExemplo = false,
  }) : _apiClient = apiClient ??
            ApiClient(
              baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
              empresaId: '001',
              dataReferencia: '31.01.1980',
              timeout: const Duration(seconds: 15),
            );

  /// Retorna o endpoint financeiro com os parâmetros padrão
  String get _endpointFinanceiro =>
      '$_endpointBaseFinanceiro/${_apiClient.empresaId}/${_apiClient.dataReferencia}';

  /// Método para criar duplicatas de exemplo para testes
  List<Duplicata> _criarDuplicatasExemplo(int codcli) {
    _log("⚠️ Criando duplicatas de exemplo para cliente $codcli");
    return [
      Duplicata(
        numdoc: "TESTE001",
        codcli: codcli,
        dtavct: DateTime.now().add(Duration(days: 10)).toString(),
        vlrdpl: 1500.0,
      ),
      Duplicata(
        numdoc: "TESTE002",
        codcli: codcli,
        dtavct: DateTime.now().add(Duration(days: -5)).toString(),
        vlrdpl: 750.0,
      ),
      Duplicata(
        numdoc: "TESTE003",
        codcli: codcli,
        dtavct: DateTime.now().add(Duration(days: -15)).toString(),
        vlrdpl: 1200.0,
      ),
    ];
  }

  /// Método auxiliar para logs
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  /// Busca duplicatas por código do cliente
  Future<ApiResult<List<Duplicata>>> buscarDuplicatasPorCliente(int codcli) async {
    // Se estiver no modo de dados de exemplo, retorna dados simulados
    if (usarDadosExemplo) {
      return ApiResult.success(_criarDuplicatasExemplo(codcli));
    }

    // Fazer a requisição utilizando o ApiClient
    final result = await _apiClient.get<List<dynamic>>(
      _endpointFinanceiro,
      fromJson: (jsonResponse) {
        if (jsonResponse is List) {
          // Converter e filtrar apenas duplicatas do cliente específico
          final duplicatas = jsonResponse
              .map((item) => Duplicata.fromJson(item))
              .where((duplicata) => duplicata.codcli == codcli)
              .toList();

          _log("📊 Total de duplicatas encontradas para o cliente $codcli: ${duplicatas.length}");

          // Se não encontrou nenhuma duplicata e está habilitado para usar dados de exemplo
          if (duplicatas.isEmpty && usarDadosExemplo) {
            return _criarDuplicatasExemplo(codcli);
          }

          return duplicatas;
        }
        return <Duplicata>[];
      },
    );

    // Se houve erro e estamos permitindo usar dados de exemplo, retornamos o fallback
    if (!result.isSuccess && usarDadosExemplo) {
      return ApiResult.success(_criarDuplicatasExemplo(codcli));
    }

    return result as ApiResult<List<Duplicata>>;
  }

  /// Busca uma única duplicata por ID
  Future<ApiResult<Duplicata?>> buscarDuplicataPorId(String numdoc) async {
    final result = await _apiClient.get<Duplicata?>(
      '$_endpointBaseDuplicata/$numdoc',
      fromJson: (json) => json != null ? Duplicata.fromJson(json) : null,
    );

    return result;
  }

  /// Busca todas as duplicatas
  Future<ApiResult<List<Duplicata>>> buscarDuplicatas() async {
    // Fazer a requisição utilizando o ApiClient
    final result = await _apiClient.get<List<Duplicata>>(
      _endpointFinanceiro,
      fromJson: (jsonResponse) {
        if (jsonResponse is List) {
          // Converter os dados para a lista de Duplicatas
          final duplicatas = jsonResponse
              .map((item) => Duplicata.fromJson(item))
              .toList();

          _log("📊 Total de duplicatas encontradas: ${duplicatas.length}");
          return duplicatas;
        }
        
        // Se habilitado para usar dados de exemplo e a resposta não é uma lista
        if (usarDadosExemplo) {
          return [
            ..._criarDuplicatasExemplo(1001),
            ..._criarDuplicatasExemplo(1002),
            ..._criarDuplicatasExemplo(1003),
          ];
        }
        
        return <Duplicata>[];
      },
    );

    // Se houve erro e estamos permitindo usar dados de exemplo, retornamos o fallback
    if (!result.isSuccess && usarDadosExemplo) {
      return ApiResult.success([
        ..._criarDuplicatasExemplo(1001),
        ..._criarDuplicatasExemplo(1002),
        ..._criarDuplicatasExemplo(1003),
      ]);
    }

    return result as ApiResult<List<Duplicata>>;
  }
}
