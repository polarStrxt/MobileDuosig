import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/perfilCriente.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/widgets/app_drawer.dart';
import 'package:flutter_docig_venda/services/Sincronizacao.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Constantes
  final Color primaryColor = const Color(0xFF5D5CDE);

  // Estado da lista
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  Map<String, String> clienteSearchIndex = {};

  // Estado de carregamento
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isSyncing = false;

  // Controllers
  final ClienteDao _clienteDao = ClienteDao();
  final SyncService _syncService = SyncService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Inicia a sincronização e depois carrega os dados locais
    _sincronizarDados(mostrarUI: false).then((_) => carregarClientesLocal());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // MÉTODOS DE CARREGAMENTO E SINCRONIZAÇÃO DE DADOS

  Future<void> _sincronizarDados({bool mostrarUI = true}) async {
    if (isSyncing) return; // Evita múltiplas sincronizações simultâneas
    
    // Se for para mostrar na UI, exibe diálogo de progresso
    if (mostrarUI) {
      setState(() {
        isSyncing = true;
      });
      _mostrarDialogoCarregamento(mensagem: 'Sincronizando dados com o servidor...');
    }

    try {
      // Verifica conexão com a internet primeiro
      final conexaoResult = await _syncService.verificarConexaoInternet();
      
      if (!conexaoResult.isSuccess || !conexaoResult.data!) {
        if (mostrarUI) {
          if (!mounted) return;
          Navigator.of(context).pop(); // Fecha o diálogo
          _mostrarSnackBar(
            'Sem conexão com a internet. Usando dados locais.',
            Colors.orange[700]!
          );
        }
        return;
      }

      // Sincroniza todos os dados
      final syncResult = await _syncService.sincronizarTodosDados();

      if (mostrarUI && mounted) {
        Navigator.of(context).pop(); // Fecha o diálogo
      }

      if (syncResult.isSuccess) {
        if (mostrarUI && mounted) {
          _mostrarSnackBar(
            'Sincronização concluída: ${syncResult.totalCount} registros atualizados',
            primaryColor
          );
        }
      } else {
        if (mostrarUI && mounted) {
          _mostrarSnackBar(
            'Erro na sincronização: ${syncResult.errorMessage}',
            Colors.red[700]!
          );
        }
      }
    } catch (e) {
      if (mostrarUI && mounted) {
        Navigator.of(context).pop(); // Fecha o diálogo
        _mostrarSnackBar(
          'Erro durante a sincronização: ${_getFriendlyErrorMessage(e)}',
          Colors.red[700]!
        );
      }
    } finally {
      if (mostrarUI) {
        setState(() {
          isSyncing = false;
        });
      }
    }
    
    return; // Add explicit return statement
  }

  Future<void> carregarClientesLocal() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      List<Cliente> listaLocal =
          await _clienteDao.getAll((json) => Cliente.fromJson(json));
      _buildSearchIndex(listaLocal);

      if (mounted) {
        setState(() {
          clientes = listaLocal;
          clientesFiltrados = listaLocal;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage =
              "Erro ao buscar dados locais: ${_getFriendlyErrorMessage(e)}";
        });
      }
    }
    
    return; // Add explicit return statement
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

  // MÉTODOS PARA GERENCIAMENTO DO BANCO LOCAL

  Future<void> _handleUpdateCliente(Cliente cliente) async {
    try {
      _mostrarDialogoCarregamento(mensagem: 'Atualizando cliente');
      
      await _clienteDao.insertOrUpdate(cliente.toJson(), 'codcli');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o diálogo
      
      await carregarClientesLocal(); // Recarrega a lista
      
      if (mounted) {
        _mostrarSnackBar('Cliente atualizado com sucesso', primaryColor);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o diálogo
      _mostrarSnackBar('Erro ao atualizar cliente: ${_getFriendlyErrorMessage(e)}', 
          Colors.red[700]!);
    }
    
    return; // Add explicit return statement
  }

  Future<void> _handleDeleteCliente(String codcli) async {
    bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmação'),
              content: const Text(
                  'Deseja realmente excluir este cliente? Esta ação não pode ser desfeita.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Excluir'),
                ),
              ],
            );
          },
        );

    if (confirmar != true) return;

    try {
      _mostrarDialogoCarregamento(mensagem: 'Excluindo cliente');
      
      await _clienteDao.delete(codcli, 'codcli');
      
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o diálogo
      
      await carregarClientesLocal(); // Recarrega a lista
      
      if (mounted) {
        _mostrarSnackBar('Cliente excluído com sucesso', primaryColor);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Fecha o diálogo
      _mostrarSnackBar('Erro ao excluir cliente: ${_getFriendlyErrorMessage(e)}', 
          Colors.red[700]!);
    }
    
    return; // Add explicit return statement
  }

  Future<void> _handleClearAllData() async {
    bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmação'),
              content: const Text(
                  'Deseja realmente limpar todos os dados? Esta ação não pode ser desfeita.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );

    if (confirmar != true) return;

    try {
      _mostrarDialogoCarregamento(mensagem: 'Limpando dados');

      await _clienteDao.clearTable();

      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        clientes = [];
        clientesFiltrados = [];
      });

      _mostrarSnackBar('Dados removidos com sucesso', primaryColor);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _mostrarSnackBar('Erro ao limpar dados', Colors.red[700]!);
    }
    
    return; // Add explicit return statement to fix the error
  }

  // MÉTODOS PARA UI

  void _mostrarSnackBar(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(mensagem)),
            ],
          ),
        );
      },
    );
  }

  void filtrarClientes(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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

    if (message.contains('DatabaseException') ||
        message.contains('SQLException')) {
      return 'Erro no banco de dados local';
    } else if (message.contains('FormatException')) {
      return 'Erro de formato de dados';
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
        clearAllTables: _handleClearAllData,
        syncAllTables: () => _sincronizarDados(mostrarUI: true),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Divider(height: 1, thickness: 1, color: Colors.grey[200]),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Ao fazer pull-to-refresh, sincroniza e atualiza
                await _sincronizarDados(mostrarUI: true);
                await carregarClientesLocal();
              },
              color: primaryColor,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implementar a criação de um novo cliente
          // Você pode adicionar uma navegação para uma tela de cadastro
          _mostrarSnackBar('Função para adicionar clientes', primaryColor);
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Clientes",
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.sync),
          tooltip: 'Sincronizar',
          onPressed: () => _sincronizarDados(mostrarUI: true),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar dados locais',
          onPressed: carregarClientesLocal,
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
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
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
        style: const TextStyle(fontSize: 16),
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
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar dados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            Text(
              isPesquisaAtiva
                  ? 'Tente outros termos de pesquisa'
                  : 'Adicione seu primeiro cliente',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(isPesquisaAtiva ? Icons.clear : Icons.add),
              label: Text(isPesquisaAtiva ? 'Limpar pesquisa' : 'Adicionar cliente'),
              onPressed: isPesquisaAtiva
                  ? () {
                      _searchController.clear();
                      filtrarClientes('');
                      _searchFocus.unfocus();
                    }
                  : () {
                      // Implementar navegação para tela de cadastro
                      _mostrarSnackBar('Função para adicionar clientes', primaryColor);
                    },
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
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemBuilder: (context, index) {
        return ClientePerfil(cliente: clientesFiltrados[index]);
      },
    );
  }
}