import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Resultado da API que encapsula sucesso ou erro de forma padronizada
class ApiResult<T> {
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final bool isSuccess;

  ApiResult.success(this.data)
      : isSuccess = true,
        errorMessage = null,
        statusCode = 200;

  ApiResult.error(this.errorMessage, {this.statusCode})
      : isSuccess = false,
        data = null;

  /// Verifica se o resultado contém dados (não nulos)
  bool get hasData => data != null;
}

/// Cliente HTTP base que gerencia as requisições
class ApiClient {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> defaultHeaders;
  final String empresaId;
  final String dataReferencia;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.defaultHeaders = const {"Content-Type": "application/json"},
    required this.empresaId,
    required this.dataReferencia,
  });

  /// Realiza uma requisição GET e retorna um resultado padronizado
  Future<ApiResult<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParameters,
      );

      final requestHeaders = {...defaultHeaders, ...?headers};

      _logRequest('GET', uri, headers: requestHeaders);

      final response = await http
          .get(uri, headers: requestHeaders)
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('A requisição excedeu o tempo limite de $timeout');
      });

      return _handleResponse<T>(response, fromJson: fromJson);
    } on TimeoutException catch (e) {
      _logError('Timeout', e);
      return ApiResult.error('Tempo limite excedido: $e');
    } catch (e) {
      _logError('Erro na requisição', e);
      return ApiResult.error('Erro ao processar requisição: $e');
    }
  }

  /// Processa a resposta HTTP e converte para o tipo apropriado
  ApiResult<T> _handleResponse<T>(
    http.Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    _logResponse(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final jsonData = json.decode(response.body);
        
        if (fromJson != null) {
          final data = fromJson(jsonData);
          return ApiResult.success(data);
        }
        
        return ApiResult.success(jsonData as T);
      } catch (e) {
        _logError('Erro ao decodificar resposta', e);
        return ApiResult.error('Erro ao processar dados: $e', 
            statusCode: response.statusCode);
      }
    } else {
      return ApiResult.error(
        'Erro ${response.statusCode}: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Registra informações sobre requisições (substitua por um logger adequado)
  void _logRequest(String method, Uri url, {Map<String, String>? headers}) {
    print('🔍 $method: $url');
    if (headers != null) print('📋 Headers: $headers');
  }

  /// Registra informações sobre respostas (substitua por um logger adequado)
  void _logResponse(http.Response response) {
    print('📩 Status: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ Resposta recebida com sucesso');
    } else {
      print('❌ Erro ${response.statusCode}: ${response.body}');
    }
  }

  /// Registra erros (substitua por um logger adequado)
  void _logError(String message, Object error) {
    print('⚠️ $message: $error');
  }
}
