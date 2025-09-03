import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/presentation/widgets/perfilCriente.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/presentation/widgets/app_drawer.dart';
import 'package:flutter_docig_venda/services/sync_service.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
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
  static const Color errorColor = Color(0xFFE03F3F);
  static const Color warningColor = Color(0xFFE0A030);
  
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      // Corrigido: removido printTime deprecated
    ),
  );

  // Repositories (substituindo DAOs)
  late final RepositoryManager _repositories;
  late final ClienteRepository _clienteRepository;
  late final PedidosParaEnvioRepository _pedidosRepository;

  // Estado da lista de clientes
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  Map<String, String> clienteSearchIndex = {};

  // Estado de carregamento e sincronização
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isSyncing = false;

  // Estado para pedidos pendentes
  int _pedidosPendentesCount = 0;
  bool _isSendingPedidos = false;
  List<Map<String, dynamic>> _listaUiPedidosPendentes = [];

  // Controllers e Timers
  final SyncService _syncService = SyncService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();
  
  // Cache de busca para melhor performance
  final Map<String, List<Cliente>> _searchCache = {};
  static const int _maxCacheSize = 50;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  void _initializeRepositories() {
    final dbHelper = DatabaseHelper.instance;
    _repositories = RepositoryManager(dbHelper);
    _clienteRepository = _repositories.clientes;
    _pedidosRepository = _repositories.pedidosParaEnvio;
  }

  Future<void> _initializeData() async {
    _logger.i("HomeScreen: Inicializando dados...");
    
    // Carrega clientes primeiro
    await carregarClientesLocal();
    
    // Se não há clientes, tenta sincronizar
    if (clientes.isEmpty && mounted) {
      _logger.i("HomeScreen: Sem clientes locais, iniciando sincronização...");
      await _sincronizarDados(mostrarUI: false);
    }
    
    // Carrega pedidos pendentes
    if (mounted) {
      await _carregarPedidosPendentes();
    }
  }

  @override
  void dispose() {
    _logger.i("HomeScreen: Limpando recursos...");
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _searchCache.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _logger.i("HomeScreen: App resumido, recarregando pedidos...");
      _carregarPedidosPendentes();
    }
  }

  // ========== MÉTODOS DE PEDIDOS ==========
  
  Future<void> _carregarPedidosPendentes() async {
    if (!mounted) return;
    
    try {
      // Usa o repository em vez do DAO
      final pendentesDoBanco = await _pedidosRepository.getPendentesParaEnvio();
      final List<Map<String, dynamic>> novaListaUi = [];

      for (var pedidoLocal in pendentesDoBanco) {
        String nomeCliente = "Cliente Desconhecido";
        
        try {
          final codClienteStr = pedidoLocal.jsonDoPedido['cod_cliente']?.toString();
          
          if (codClienteStr != null && codClienteStr.isNotEmpty) {
            final codCli = int.parse(codClienteStr);
            
            // Busca cliente na lista em memória (mais rápido)
            final cliente = clientes.firstWhere(
              (c) => c.codcli == codCli,
              orElse: () => Cliente.empty(),
            );
            
            if (cliente.codcli != 0) {
              nomeCliente = cliente.nomcli;
            }
          }
        } catch (e) {
          _logger.e("Erro ao buscar cliente do pedido: $e");
        }

        novaListaUi.add({
          'codigoPedidoApp': pedidoLocal.codigoPedidoApp,
          'nomeCliente': nomeCliente,
          'dataCriacao': DateFormat('dd/MM/yy HH:mm').format(pedidoLocal.dataCriacao),
          'statusEnvio': pedidoLocal.statusEnvio,
          'objetoOriginal': pedidoLocal,
        });
      }

      if (mounted) {
        setState(() {
          _pedidosPendentesCount = novaListaUi.length;
          _listaUiPedidosPendentes = novaListaUi;
        });
      }
    } catch (e, s) {
      _logger.e("Erro ao carregar pedidos pendentes", error: e, stackTrace: s);
      if (mounted) {
        _mostrarSnackBar('Erro ao carregar pedidos pendentes', errorColor);
      }
    }
  }

  Future<void> _processarEnvioDePedidos() async {
    if (_isSendingPedidos) return;

    if (!mounted) return;
    setState(() => _isSendingPedidos = true);

    _mostrarDialogoCarregamento(mensagem: 'Enviando pedidos...');

    try {
      final pedidos = await _pedidosRepository.getPendentesParaEnvio();
      
      if (pedidos.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          _mostrarSnackBar('Nenhum pedido pendente', primaryColor);
        }
        return;
      }

      int sucessos = 0;
      int falhas = 0;

      for (var pedido in pedidos) {
        if (pedido.idPedidoLocal == null) continue;

        try {
          final response = await http
              .post(
                Uri.parse('http://duotecsuprilev.ddns.com.br:8082/v1/pedido'),
                headers: {'Content-Type': 'application/json; charset=UTF-8'},
                body: jsonEncode(pedido.jsonDoPedido),
              )
              .timeout(const Duration(seconds: 45));

          if (response.statusCode == 200 || response.statusCode == 201) {
            // CORRIGIDO: Usa o método correto para deletar pedido
            await _pedidosRepository.deletePedidoPorId(pedido.idPedidoLocal!);
            sucessos++;
            _logger.i("Pedido ${pedido.codigoPedidoApp} enviado com sucesso");
          } else {
            falhas++;
            _logger.w("Falha ao enviar pedido ${pedido.codigoPedidoApp}: ${response.statusCode}");
          }
        } catch (e) {
          _logger.e("Erro ao enviar pedido ${pedido.codigoPedidoApp}: $e");
          falhas++;
        }
      }

      if (mounted) {
        Navigator.pop(context);
        
        String msg;
        Color cor;
        
        if (sucessos > 0 && falhas == 0) {
          msg = "$sucessos pedido(s) enviado(s)!";
          cor = Colors.green;
        } else if (sucessos > 0 && falhas > 0) {
          msg = "$sucessos enviado(s), $falhas falharam";
          cor = warningColor;
        } else {
          msg = "$falhas pedido(s) falharam";
          cor = errorColor;
        }
        
        _mostrarSnackBar(msg, cor);
      }
    } catch (e, s) {
      _logger.e("Erro no processamento de envio de pedidos", error: e, stackTrace: s);
      if (mounted) {
        Navigator.pop(context);
        _mostrarSnackBar('Erro ao processar envio', errorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingPedidos = false);
        await _carregarPedidosPendentes();
      }
    }
  }

  // ========== MÉTODOS DE CLIENTES ==========
  
  Future<void> carregarClientesLocal() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Usa o repository em vez do DAO
      final listaLocal = await _clienteRepository.getAll();
      _buildSearchIndex(listaLocal);

      if (mounted) {
        setState(() {
          clientes = listaLocal;
          clientesFiltrados = listaLocal;
          isLoading = false;
        });
      }
      
      _logger.i("${listaLocal.length} clientes carregados do banco local");
    } catch (e, s) {
      _logger.e("Erro ao carregar clientes", error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = "Erro ao carregar clientes";
        });
      }
    }
  }

  void _buildSearchIndex(List<Cliente> listaClientes) {
    clienteSearchIndex.clear();
    for (var cliente in listaClientes) {
      final searchText = '${cliente.nomcli} ${cliente.numtel001} ${cliente.endcli} '
          '${cliente.baicli} ${cliente.muncli} ${cliente.codcli}'
          .toLowerCase();
      clienteSearchIndex[cliente.codcli.toString()] = searchText;
    }
    _logger.d("Índice de busca construído para ${listaClientes.length} clientes");
  }

  void filtrarClientes(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final termo = query.toLowerCase().trim();
      
      if (!mounted) return;
      
      // Verifica cache primeiro
      if (_searchCache.containsKey(termo)) {
        setState(() {
          clientesFiltrados = _searchCache[termo]!;
        });
        return;
      }
      
      setState(() {
        if (termo.isEmpty) {
          clientesFiltrados = clientes;
        } else {
          clientesFiltrados = clientes.where((cliente) {
            final searchText = clienteSearchIndex[cliente.codcli.toString()] ?? '';
            return searchText.contains(termo);
          }).toList();
          
          // Adiciona ao cache
          if (_searchCache.length >= _maxCacheSize) {
            _searchCache.remove(_searchCache.keys.first);
          }
          _searchCache[termo] = clientesFiltrados;
        }
      });
    });
  }

  // ========== SINCRONIZAÇÃO ==========
  
  Future<void> _sincronizarDados({bool mostrarUI = true}) async {
    if (isSyncing) return;

    if (mounted && mostrarUI) {
      setState(() => isSyncing = true);
      _mostrarDialogoCarregamento(mensagem: 'Sincronizando dados...');
    }

    try {
      final conexao = await _syncService.verificarConexaoInternet();
      
      if (!conexao.isSuccess || !(conexao.data ?? false)) {
        if (mounted && mostrarUI) {
          Navigator.pop(context);
          _mostrarSnackBar('Sem conexão com a internet', warningColor);
        }
        return;
      }

      final result = await _syncService.sincronizarTodosDados();
      
      if (mounted && mostrarUI) {
        Navigator.pop(context);
      }

      if (result.isSuccess) {
        await carregarClientesLocal();
        if (mounted && mostrarUI) {
          _mostrarSnackBar(
            'Sincronização concluída: ${result.totalCount} registros',
            primaryColor
          );
        }
        _logger.i("Sincronização concluída com sucesso: ${result.totalCount} registros");
      } else {
        if (mounted && mostrarUI) {
          _mostrarSnackBar('Erro na sincronização: ${result.errorMessage}', errorColor);
        }
        _logger.w("Falha na sincronização: ${result.errorMessage}");
      }
    } catch (e, s) {
      _logger.e("Erro na sincronização", error: e, stackTrace: s);
      if (mounted && mostrarUI) {
        Navigator.pop(context);
        _mostrarSnackBar('Erro na sincronização', errorColor);
      }
    } finally {
      if (mounted) {
        if (mostrarUI) setState(() => isSyncing = false);
        await _carregarPedidosPendentes();
      }
    }
  }

  // ========== MÉTODOS DE UI ==========
  
  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: cor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(12),
        ),
      );
  }

  void _mostrarDialogoCarregamento({required String mensagem}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 24),
            Expanded(child: Text(mensagem)),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoConfirmacaoEnvio() {
    if (_pedidosPendentesCount == 0) {
      _mostrarSnackBar('Nenhum pedido para enviar', primaryColor);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Envio'),
        content: Text('Enviar $_pedidosPendentesCount pedido(s) pendente(s)?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processarEnvioDePedidos();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPedidosPendentes() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sync_problem, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Pedidos Pendentes ($_pedidosPendentesCount)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Content
              if (_listaUiPedidosPendentes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                      SizedBox(height: 16),
                      Text('Nenhum pedido pendente'),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _listaUiPedidosPendentes.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final pedido = _listaUiPedidosPendentes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text('Pedido: ${pedido['codigoPedidoApp']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Cliente: ${pedido['nomeCliente']}'),
                              Text('Data: ${pedido['dataCriacao']}'),
                              Text('Status: ${pedido['statusEnvio']}'),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              
              // Actions
              if (_pedidosPendentesCount > 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingPedidos ? null : () {
                        Navigator.pop(context);
                        _mostrarDialogoConfirmacaoEnvio();
                      },
                      icon: _isSendingPedidos 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        _isSendingPedidos
                            ? 'Enviando...'
                            : 'Enviar $_pedidosPendentesCount Pedido(s)',
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
      ),
    );
  }

  // ========== BUILD METHODS ==========
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      drawer: AppDrawer(
        clearAllTables: () async {
          try {
            // Implementar limpeza usando repositories
            await _repositories.limparTodosDados();
            await carregarClientesLocal();
            await _carregarPedidosPendentes();
            _mostrarSnackBar('Dados limpos com sucesso', primaryColor);
          } catch (e) {
            _logger.e("Erro ao limpar dados", error: e);
            _mostrarSnackBar('Erro ao limpar dados', errorColor);
          }
        },
        syncAllTables: () => _sincronizarDados(mostrarUI: true),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _sincronizarDados(mostrarUI: true),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'DuoSig Vendas',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
      ),
      backgroundColor: primaryColor,
      elevation: 2,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (_pedidosPendentesCount > 0)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: _mostrarDialogoPedidosPendentes,
                tooltip: 'Pedidos pendentes',
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
          icon: Icon(isSyncing ? Icons.sync : Icons.sync),
          onPressed: isSyncing ? null : () => _sincronizarDados(mostrarUI: true),
          tooltip: 'Sincronizar dados',
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Pesquisar cliente...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    filtrarClientes('');
                  },
                )
              : null,
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
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
        onChanged: filtrarClientes,
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading && clientes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando clientes...'),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: carregarClientesLocal,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            ),
          ],
        ),
      );
    }

    if (clientesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Nenhum cliente cadastrado'
                  : 'Nenhum cliente encontrado',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (_searchController.text.isEmpty)
              const Text(
                'Sincronize os dados para carregar clientes',
                style: TextStyle(color: Colors.grey),
              )
            else
              const Text(
                'Tente outro termo de busca',
                style: TextStyle(color: Colors.grey),
              ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _sincronizarDados(mostrarUI: true),
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: clientesFiltrados.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ClientePerfil(cliente: clientesFiltrados[index]),
        );
      },
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_pedidosPendentesCount <= 0) return null;
    
    return FloatingActionButton.extended(
      onPressed: _mostrarDialogoPedidosPendentes,
      backgroundColor: primaryColor,
      icon: const Icon(Icons.receipt_long, color: Colors.white),
      label: Text(
        '$_pedidosPendentesCount',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      tooltip: 'Ver pedidos pendentes',
    );
  }
}