import 'dart:convert'; // Para jsonEncode
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Para chamadas HTTP
// Importe suas classes:
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart'; // Seu DatabaseHelper
import 'package:flutter_docig_venda/data/models/registrar_pedido_local.dart'; // Seu modelo RegistroPedidoLocal
import 'package:flutter_docig_venda/services/dao/pedidosParaEnvioDao.dart'; // O DAO que criamos
import 'package:logger/logger.dart'; // Ou sua instância de logger



class TelaSincronizacaoPedidos extends StatefulWidget {
  const TelaSincronizacaoPedidos({super.key});

  @override
  State<TelaSincronizacaoPedidos> createState() => _TelaSincronizacaoPedidosState();
}

class _TelaSincronizacaoPedidosState extends State<TelaSincronizacaoPedidos> with WidgetsBindingObserver {
  late final PedidosParaEnvioDao _pedidosDao;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
  
  int _pedidosPendentesCount = 0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _pedidosDao = PedidosParaEnvioDao(DatabaseHelper.instance, _logger);
    WidgetsBinding.instance.addObserver(this);
    _logger.i("TelaSincronizacaoPedidos: initState - Verificando pendentes...");
    _verificarPedidosPendentes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _logger.i("TelaSincronizacaoPedidos: AppLifecycleState.resumed - Verificando pendentes...");
      _verificarPedidosPendentes();
    }
  }

  Future<void> _verificarPedidosPendentes() async {
    if (!mounted) return;
    _logger.d("TelaSincronizacaoPedidos: Iniciando _verificarPedidosPendentes()...");
    try {
      final count = await _pedidosDao.getPendentesCount();
      if (mounted) {
        _logger.d("TelaSincronizacaoPedidos: Contagem recebida do DAO: $count. _pedidosPendentesCount ANTES: $_pedidosPendentesCount");
        if (_pedidosPendentesCount != count) { 
          setState(() {
            _pedidosPendentesCount = count;
          });
          _logger.i("TelaSincronizacaoPedidos: setState chamado. Nova contagem de pendentes: $_pedidosPendentesCount");
        } else {
          _logger.d("TelaSincronizacaoPedidos: Contagem não mudou ($count), sem setState.");
        }
      }
    } catch (e, s) {
      _logger.e("TelaSincronizacaoPedidos: Erro em _verificarPedidosPendentes: $e", error: e, stackTrace: s);
      if (mounted) {
        _mostrarSnackBar("Erro ao verificar pedidos pendentes.", isError: true);
      }
    }
  }

  void _mostrarSnackBar(String mensagem, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _enviarPedidos() async {
    if (_isSending) {
      _logger.w("TelaSincronizacaoPedidos: Tentativa de enviar enquanto já estava enviando.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSending = true;
    });

    List<RegistroPedidoLocal> pedidos;
    try {
      pedidos = await _pedidosDao.getPendentesParaEnvio();
    } catch (e, s) {
      _logger.e("TelaSincronizacaoPedidos: Erro ao buscar pedidos para envio: $e", error: e, stackTrace: s);
      _mostrarSnackBar("Erro ao buscar pedidos para envio.", isError: true);
      if (mounted) {
        setState(() { _isSending = false; });
      }
      return;
    }
    
    if (pedidos.isEmpty) {
      _logger.i("TelaSincronizacaoPedidos: Nenhum pedido pendente para enviar.");
      _mostrarSnackBar("Nenhum pedido pendente para enviar.");
      if (mounted) {
        setState(() { _isSending = false; });
      }
      await _verificarPedidosPendentes();
      return;
    }

    _logger.i("TelaSincronizacaoPedidos: Iniciando envio de ${pedidos.length} pedido(s)...");
    int sucessos = 0;
    int falhas = 0;

    for (var pedidoLocal in pedidos) {
      if (pedidoLocal.idPedidoLocal == null) {
        _logger.e("TelaSincronizacaoPedidos: Crítico - Pedido local com ID nulo encontrado! Código App: ${pedidoLocal.codigoPedidoApp}. Pulando este pedido.");
        falhas++;
        continue;
      }

      _logger.i('TelaSincronizacaoPedidos: Enviando pedido cód. app: ${pedidoLocal.codigoPedidoApp}');
      
      final Uri uri = Uri.parse('http://duotecsuprilev.ddns.com.br:8082/v1/pedido');
      
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(pedidoLocal.jsonDoPedido),
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _logger.i('TelaSincronizacaoPedidos: Pedido ${pedidoLocal.codigoPedidoApp} enviado com sucesso! Resposta: ${response.body}');
          await _pedidosDao.delete(pedidoLocal.idPedidoLocal!);
          _logger.i('TelaSincronizacaoPedidos: Pedido ${pedidoLocal.codigoPedidoApp} deletado do banco local.');
          sucessos++;
        } else {
          _logger.e('TelaSincronizacaoPedidos: Falha ao enviar pedido ${pedidoLocal.codigoPedidoApp}. Status: ${response.statusCode}, Corpo: ${response.body}');
          falhas++;
        }
      } catch (e, s) {
        _logger.e('TelaSincronizacaoPedidos: Erro de conexão/timeout ao enviar pedido ${pedidoLocal.codigoPedidoApp}: $e', error: e, stackTrace: s);
        falhas++;
      }
    }

    if (mounted) {
      String feedbackMsg;
      bool houveErroGeral = falhas > 0;

      if (sucessos > 0 && falhas == 0) {
        feedbackMsg = "$sucessos pedido(s) enviado(s) com sucesso!";
      } else if (sucessos > 0 && falhas > 0) {
        feedbackMsg = "$sucessos enviado(s) com sucesso, $falhas falharam e permanecem pendentes.";
      } else if (falhas > 0 && sucessos == 0) {
        feedbackMsg = "$falhas pedido(s) falharam ao enviar e permanecem pendentes.";
      } else if (pedidos.isNotEmpty && sucessos == 0 && falhas == 0) {
        feedbackMsg = "Processamento concluído, mas sem informação de sucesso ou falha nos envios.";
        _logger.w("TelaSincronizacaoPedidos: Loop de envio concluído sem sucessos ou falhas reportadas, verificar lógica.");
      } else {
        feedbackMsg = "Nenhum pedido processado.";
      }
      _mostrarSnackBar(feedbackMsg, isError: houveErroGeral);
    }
    
    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
    await _verificarPedidosPendentes();
  }

  void _mostrarDialogoConfirmacaoEnvio() {
    if (_isSending) return;

    if (_pedidosPendentesCount == 0) {
      _mostrarSnackBar("Nenhum pedido para enviar.");
      _verificarPedidosPendentes();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: !_isSending,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Envio'),
          content: Text('Você deseja enviar os $_pedidosPendentesCount pedido(s) pendente(s) agora?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _enviarPedidos(); 
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizar Pedidos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSending ? null : _verificarPedidosPendentes,
            tooltip: "Verificar pendentes",
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_isSending) ...[
                const Text(
                  "Enviando pedidos...", 
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text(
                  "Aguarde, por favor. Isso pode levar alguns instantes.",
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  'Pedidos pendentes para envio:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '$_pedidosPendentesCount',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              if (!_isSending)
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync_problem),
                  label: const Text("Atualizar Contagem"),
                  onPressed: _verificarPedidosPendentes,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20, 
                      vertical: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _pedidosPendentesCount > 0 && !_isSending
          ? FloatingActionButton.extended(
              onPressed: _mostrarDialogoConfirmacaoEnvio,
              icon: const Icon(Icons.cloud_upload),
              label: Text('Enviar ($_pedidosPendentesCount)'),
              tooltip: 'Enviar Pedidos Pendentes',
            )
          : null,
    );
  }
}