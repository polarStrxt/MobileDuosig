import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/perfilCriente.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/apiCliente.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/widgets/app_drawer.dart';
import 'package:flutter_docig_venda/services/sincronizacao.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Constantes
  final Color primaryColor = Color(0xFF5D5CDE);

  // Estado da lista
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  Map<String, String> clienteSearchIndex = {};

  // Estado de carregamento
  bool isLoading = true;
  bool isSyncing = false;
  double syncProgress = 0.0;
  String syncStatus = '';
  bool hasError = false;
  String errorMessage = '';

  // Controllers
  final ClienteDao _clienteDao = ClienteDao();
  final SyncService _syncService = SyncService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;
  Function(double, String)? _updateDialogUI;

  @override
  void initState() {
    super.initState();
    carregarClientesLocal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // MÉTODOS DE CARREGAMENTO DE DADOS

  Future<void> carregarClientesLocal() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      List<Cliente> listaLocal =
          await _clienteDao.getAll((json) => Cliente.fromJson(json));
      _buildSearchIndex(listaLocal);

      setState(() {
        clientes = listaLocal;
        clientesFiltrados = listaLocal;
        isLoading = false;
      });

      if (listaLocal.isEmpty) {
        sincronizarComAPI();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage =
            "Erro ao buscar dados locais: ${_getFriendlyErrorMessage(e)}";
      });
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

  // MÉTODOS DE SINCRONIZAÇÃO

  Future<void> sincronizarComAPI() async {
    if (isSyncing) {
      _mostrarSnackBar('Sincronização em andamento', Colors.black87);
      return;
    }

    setState(() {
      isSyncing = true;
    });

    _mostrarDialogoCarregamento(mensagem: 'Sincronizando dados dos clientes');

    try {
      List<Cliente> listaAPI = await ClienteService.buscarClientes();

      for (var cliente in listaAPI) {
        await _clienteDao.insertOrUpdate(cliente.toJson(), 'codcli');
      }

      Navigator.of(context).pop();

      List<Cliente> listaAtualizada =
          await _clienteDao.getAll((json) => Cliente.fromJson(json));
      _buildSearchIndex(listaAtualizada);

      setState(() {
        clientes = listaAtualizada;
        clientesFiltrados = listaAtualizada;
        isSyncing = false;
      });

      _mostrarSnackBar(
          '${listaAPI.length} clientes sincronizados', primaryColor);
    } catch (e) {
      Navigator.of(context).pop();
      setState(() {
        isSyncing = false;
      });

      _mostrarSnackBar('Erro na sincronização: ${_getFriendlyErrorMessage(e)}',
          Colors.red[700]!);
    }
  }

  Future<void> _handleSyncAllTables() async {
    if (isSyncing) {
      _mostrarSnackBar('Sincronização em andamento', Colors.black87);
      return;
    }

    setState(() {
      isSyncing = true;
      syncProgress = 0.0;
      syncStatus = 'Verificando conexão';
    });

    _mostrarDialogoProgressivo();

    try {
      bool hasInternet = await _syncService.hasInternetConnection();
      if (!hasInternet) {
        Navigator.of(context).pop();
        setState(() {
          isSyncing = false;
          _updateDialogUI = null;
        });
        _mostrarSnackBar('Sem conexão com a internet', Colors.red[700]!);
        return;
      }

      _atualizarProgresso(0.25, 'Sincronizando dados');

      final results = await _syncWithTimeout();

      _atualizarProgresso(1.0, 'Concluído');
      await Future.delayed(Duration(milliseconds: 300));

      Navigator.of(context).pop();

      await carregarClientesLocal();

      setState(() {
        isSyncing = false;
        _updateDialogUI = null;
      });

      if (results != null && results.isNotEmpty) {
        int totalRegistros =
            results.values.fold(0, (sum, value) => sum + value);
        _mostrarSnackBar(
            'Sincronização concluída: $totalRegistros registros', primaryColor);
      } else {
        _mostrarSnackBar('Sincronização concluída', primaryColor);
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      setState(() {
        isSyncing = false;
        _updateDialogUI = null;
      });

      _mostrarSnackBar(
          'Erro: ${_getFriendlyErrorMessage(e)}', Colors.red[700]!);
    }
  }

  Future<Map<String, int>?> _syncWithTimeout() async {
    try {
      return await Future.any([
        _syncService.syncAllData(),
        Future.delayed(Duration(minutes: 2), () {
          throw TimeoutException('Tempo limite excedido');
        }),
      ]);
    } on TimeoutException {
      throw TimeoutException('A sincronização excedeu o tempo limite');
    }
  }

  Future<void> _handleClearAllTables() async {
    bool confirmar = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirmação'),
              content: Text(
                  'Deseja realmente limpar todas as tabelas? Esta ação não pode ser desfeita.'),
              actions: [
                TextButton(
                  child: Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Confirmar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmar) return;

    try {
      _mostrarDialogoCarregamento(mensagem: 'Limpando tabelas');

      await _syncService.clearAllTables();

      Navigator.of(context).pop();

      setState(() {
        clientes = [];
        clientesFiltrados = [];
      });

      _mostrarSnackBar('Dados removidos com sucesso', primaryColor);
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _mostrarSnackBar('Erro ao limpar tabelas', Colors.red[700]!);
    }
  }

  // MÉTODOS PARA UI

  void _atualizarProgresso(double progress, String status) {
    setState(() {
      syncProgress = progress;
      syncStatus = status;
    });

    if (_updateDialogUI != null) {
      _updateDialogUI!(progress, status);
    }
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _mostrarDialogoCarregamento({required String mensagem}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Expanded(child: Text(mensagem)),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoProgressivo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateDialog(double progress, String status) {
              setDialogState(() {
                syncProgress = progress;
                syncStatus = status;
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _updateDialogUI = updateDialog);
            });

            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(syncStatus,
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: syncProgress > 0 ? syncProgress : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void filtrarClientes(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      final String termoBusca = query.toLowerCase().trim();

      setState(() {
        if (termoBusca.isEmpty) {
          clientesFiltrados = clientes;
        } else {
          clientesFiltrados = clientes.where((cliente) {
            final searchText =
                clienteSearchIndex[cliente.codcli.toString()] ?? '';
            return searchText.contains(termoBusca);
          }).toList();
        }
      });
    });
  }

  String _getFriendlyErrorMessage(dynamic error) {
    String message = error.toString();

    if (message.contains('SocketException') ||
        message.contains('NetworkError')) {
      return 'Falha na conexão de internet';
    } else if (message.contains('timeout') ||
        message.contains('TimeoutException')) {
      return 'Operação excedeu o tempo limite';
    } else if (message.contains('API') || message.contains('Server')) {
      return 'Erro no servidor';
    }

    return message;
  }

  // WIDGETS DE UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      drawer: AppDrawer(
        clearAllTables: _handleClearAllTables,
        syncAllTables: _handleSyncAllTables,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          Expanded(
            child: RefreshIndicator(
              onRefresh: carregarClientesLocal,
              color: primaryColor,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Clientes",
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        // Indicador de sincronização
        if (isSyncing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(Icons.sync),
            tooltip: 'Sincronizar',
            onPressed: sincronizarComAPI,
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: 'Pesquisar cliente',
          prefixIcon: Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    filtrarClientes('');
                    _searchFocus.unfocus();
                  },
                )
              : null,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: primaryColor),
          ),
        ),
        style: TextStyle(fontSize: 16),
        onChanged: filtrarClientes,
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (hasError) {
      return _buildErrorState();
    }

    if (clientesFiltrados.isEmpty) {
      return _buildEmptyState();
    }

    return _buildClientList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando',
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 48),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar dados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Tentar novamente'),
              onPressed: carregarClientesLocal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isPesquisaAtiva = _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPesquisaAtiva ? Icons.search_off : Icons.people_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              isPesquisaAtiva
                  ? 'Nenhum cliente encontrado'
                  : 'Nenhum cliente cadastrado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              isPesquisaAtiva
                  ? 'Tente outros termos de pesquisa'
                  : 'Sincronize para carregar os clientes',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(isPesquisaAtiva ? Icons.clear : Icons.sync),
              label: Text(isPesquisaAtiva ? 'Limpar pesquisa' : 'Sincronizar'),
              onPressed: isPesquisaAtiva
                  ? () {
                      _searchController.clear();
                      filtrarClientes('');
                      _searchFocus.unfocus();
                    }
                  : sincronizarComAPI,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: clientesFiltrados.length,
      padding: EdgeInsets.only(top: 8, bottom: 20),
      itemBuilder: (context, index) {
        return ClientePerfil(cliente: clientesFiltrados[index]);
      },
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
