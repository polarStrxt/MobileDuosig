import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Resultado genérico para operações de API
class ApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final Map<String, dynamic>? metadata;

  ApiResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.metadata,
  });

  factory ApiResult.success(T data, {int? statusCode, Map<String, dynamic>? metadata}) {
    return ApiResult._(
      isSuccess: true,
      data: data,
      statusCode: statusCode ?? 200,
      metadata: metadata,
    );
  }

  factory ApiResult.error(String message, {int? statusCode, Map<String, dynamic>? metadata}) {
    return ApiResult._(
      isSuccess: false,
      errorMessage: message,
      statusCode: statusCode,
      metadata: metadata,
    );
  }
}

/// Cliente API unificado com interceptors e retry logic
class UnifiedApiClient {
  final String baseUrl;
  final String empresaId;
  final Map<String, String> defaultHeaders;
  final Logger _logger = Logger();
  final Duration timeout;
  
  String? _authToken;
  DateTime? _tokenExpiry;

  UnifiedApiClient({
    required this.baseUrl,
    required this.empresaId,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 30),
  }) : defaultHeaders = headers ?? {};

  /// Verifica conectividade antes de fazer chamadas
  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Obtém headers atualizados com token
  Map<String, String> _getHeaders() {
    final headers = Map<String, String>.from(defaultHeaders);
    headers['Content-Type'] = 'application/json';
    
    if (_authToken != null && (_tokenExpiry == null || DateTime.now().isBefore(_tokenExpiry!))) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  /// Define o token de autenticação
  void setAuthToken(String token, {Duration validity = const Duration(hours: 24)}) {
    _authToken = token;
    _tokenExpiry = DateTime.now().add(validity);
    _logger.i("Token de autenticação definido. Expira em: $_tokenExpiry");
  }

  /// Requisição GET genérica com retry automático
  Future<ApiResult<T>> get<T>(
    String endpoint, {
    T Function(dynamic json)? fromJson,
    Map<String, String>? queryParams,
    int maxRetries = 3,
  }) async {
    if (!await _checkConnectivity()) {
      return ApiResult.error("Sem conexão com a internet");
    }

    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    _logger.i("GET Request: $uri");

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(uri, headers: _getHeaders())
            .timeout(timeout);

        _logger.d("Response Status: ${response.statusCode}");
        _logger.d("Response Body: ${response.body}");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final jsonData = json.decode(response.body);
          
          if (fromJson != null) {
            final data = fromJson(jsonData);
            return ApiResult.success(data, statusCode: response.statusCode);
          }
          
          return ApiResult.success(jsonData as T, statusCode: response.statusCode);
        }

        // Retry apenas para erros 5xx ou timeout
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        return ApiResult.error(
          "Erro na requisição: ${response.statusCode}",
          statusCode: response.statusCode,
        );
      } catch (e) {
        _logger.e("Erro na tentativa $attempt de $maxRetries", error: e);
        
        if (attempt == maxRetries) {
          return ApiResult.error("Erro após $maxRetries tentativas: $e");
        }
        
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    return ApiResult.error("Falha após todas as tentativas");
  }

  /// Requisição POST genérica
  Future<ApiResult<T>> post<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic json)? fromJson,
  }) async {
    if (!await _checkConnectivity()) {
      return ApiResult.error("Sem conexão com a internet");
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    _logger.i("POST Request: $uri");
    _logger.d("Request Body: $body");

    try {
      final response = await http
          .post(
            uri,
            headers: _getHeaders(),
            body: json.encode(body),
          )
          .timeout(timeout);

      _logger.d("Response Status: ${response.statusCode}");
      _logger.d("Response Body: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return ApiResult.success(null as T, statusCode: response.statusCode);
        }

        final jsonData = json.decode(response.body);
        
        if (fromJson != null) {
          final data = fromJson(jsonData);
          return ApiResult.success(data, statusCode: response.statusCode);
        }
        
        return ApiResult.success(jsonData as T, statusCode: response.statusCode);
      }

      return ApiResult.error(
        "Erro na requisição: ${response.statusCode}",
        statusCode: response.statusCode,
      );
    } catch (e) {
      _logger.e("Erro no POST", error: e);
      return ApiResult.error("Erro na requisição: $e");
    }
  }
}