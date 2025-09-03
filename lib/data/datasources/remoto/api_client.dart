import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Resultado genérico para operações de API com melhor handling
class ApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ApiResult._({
    required this.isSuccess,
    this.data,
    this.errorMessage,
    this.statusCode,
    this.metadata,
  }) : timestamp = DateTime.now();

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

  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResult.success(data: ${data.runtimeType}, statusCode: $statusCode)';
    } else {
      return 'ApiResult.error(message: $errorMessage, statusCode: $statusCode)';
    }
  }
}

/// Cliente API unificado otimizado com cache e retry inteligente
class UnifiedApiClient {
  final String baseUrl;
  final String codigoVendedor;
  final Map<String, String> defaultHeaders;
  final Logger _logger = Logger();
  final Duration timeout;
  
  // Cache simples para evitar requisições desnecessárias
  final Map<String, ApiResult<dynamic>> _cache = {};
  final Duration _cacheDuration = const Duration(minutes: 5);
  
  String? _authToken;
  DateTime? _tokenExpiry;

  UnifiedApiClient({
    required this.baseUrl,
    required this.codigoVendedor,
    Map<String, String>? headers,
    this.timeout = const Duration(seconds: 30),
  }) : defaultHeaders = headers ?? {
    'Accept': 'application/json',
    'User-Agent': 'DocigVenda/1.0',
  };

  /// Verifica conectividade de forma otimizada
  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((result) => 
        result == ConnectivityResult.mobile || 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet
      );
    } catch (e) {
      _logger.w("Erro ao verificar conectividade: $e");
      return false;
    }
  }

  /// Headers otimizados com compressão
  Map<String, String> _getHeaders() {
    final headers = Map<String, String>.from(defaultHeaders);
    headers['Content-Type'] = 'application/json; charset=utf-8';
    headers['Accept-Encoding'] = 'gzip, deflate';
    
    if (_authToken != null && (_tokenExpiry == null || DateTime.now().isBefore(_tokenExpiry!))) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    
    return headers;
  }

  /// Gera chave de cache
  String _getCacheKey(String endpoint, Map<String, String>? queryParams) {
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    return uri.toString();
  }

  /// Verifica se o cache é válido
  bool _isCacheValid(String cacheKey) {
    if (!_cache.containsKey(cacheKey)) return false;
    
    final cachedResult = _cache[cacheKey]!;
    final isExpired = DateTime.now().difference(cachedResult.timestamp) > _cacheDuration;
    
    if (isExpired) {
      _cache.remove(cacheKey);
      return false;
    }
    
    return true;
  }

  /// Define o token de autenticação
  void setAuthToken(String token, {Duration validity = const Duration(hours: 24)}) {
    _authToken = token;
    _tokenExpiry = DateTime.now().add(validity);
    _logger.i("Token definido. Expira em: $_tokenExpiry");
  }

  /// Limpa cache
  void clearCache() {
    _cache.clear();
    _logger.d("Cache limpo");
  }

  /// Requisição GET otimizada com cache inteligente
  Future<ApiResult<T>> get<T>(
    String endpoint, {
    T Function(dynamic json)? fromJson,
    Map<String, String>? queryParams,
    int maxRetries = 3,
    bool useCache = true,
    Duration? customTimeout,
  }) async {
    // Verifica cache primeiro
    if (useCache) {
      final cacheKey = _getCacheKey(endpoint, queryParams);
      if (_isCacheValid(cacheKey)) {
        final cachedResult = _cache[cacheKey]!;
        _logger.d("Cache hit para: $endpoint");
        return ApiResult.success(cachedResult.data as T, statusCode: cachedResult.statusCode);
      }
    }

    if (!await _checkConnectivity()) {
      return ApiResult.error("Sem conexão com a internet", statusCode: 0);
    }

    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    _logger.i("GET: $uri");

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(uri, headers: _getHeaders())
            .timeout(customTimeout ?? timeout);

        _logger.d("Status: ${response.statusCode} | Tamanho: ${response.body.length} bytes");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) {
            final result = ApiResult.success(null as T, statusCode: response.statusCode);
            if (useCache) _cache[_getCacheKey(endpoint, queryParams)] = result;
            return result;
          }

          try {
            final jsonData = json.decode(response.body);
            final data = fromJson != null ? fromJson(jsonData) : jsonData as T;
            final result = ApiResult.success(data, statusCode: response.statusCode);
            
            // Cache apenas respostas bem-sucedidas
            if (useCache) _cache[_getCacheKey(endpoint, queryParams)] = result;
            
            return result;
          } catch (jsonError) {
            _logger.e("Erro ao decodificar JSON: $jsonError");
            return ApiResult.error("Resposta inválida do servidor", statusCode: response.statusCode);
          }
        }

        // Retry inteligente baseado no status code
        if (_shouldRetry(response.statusCode, attempt, maxRetries)) {
          final delay = _calculateRetryDelay(attempt);
          _logger.w("Tentativa $attempt/$maxRetries falhada. Tentando novamente em ${delay.inSeconds}s");
          await Future.delayed(delay);
          continue;
        }

        return ApiResult.error(
          _getErrorMessage(response.statusCode, response.body),
          statusCode: response.statusCode,
        );
      } catch (e) {
        _logger.e("Erro na tentativa $attempt/$maxRetries: $e");
        
        if (attempt == maxRetries) {
          return ApiResult.error("Erro após $maxRetries tentativas: ${_simplifyError(e)}", statusCode: 0);
        }
        
        await Future.delayed(_calculateRetryDelay(attempt));
      }
    }

    return ApiResult.error("Falha após todas as tentativas", statusCode: 0);
  }

  /// Requisição POST otimizada
  Future<ApiResult<T>> post<T>(
    String endpoint, {
    dynamic body,
    T Function(dynamic json)? fromJson,
    Duration? customTimeout,
    int maxRetries = 2,
  }) async {
    if (!await _checkConnectivity()) {
      return ApiResult.error("Sem conexão com a internet", statusCode: 0);
    }

    final uri = Uri.parse('$baseUrl$endpoint');
    _logger.i("POST: $uri");
    
    final requestBody = body != null ? json.encode(body) : null;
    if (requestBody != null) {
      _logger.d("Body size: ${requestBody.length} bytes");
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: _getHeaders(),
              body: requestBody,
            )
            .timeout(customTimeout ?? timeout);

        _logger.d("Status: ${response.statusCode}");

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) {
            return ApiResult.success(null as T, statusCode: response.statusCode);
          }

          try {
            final jsonData = json.decode(response.body);
            final data = fromJson != null ? fromJson(jsonData) : jsonData as T;
            return ApiResult.success(data, statusCode: response.statusCode);
          } catch (jsonError) {
            _logger.e("Erro ao decodificar JSON: $jsonError");
            return ApiResult.error("Resposta inválida do servidor", statusCode: response.statusCode);
          }
        }

        if (attempt < maxRetries && _shouldRetry(response.statusCode, attempt, maxRetries)) {
          await Future.delayed(_calculateRetryDelay(attempt));
          continue;
        }

        return ApiResult.error(
          _getErrorMessage(response.statusCode, response.body),
          statusCode: response.statusCode,
        );
      } catch (e) {
        _logger.e("Erro no POST (tentativa $attempt): $e");
        
        if (attempt == maxRetries) {
          return ApiResult.error("Erro na requisição: ${_simplifyError(e)}", statusCode: 0);
        }
        
        await Future.delayed(_calculateRetryDelay(attempt));
      }
    }

    return ApiResult.error("Falha após todas as tentativas", statusCode: 0);
  }

  /// Determina se deve tentar novamente baseado no status code
  bool _shouldRetry(int statusCode, int attempt, int maxRetries) {
    if (attempt >= maxRetries) return false;
    
    // Retry para erros de servidor ou rate limiting
    return statusCode >= 500 || statusCode == 429 || statusCode == 408;
  }

  /// Calcula delay exponencial para retry
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = Duration(milliseconds: 500 * attempt);
    final jitter = Duration(milliseconds: (attempt * 100)); // Adiciona jitter
    return baseDelay + jitter;
  }

  /// Simplifica mensagens de erro
  String _simplifyError(dynamic error) {
    if (error.toString().contains('TimeoutException')) {
      return 'Timeout na requisição';
    } else if (error.toString().contains('SocketException')) {
      return 'Erro de conexão';
    } else if (error.toString().contains('HandshakeException')) {
      return 'Erro SSL/TLS';
    }
    return error.toString();
  }

  /// Gera mensagens de erro mais amigáveis
  String _getErrorMessage(int statusCode, String responseBody) {
    switch (statusCode) {
      case 400:
        return 'Requisição inválida';
      case 401:
        return 'Não autorizado';
      case 403:
        return 'Acesso negado';
      case 404:
        return 'Recurso não encontrado';
      case 422:
        return 'Dados inválidos';
      case 429:
        return 'Muitas requisições. Tente novamente em alguns segundos';
      case 500:
        return 'Erro interno do servidor';
      case 502:
        return 'Servidor indisponível';
      case 503:
        return 'Serviço temporariamente indisponível';
      default:
        return 'Erro HTTP $statusCode';
    }
  }

  /// Obtém estatísticas do cache
  Map<String, dynamic> getCacheStats() {
    return {
      'totalEntries': _cache.length,
      'cacheKeys': _cache.keys.toList(),
      'cacheDuration': _cacheDuration.inMinutes,
    };
  }

  /// Método para debug das configurações
  Map<String, dynamic> getClientInfo() {
    return {
      'baseUrl': baseUrl,
      'codigoVendedor': codigoVendedor,
      'timeout': timeout.inSeconds,
      'hasAuthToken': _authToken != null,
      'tokenExpiry': _tokenExpiry?.toIso8601String(),
      'defaultHeaders': defaultHeaders,
      'cacheStats': getCacheStats(),
    };
  }
}