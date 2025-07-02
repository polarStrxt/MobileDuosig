import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/perfilCriente.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/widgets/app_drawer.dart';
import 'package:flutter_docig_venda/services/Sincronizacao.dart';
import 'package:flutter_docig_venda/services/dao/pedidosParaEnvioDao.dart';
import 'package:flutter_docig_venda/models/registrar_pedido_local.dart';
import 'package:flutter_docig_venda/services/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Constantes e temas
  static const Color primaryColor = Color(0xFF5D5CDE);
  static const Color secondaryColor = Color(0xFF7472E0);
  static const Color errorColor = Color(0xFFE03F3F);
  static const Color warningColor = Color(0xFFE0A030);
  final Logger _logger = Logger(
    printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: false),
  );

  // Estado da lista de clientes
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  Map<String, String> clienteSearchIndex = {};

  // Estado de carregamento e sincronização geral
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isSyncing = false;

  // Estado para pedidos pendentes
  int _pedidosPendentesCount = 0;
  bool _isSendingPedidos = false;
  late final PedidosParaEnvioDao _pedidosParaEnvioDao;
  List<Map<String, dynamic>> _listaUiPedidosPendentes = [];

  // Controllers e Timers
  final ClienteDao _clienteDao = ClienteDao();
  final SyncService _syncService = SyncService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pedidosParaEnvioDao = PedidosParaEnvioDao(DatabaseHelper.instance, _logger);
    WidgetsBinding.instance.addObserver(this);

    _logger.i("HomeScreen: initState - Carregando clientes locais e depois pedidos pendentes...");
    carregarClientesLocal().then((_) {
      if (clientes.isEmpty && mounted) {
        _logger.i("HomeScreen: Lista de clientes vazia após carga local, iniciando sincronização de dados...");
        _sincronizarDados(mostrarUI: false);
      }
      if (mounted) {
        _logger.i("HomeScreen: initState - Chamando _carregarPedidosPendentes() após carregarClientesLocal.");
        _carregarPedidosPendentes();
      }
    });
  }

  @override
  void dispose() {
    _logger.i("HomeScreen: dispose - Removendo observer e limpando controllers.");
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _logger.i("HomeScreen: AppLifecycleState.resumed - Recarregando contagem e lista de pedidos pendentes...");
      _carregarPedidosPendentes();
    }
  }

  // MÉTODOS PARA GERENCIAR PEDIDOS PENDENTES
  Future<void> _carregarPedidosPendentes() async {
    if (!mounted) return;
    _logger.d("HomeScreen: Iniciando _carregarPedidosPendentes() para UI e contagem...");

    try {
      final List<RegistroPedidoLocal> pendentesDoBanco = 
          await _pedidosParaEnvioDao.getPendentesParaEnvio();

      List<Map<String, dynamic>> novaListaUi = [];

      for (var pedidoLocal in pendentesDoBanco) {
        String nomeClienteParaUi = "Cliente Desconhecido";

        if (clientes.isNotEmpty) {
          try {
            final String? codClienteStr = 
                pedidoLocal.jsonDoPedido['cod_cliente']?.toString();

            if (codClienteStr != null && codClienteStr.isNotEmpty) {
              final int codCliDoPedido = int.parse(codClienteStr);

              final clienteEncontrado = clientes.firstWhere(
                  (clienteDaLista) => clienteDaLista.codcli == codCliDoPedido,
                  orElse: () {
                _logger.w("Cliente com codcli $codCliDoPedido (do pedido ${pedidoLocal.codigoPedidoApp}) não foi encontrado na lista 'clientes' carregada.");
                return Cliente.empty();
              });

              if (clienteEncontrado.codcli != 0 && 
                  clienteEncontrado.nomcli != "Cliente Desconhecido") {
                nomeClienteParaUi = clienteEncontrado.nomcli;
              } else if (clienteEncontrado.codcli == 0 &&
                  clienteEncontrado.nomcli == "Cliente Desconhecido") {
                if (codCliDoPedido != 0) {
                  _logger.i("Pedido ${pedidoLocal.codigoPedidoApp} tem cod_cliente $codCliDoPedido, mas o cliente não foi encontrado. Usando nome padrão.");
                }
              } else {
                _logger.d("Cliente encontrado para pedido ${pedidoLocal.codigoPedidoApp} com codcli=${clienteEncontrado.codcli} e nome='${clienteEncontrado.nomcli}', usando nome padrão se for o caso.");
                if (clienteEncontrado.nomcli.isNotEmpty) {
                  nomeClienteParaUi = clienteEncontrado.nomcli;
                }
              }
            } else {
              _logger.w("cod_cliente não encontrado ou está vazio no JSON do pedido ${pedidoLocal.codigoPedidoApp}");
            }
          } catch (e) {
            _logger.e("Erro ao processar/buscar nome do cliente para pedido ${pedidoLocal.codigoPedidoApp}: $e");
          }
        } else {
          _logger.w("A lista principal de clientes (this.clientes) está vazia. Os nomes dos clientes para os pedidos pendentes não puderam ser buscados.");
        }

        novaListaUi.add({
          'codigoPedidoApp': pedidoLocal.codigoPedidoApp,
          'nomeCliente': nomeClienteParaUi,
          'dataCriacao': DateFormat('dd/MM/yy HH:mm').format(pedidoLocal.dataCriacao),
          'statusEnvio': pedidoLocal.statusEnvio,
          'objetoOriginal': pedidoLocal,
        });
      }

      if (mounted) {
        _logger.d("HomeScreen: Nº de pendentes para UI: ${novaListaUi.length}. _pedidosPendentesCount ATUAL: $_pedidosPendentesCount");

        if (_pedidosPendentesCount != novaListaUi.length ||
            _listaUiPedidosPendentes.length != novaListaUi.length) {
          setState(() {
            _pedidosPendentesCount = novaListaUi.length;
            _listaUiPedidosPendentes = novaListaUi;
          });
          _logger.i("HomeScreen: setState chamado. Nova contagem: $_pedidosPendentesCount. Itens na lista UI: ${_listaUiPedidosPendentes.length}");
        } else {
          _logger.d("HomeScreen: Contagem e tamanho da lista UI não mudaram, sem necessidade de setState.");
        }
      }
    } catch (e, s) {
      _logger.e("HomeScreen: Erro GERAL em _carregarPedidosPendentes: $e", error: e, stackTrace: s);
      if (mounted) {
        _mostrarSnackBar(
            'Erro ao carregar lista de pedidos pendentes: ${_getFriendlyErrorMessage(e)}',
            errorColor);
      }
    }
  }

  void _mostrarDialogoConfirmacaoEnvio() {
    if (_isSendingPedidos) return;

    if (_pedidosPendentesCount == 0) {
      _mostrarSnackBar('Nenhum pedido para enviar.', primaryColor);
      _carregarPedidosPendentes();
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Envio'),
          content: Text('Deseja enviar $_pedidosPendentesCount pedido(s) pendente(s) para o servidor?'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _processarEnvioDePedidos();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processarEnvioDePedidos() async {
    if (_isSendingPedidos) {
      _logger.w("HomeScreen: Tentativa de enviar enquanto já estava enviando.");
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSendingPedidos = true;
    });

    _mostrarDialogoCarregamento(mensagem: 'Enviando pedidos ao servidor...');

    List<RegistroPedidoLocal> pedidos;
    try {
      pedidos = await _pedidosParaEnvioDao.getPendentesParaEnvio();
    } catch (e, s) {
      _logger.e("HomeScreen: Erro ao buscar pedidos para envio: $e", error: e, stackTrace: s);
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _mostrarSnackBar(
            'Erro ao buscar pedidos para envio: ${_getFriendlyErrorMessage(e)}',
            errorColor);
        setState(() {
          _isSendingPedidos = false;
        });
      }
      return;
    }

    if (pedidos.isEmpty) {
      _logger.i("HomeScreen: Nenhum pedido pendente para enviar.");
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _mostrarSnackBar('Nenhum pedido pendente para enviar.', primaryColor);
        setState(() {
          _isSendingPedidos = false;
        });
      }
      await _carregarPedidosPendentes();
      return;
    }

    _logger.i("HomeScreen: Iniciando envio de ${pedidos.length} pedido(s)...");
    int sucessos = 0;
    int falhas = 0;

    for (var pedidoLocal in pedidos) {
      if (pedidoLocal.idPedidoLocal == null) {
        _logger.e("HomeScreen: Crítico - Pedido local com ID nulo! Código App: ${pedidoLocal.codigoPedidoApp}. Pulando.");
        falhas++;
        continue;
      }

      _logger.i('HomeScreen: Enviando pedido cód. app: ${pedidoLocal.codigoPedidoApp}');
      final Uri uri = Uri.parse('http://duotecsuprilev.ddns.com.br:8082/v1/pedido');

      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json; charset=UTF-8'},
              body: jsonEncode(pedidoLocal.jsonDoPedido),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200 || response.statusCode == 201) {
          _logger.i('HomeScreen: Pedido ${pedidoLocal.codigoPedidoApp} enviado com sucesso! Resposta: ${response.body}');
          await _pedidosParaEnvioDao.delete(pedidoLocal.idPedidoLocal!);
          _logger.i('HomeScreen: Pedido ${pedidoLocal.codigoPedidoApp} deletado do banco local.');
          sucessos++;
        } else {
          _logger.e('HomeScreen: Falha ao enviar pedido ${pedidoLocal.codigoPedidoApp}. Status: ${response.statusCode}, Corpo: ${response.body}');
          falhas++;
        }
      } catch (e, s) {
        _logger.e('HomeScreen: Erro de conexão/timeout ao enviar pedido ${pedidoLocal.codigoPedidoApp}: $e', error: e, stackTrace: s);
        falhas++;
      }
    }

    if (mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context);

      String feedbackMsg;
      Color feedbackColor;

      if (sucessos > 0 && falhas == 0) {
        feedbackMsg = "$sucessos pedido(s) enviado(s) com sucesso!";
        feedbackColor = Colors.green[700]!;
      } else if (sucessos > 0 && falhas > 0) {
        feedbackMsg = "$sucessos enviado(s) com sucesso, $falhas falharam e permanecem pendentes.";
        feedbackColor = warningColor;
      } else if (falhas > 0 && sucessos == 0) {
        feedbackMsg = "$falhas pedido(s) falharam ao enviar e permanecem pendentes.";
        feedbackColor = errorColor;
      } else if (pedidos.isNotEmpty && sucessos == 0 && falhas == 0) {
        feedbackMsg = "Nenhum pedido foi efetivamente enviado ou falhou.";
        feedbackColor = warningColor;
        _logger.w("HomeScreen: Loop de envio concluído sem sucessos ou falhas reportadas.");
      } else {
        feedbackMsg = "Nenhum pedido processado.";
        feedbackColor = primaryColor;
      }
      _mostrarSnackBar(feedbackMsg, feedbackColor);

      setState(() {
        _isSendingPedidos = false;
      });
    }
    await _carregarPedidosPendentes();
  }

  // --- MÉTODOS DE CARREGAMENTO E SINCRONIZAÇÃO DE DADOS DE CLIENTES ---
  Future<void> _sincronizarDados({bool mostrarUI = true}) async {
    if (isSyncing) return;

    if (mounted && mostrarUI) {
      setState(() {
        isSyncing = true;
      });
      _mostrarDialogoCarregamento(mensagem: 'Sincronizando dados com o servidor...');
    }

    try {
      final conexaoResult = await _syncService.verificarConexaoInternet();

      if (!conexaoResult.isSuccess || !(conexaoResult.data ?? false)) {
        if (mounted && mostrarUI) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          _mostrarSnackBar('Sem conexão com a internet. Usando dados locais.', warningColor);
        }
        return;
      }

      final syncResult = await _syncService.sincronizarTodosDados();

      if (mounted && mostrarUI) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      }

      if (syncResult.isSuccess) {
        await carregarClientesLocal();
        if (mounted && mostrarUI) {
          _mostrarSnackBar(
              'Sincronização concluída: ${syncResult.totalCount} registros atualizados',
              primaryColor);
        }
      } else {
        if (mounted && mostrarUI) {
          _mostrarSnackBar('Erro na sincronização: ${syncResult.errorMessage}', errorColor);
        }
      }
    } catch (e) {
      _logger.e("Erro em _sincronizarDados: $e");
      if (mounted && mostrarUI) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _mostrarSnackBar(
            'Erro durante a sincronização: ${_getFriendlyErrorMessage(e)}',
            errorColor);
      }
    } finally {
      if (mounted) {
        if (mostrarUI) {
          setState(() {
            isSyncing = false;
          });
        }
        _logger.i("HomeScreen: _sincronizarDados finalizado, chamando _carregarPedidosPendentes()...");
        await _carregarPedidosPendentes();
      }
    }
  }

  Future<void> carregarClientesLocal() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      List<Cliente> listaLocal = await _clienteDao.getAll((json) => Cliente.fromJson(json));
      _buildSearchIndex(listaLocal);

      if (mounted) {
        setState(() {
          clientes = listaLocal;
          clientesFiltrados = listaLocal;
          isLoading = false;
        });
      }
    } catch (e) {
      _logger.e("Erro em carregarClientesLocal: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = "Erro ao buscar dados locais: ${_getFriendlyErrorMessage(e)}";
        });
      }
    }
  }

  void _buildSearchIndex(List<Cliente> listaClientes) {
    Map<String, String> searchIndex = {};
    for (var cliente in listaClientes) {
      final lowerNome = cliente.nomcli.toLowerCase();
      final lowerTel = cliente.numtel001.toLowerCase();
      final lowerEnd = cliente.endcli.toLowerCase();
      final lowerBairro = cliente.baicli.toLowerCase();
      final lowerMun = cliente.muncli.toLowerCase();
      searchIndex[cliente.codcli.toString()] = 
          '$lowerNome $lowerTel $lowerEnd $lowerBairro $lowerMun ${cliente.codcli}';
    }
    clienteSearchIndex = searchIndex;
  }

  // --- MÉTODOS PARA GERENCIAMENTO DO BANCO LOCAL DE CLIENTES ---
  Future<void> _handleClearAllData() async {/* ... seu código ... */}

  // --- MÉTODOS PARA UI ---
  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _mostrarDialogoCarregamento({required String mensagem}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                    child: Text(
                  mensagem,
                  style: const TextStyle(fontSize: 16),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  void filtrarClientes(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final String termoBusca = query.toLowerCase().trim();
      if (!mounted) return;
      setState(() {
        if (termoBusca.isEmpty) {
          clientesFiltrados = clientes;
        } else {
          clientesFiltrados = clientes.where((cliente) {
            final searchText = clienteSearchIndex[cliente.codcli.toString()] ?? '';
            return searchText.contains(termoBusca);
          }).toList();
        }
      });
    });
  }

  String _getFriendlyErrorMessage(dynamic error) {
    String message = error.toString();
    if (message.contains('DatabaseException') || message.contains('SQLException')) {
      return 'Erro no banco de dados local.';
    } else if (message.contains('FormatException')) {
      return 'Erro de formato de dados.';
    } else if (message.contains('SocketException') ||
        message.contains('HandshakeException') ||
        message.contains('TimeoutException') ||
        message.contains('ClientException')) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    return message.length > 150 ? "${message.substring(0, 150)}..." : message;
  }

  // Método para mostrar o diálogo com todos os pedidos pendentes
  void _mostrarDialogoPedidosPendentes() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          clipBehavior: Clip.antiAliasWithSaveLayer,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: primaryColor,
                  width: double.infinity,
                  child: Row(
                    children: [
                      const Icon(Icons.sync_problem, color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        "Pedidos Pendentes ($_pedidosPendentesCount)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: 'Fechar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                if (_isSendingPedidos)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          "Enviando pedidos...",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_listaUiPedidosPendentes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.green[400]),
                        const SizedBox(height: 16),
                        Text(
                          "Nenhum pedido pendente",
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _listaUiPedidosPendentes.length,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemBuilder: (context, index) {
                        final pedidoPendente = _listaUiPedidosPendentes[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          elevation: 2.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              "Pedido: ${pedidoPendente['codigoPedidoApp']}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  "Cliente: ${pedidoPendente['nomeCliente']}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${pedidoPendente['dataCriacao']}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.sync_problem_outlined,
                                      size: 12,
                                      color: warningColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${pedidoPendente['statusEnvio']}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: warningColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_pedidosPendentesCount > 0 && !_isSendingPedidos)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _mostrarDialogoConfirmacaoEnvio,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(
                          "Enviar $_pedidosPendentesCount Pedido(s)",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS DE UI (build e os _build...) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: AppDrawer(
        clearAllTables: _handleClearAllData,
        syncAllTables: () => _sincronizarDados(mostrarUI: true),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _logger.i("HomeScreen: RefreshIndicator - Sincronizando e recarregando...");
                  await _sincronizarDados(mostrarUI: true);
                },
                color: primaryColor,
                child: _buildMainContent(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_pedidosPendentesCount <= 0) return null;
    
    return FloatingActionButton(
      onPressed: _mostrarDialogoPedidosPendentes,
      backgroundColor: primaryColor,
      elevation: 4,
      tooltip: 'Ver Pedidos Pendentes',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.receipt_long, color: Colors.white),
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$_pedidosPendentesCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "DuoSig Vendas",
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: primaryColor,
      elevation: 2,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (_pedidosPendentesCount > 0)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: 'Ver Pedidos Pendentes',
                onPressed: _mostrarDialogoPedidosPendentes,
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$_pedidosPendentesCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Sincronizar Dados',
          onPressed: isSyncing || _isSendingPedidos
              ? null
              : () => _sincronizarDados(mostrarUI: true),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Pesquisar cliente por nome, código, telefone...',
          hintStyle: TextStyle(fontSize: 15, color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey[700]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20, color: Colors.grey[700]),
                  onPressed: () {
                    _searchController.clear();
                    filtrarClientes('');
                    _searchFocus.unfocus();
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 15.0),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
        style: const TextStyle(fontSize: 16),
        onChanged: filtrarClientes,
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading && clientes.isEmpty) {
      return _buildLoadingState(mensagem: "Carregando dados...");
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Título para Lista de Clientes
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, color: Colors.grey[800], size: 20),
                const SizedBox(width: 8),
                Text(
                  "Clientes",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (clientesFiltrados.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${clientesFiltrados.length}",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Lista de Clientes
        if (isLoading && clientes.isEmpty)
          SliverFillRemaining(
            child: _buildLoadingState(mensagem: "Carregando clientes..."),
          )
        else if (hasError)
          SliverFillRemaining(
            child: _buildErrorState(),
          )
        else if (clientesFiltrados.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(
              isPesquisaAtiva: _searchController.text.isNotEmpty,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 80), // Espaço para o FAB
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: ClientePerfil(cliente: clientesFiltrados[index]),
                  );
                },
                childCount: clientesFiltrados.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState({String mensagem = 'Carregando...'}) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: errorColor,
                size: 50
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro ao Carregar Dados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[850],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                )
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Tentar Novamente',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              onPressed: () {
                carregarClientesLocal();
                _carregarPedidosPendentes();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isPesquisaAtiva = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPesquisaAtiva ? Icons.search_off_rounded : Icons.people_alt_outlined,
                size: 50,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPesquisaAtiva ? 'Nenhum cliente encontrado' : 'Nenhum cliente cadastrado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[850],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isPesquisaAtiva
                  ? 'Verifique os termos da sua pesquisa.'
                  : 'Comece adicionando seus clientes ou sincronize os dados.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!isPesquisaAtiva)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.sync_rounded, size: 20),
                label: const Text(
                  'Sincronizar Agora',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                onPressed: () => _sincronizarDados(mostrarUI: true),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.clear_rounded, size: 20),
                label: const Text(
                  'Limpar Pesquisa',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                onPressed: () {
                  _searchController.clear();
                  filtrarClientes('');
                  _searchFocus.unfocus();
                },
              ),
          ],
        ),
      ),
    );
  }
}