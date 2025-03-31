// Arquivo: lib/home/apiDuplicata.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class DuplicataApi {
  // Configurações da API
  static String baseUrl = "http://duotecsuprilev.ddns.com.br:8082";
  static const String _empresaId = "001";
  static const String _dataBase =
      "31.01.1980"; // Considere usar um valor mais dinâmico

  // Timeout para requisições
  static const Duration _timeout = Duration(seconds: 15);

  // Cliente HTTP reutilizável para melhor performance
  static final http.Client _client = http.Client();

  // Habilitar ou desabilitar logs
  static bool enableLogs = true;

  // Método auxiliar para logs
  static void _log(String message) {
    if (enableLogs && kDebugMode) {
      print(message);
    }
  }

  /// Método auxiliar para fazer requisições HTTP com tratamento de erros padronizado
  static Future<Map<String, dynamic>> _getRequest(Uri url) async {
    try {
      _log("🔍 Requisição GET: $url");

      final response = await _client.get(
        url,
        headers: {
          "Content-Type": "application/json",
        },
      ).timeout(_timeout);

      _log("📡 Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
          'statusCode': response.statusCode
        };
      } else {
        return {
          'success': false,
          'message': 'Erro HTTP ${response.statusCode}',
          'statusCode': response.statusCode,
          'body': response.body
        };
      }
    } catch (e) {
      _log("❌ Exceção na requisição: $e");
      return {
        'success': false,
        'message': e.toString(),
        'statusCode': 0,
      };
    }
  }

  /// Método para criar duplicatas de exemplo para testes
  static List<Duplicata> _criarDuplicatasExemplo(int codcli) {
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

  /// Busca duplicatas por código do cliente
  static Future<List<Duplicata>> buscarDuplicatasPorCliente(int codcli,
      {bool usarDadosExemplo = false}) async {
    // URL para buscar duplicatas
    final url = Uri.parse("$baseUrl/v1/financeiro/$_empresaId/$_dataBase");

    // Se estiver no modo de dados de exemplo, retorna dados simulados
    if (usarDadosExemplo) {
      return _criarDuplicatasExemplo(codcli);
    }

    // Fazer a requisição utilizando o método auxiliar
    final response = await _getRequest(url);

    if (response['success']) {
      final List<dynamic> jsonResponse = response['data'];

      // Converter e filtrar apenas duplicatas do cliente específico
      final duplicatas = jsonResponse
          .map((item) => Duplicata.fromJson(item))
          .where((duplicata) => duplicata.codcli == codcli)
          .toList();

      _log(
          "📊 Total de duplicatas encontradas para o cliente $codcli: ${duplicatas.length}");

      // Se não encontrou nenhuma duplicata, pode retornar dados de exemplo
      if (duplicatas.isEmpty && usarDadosExemplo) {
        return _criarDuplicatasExemplo(codcli);
      }

      return duplicatas;
    } else {
      _log("❌ Erro ao buscar duplicatas: ${response['message']}");

      // Se falhou com 404, retorna dados de exemplo se habilitado
      if (response['statusCode'] == 404 && usarDadosExemplo) {
        return _criarDuplicatasExemplo(codcli);
      }

      return [];
    }
  }

  /// Busca uma única duplicata por ID
  static Future<Duplicata?> buscarDuplicataPorId(String numdoc) async {
    final url = Uri.parse("$baseUrl/v1/duplicata/$numdoc");

    final response = await _getRequest(url);

    if (response['success']) {
      final Map<String, dynamic> jsonResponse = response['data'];
      return Duplicata.fromJson(jsonResponse);
    } else {
      _log("❌ Erro ao buscar duplicata $numdoc: ${response['message']}");
      return null;
    }
  }

  /// Busca todas as duplicatas
  static Future<List<Duplicata>> buscarDuplicatas(
      {bool usarDadosExemplo = false}) async {
    final url = Uri.parse("$baseUrl/v1/financeiro/$_empresaId/$_dataBase");

    // Fazer a requisição utilizando o método auxiliar
    final response = await _getRequest(url);

    if (response['success']) {
      final List<dynamic> jsonResponse = response['data'];

      // Converter os dados para a lista de Duplicatas
      final duplicatas =
          jsonResponse.map((item) => Duplicata.fromJson(item)).toList();

      _log("📊 Total de duplicatas encontradas: ${duplicatas.length}");
      return duplicatas;
    } else {
      _log("❌ Erro ao buscar duplicatas: ${response['message']}");

      // Se habilitado, retorna alguns dados de exemplo
      if (usarDadosExemplo) {
        return [
          ..._criarDuplicatasExemplo(1001),
          ..._criarDuplicatasExemplo(1002),
          ..._criarDuplicatasExemplo(1003),
        ];
      }

      return [];
    }
  }

  /// Fecha o cliente HTTP quando não for mais necessário
  static void dispose() {
    _client.close();
  }
}
