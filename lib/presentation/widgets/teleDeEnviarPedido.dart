import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_docig_venda/data/models/registrar_pedido_local.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:logger/logger.dart';

/// Tela responsável pela sincronização de pedidos com o servidor
/// Utiliza Repository pattern para gerenciar dados locais
class TelaSincronizacaoPedidos extends StatefulWidget {
  final RepositoryManager repositoryManager;

  const TelaSincronizacaoPedidos({
    super.key,
    required this.repositoryManager,
  });

  @override
  State<TelaSincronizacaoPedidos> createState() => _TelaSincronizacaoPedidosState();
}

class _TelaSincronizacaoPedidosState extends State<TelaSincronizacaoPedidos> 
    with WidgetsBindingObserver {
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      // Removido printTime deprecated
    ),
  );

  // Estados da aplicação
  int _pedidosPendentesCount = 0;
  bool _isSending = false;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _ultimaVerificacao;

  // Configurações
  static const String _baseUrl = 'http://duotecsuprilev.ddns.com.br:8082';
  static const Duration _timeoutDuration = Duration(seconds: 45);
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxRetries = 3;

  // Getter para facilitar acesso ao repository
  PedidosParaEnvioRepository get _pedidosRepo => 
      widget.repositoryManager.pedidosParaEnvio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logger.i("TelaSincronizacaoPedidos: Inicializando tela");
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _verificarPedidosPendentes();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _logger.i("App retomado - Verificando pedidos pendentes");
      _verificarPedidosPendentes();
    }
  }

  /// Verifica quantidade de pedidos pendentes para envio
  Future<void> _verificarPedidosPendentes() async {
    if (!mounted) return;

    _setLoading(true);
    _clearError();

    try {
      final count = await _pedidosRepo.getPendentesCount();
      _ultimaVerificacao = DateTime.now();
      
      if (mounted && _pedidosPendentesCount != count) {
        setState(() {
          _pedidosPendentesCount = count;
        });
        _logger.i("Pedidos pendentes atualizados: $count");
      }
    } catch (e, stackTrace) {
      _logger.e("Erro ao verificar pedidos pendentes", error: e, stackTrace: stackTrace);
      _setError("Erro ao verificar pedidos: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }

  /// Envia todos os pedidos pendentes para o servidor
  Future<void> _enviarPedidos() async {
    if (_isSending || !mounted) return;

    _setSending(true);
    _clearError();

    try {
      final pedidos = await _pedidosRepo.getPendentesParaEnvio();
      
      if (pedidos.isEmpty) {
        _logger.i("Nenhum pedido pendente para enviar");
        _showMessage("Nenhum pedido pendente para enviar");
        await _verificarPedidosPendentes();
        return;
      }

      _logger.i("Iniciando envio de ${pedidos.length} pedido(s)");
      
      final resultado = await _processarEnvioPedidos(pedidos);
      _exibirResultadoEnvio(resultado);
      
    } catch (e, stackTrace) {
      _logger.e("Erro geral no envio de pedidos", error: e, stackTrace: stackTrace);
      _setError("Erro no envio: ${e.toString()}");
    } finally {
      _setSending(false);
      await _verificarPedidosPendentes();
    }
  }

  /// Processa o envio de uma lista de pedidos
  Future<ResultadoEnvio> _processarEnvioPedidos(List<RegistroPedidoLocal> pedidos) async {
    int sucessos = 0;
    int falhas = 0;
    final errosDetalhados = <String>[];

    for (final pedido in pedidos) {
      if (!mounted) break;
      
      if (pedido.idPedidoLocal == null) {
        _logger.e("Pedido com ID nulo: ${pedido.codigoPedidoApp}");
        falhas++;
        errosDetalhados.add("Pedido ${pedido.codigoPedidoApp}: ID nulo");
        continue;
      }

      final resultado = await _enviarPedidoIndividual(pedido);
      
      if (resultado.sucesso) {
        sucessos++;
        await _removerPedidoLocal(pedido);
      } else {
        falhas++;
        errosDetalhados.add("Pedido ${pedido.codigoPedidoApp}: ${resultado.erro}");
      }

      // Pequena pausa entre envios para não sobrecarregar o servidor
      if (mounted && pedidos.indexOf(pedido) < pedidos.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return ResultadoEnvio(
      sucessos: sucessos,
      falhas: falhas,
      errosDetalhados: errosDetalhados,
    );
  }

  /// Envia um pedido individual para o servidor
  Future<ResultadoPedido> _enviarPedidoIndividual(RegistroPedidoLocal pedido) async {
    _logger.i("Enviando pedido: ${pedido.codigoPedidoApp}");

    for (int tentativa = 1; tentativa <= _maxRetries; tentativa++) {
      try {
        final uri = Uri.parse('$_baseUrl/v1/pedido');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(pedido.jsonDoPedido),
        ).timeout(_timeoutDuration);

        if (_isResponseSuccess(response.statusCode)) {
          _logger.i("Pedido ${pedido.codigoPedidoApp} enviado com sucesso");
          return ResultadoPedido.sucesso();
        } else {
          final erro = "Status ${response.statusCode}: ${response.body}";
          _logger.w("Falha no envio (tentativa $tentativa): $erro");
          
          if (tentativa == _maxRetries) {
            return ResultadoPedido.erro(erro);
          }
        }
      } catch (e) {
        _logger.w("Erro na tentativa $tentativa: $e");
        
        if (tentativa == _maxRetries) {
          return ResultadoPedido.erro(_formatarErroRede(e));
        }
        
        if (mounted && tentativa < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }
    }

    return ResultadoPedido.erro("Máximo de tentativas excedido");
  }

  /// Remove pedido do banco local após envio bem-sucedido
  /// CORRIGIDO: Usa o método correto do repository
  Future<void> _removerPedidoLocal(RegistroPedidoLocal pedido) async {
    try {
      final deletados = await _pedidosRepo.deletePedidoPorId(pedido.idPedidoLocal!);
      if (deletados > 0) {
        _logger.i("Pedido ${pedido.codigoPedidoApp} removido do banco local");
      } else {
        _logger.w("Pedido ${pedido.codigoPedidoApp} não foi encontrado para remoção");
      }
    } catch (e, stackTrace) {
      _logger.e("Erro ao remover pedido local: ${pedido.codigoPedidoApp}", 
                error: e, stackTrace: stackTrace);
      // Não relança a exceção para não interromper o processo de envio
    }
  }

  /// Exibe o resultado final do envio
  void _exibirResultadoEnvio(ResultadoEnvio resultado) {
    if (!mounted) return;

    String mensagem;
    bool isError;

    if (resultado.sucessos > 0 && resultado.falhas == 0) {
      mensagem = "${resultado.sucessos} pedido(s) enviado(s) com sucesso!";
      isError = false;
    } else if (resultado.sucessos > 0 && resultado.falhas > 0) {
      mensagem = "${resultado.sucessos} enviado(s), ${resultado.falhas} falharam";
      isError = true;
    } else if (resultado.falhas > 0) {
      mensagem = "${resultado.falhas} pedido(s) falharam no envio";
      isError = true;
    } else {
      mensagem = "Processamento concluído sem resultados";
      isError = false;
    }

    _showMessage(mensagem, isError: isError);
    
    // Log detalhado dos erros
    if (resultado.errosDetalhados.isNotEmpty) {
      for (final erro in resultado.errosDetalhados) {
        _logger.e("Detalhes do erro: $erro");
      }
    }
  }

  /// Mostra diálogo de confirmação antes do envio
  void _mostrarDialogoConfirmacaoEnvio() {
    if (_isSending || _pedidosPendentesCount == 0) {
      if (_pedidosPendentesCount == 0) {
        _showMessage("Nenhum pedido para enviar");
        _verificarPedidosPendentes();
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Envio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja enviar $_pedidosPendentesCount pedido(s) pendente(s)?'),
            const SizedBox(height: 12),
            const Text(
              'Esta operação não pode ser cancelada uma vez iniciada.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _enviarPedidos();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para gerenciamento de estado
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) _errorMessage = null;
      });
    }
  }

  void _setSending(bool sending) {
    if (mounted) {
      setState(() => _isSending = sending);
    }
  }

  void _setError(String error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  void _clearError() {
    if (mounted) {
      setState(() => _errorMessage = null);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: isError ? SnackBarAction(
          label: 'Detalhes',
          textColor: Colors.white,
          onPressed: () => _mostrarDetalhesErro(),
        ) : null,
      ),
    );
  }

  void _mostrarDetalhesErro() {
    if (_errorMessage == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalhes do Erro'),
        content: SingleChildScrollView(
          child: Text(_errorMessage!),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // Métodos utilitários
  bool _isResponseSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  String _formatarErroRede(dynamic erro) {
    if (erro is SocketException) {
      return "Erro de conexão: Verifique sua internet";
    } else if (erro is HttpException) {
      return "Erro HTTP: ${erro.message}";
    } else if (erro.toString().contains('timeout')) {
      return "Timeout: Servidor demorou para responder";
    } else {
      return "Erro de rede: ${erro.toString()}";
    }
  }

  String _formatarUltimaVerificacao() {
    if (_ultimaVerificacao == null) return "";
    
    final agora = DateTime.now();
    final diferenca = agora.difference(_ultimaVerificacao!);
    
    if (diferenca.inMinutes < 1) {
      return "Atualizado agora";
    } else if (diferenca.inMinutes < 60) {
      return "Atualizado há ${diferenca.inMinutes}m";
    } else {
      return "Atualizado há ${diferenca.inHours}h";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizar Pedidos'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isSending ? null : _verificarPedidosPendentes,
            tooltip: "Atualizar contagem",
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _verificarPedidosPendentes,
      color: Theme.of(context).primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_isSending) ...[
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                'Enviando pedidos...',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Aguarde, isso pode levar alguns instantes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ] else ...[
              Icon(
                _pedidosPendentesCount > 0 
                    ? Icons.cloud_upload_outlined 
                    : Icons.cloud_done_outlined,
                size: 48,
                color: _pedidosPendentesCount > 0 ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'Pedidos Pendentes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '$_pedidosPendentesCount',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _pedidosPendentesCount > 0 ? Colors.orange : Colors.green,
                ),
              ),
              if (_ultimaVerificacao != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatarUltimaVerificacao(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
              if (_pedidosPendentesCount == 0) ...[
                const SizedBox(height: 8),
                const Text(
                  'Todos os pedidos foram enviados!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Configurações',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Servidor:', _baseUrl),
            _buildInfoRow('Timeout:', '${_timeoutDuration.inSeconds}s'),
            _buildInfoRow('Tentativas:', '$_maxRetries por pedido'),
            _buildInfoRow('Status:', _isSending ? 'Enviando...' : 'Aguardando'),
            const SizedBox(height: 16),
            if (!_isSending && !_isLoading)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar Contagem'),
                  onPressed: _verificarPedidosPendentes,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Erro',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _clearError(),
                  child: const Text('Dispensar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _verificarPedidosPendentes,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_pedidosPendentesCount == 0 || _isSending || _isLoading) {
      return null;
    }

    return FloatingActionButton.extended(
      onPressed: _mostrarDialogoConfirmacaoEnvio,
      icon: const Icon(Icons.cloud_upload),
      label: Text('Enviar ($_pedidosPendentesCount)'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
      tooltip: 'Enviar pedidos pendentes',
    );
  }
}

// Classes auxiliares para organizar resultados
class ResultadoEnvio {
  final int sucessos;
  final int falhas;
  final List<String> errosDetalhados;

  ResultadoEnvio({
    required this.sucessos,
    required this.falhas,
    required this.errosDetalhados,
  });
}

class ResultadoPedido {
  final bool sucesso;
  final String? erro;

  ResultadoPedido.sucesso() : sucesso = true, erro = null;
  ResultadoPedido.erro(this.erro) : sucesso = false;
}