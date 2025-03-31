import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/perfilCriente.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/apiCliente.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/dao/duplicata_dao.dart';
import 'package:flutter_docig_venda/widgets/app_drawer.dart';
// Adicione a importação do SyncService
import 'package:flutter_docig_venda/services/sincronizacao.dart'; // Ajuste o caminho de importação conforme necessário

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Cliente> clientes = [];
  List<Cliente> clientesFiltrados = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isSyncing = false;

  // Instância do DAO para acessar dados locais
  final ClienteDao _clienteDao = ClienteDao();

  // Adicione a instância do SyncService
  final SyncService _syncService = SyncService();

  // Controlador para o campo de pesquisa
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    carregarClientesLocal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // IMPORTANTE: Método modificado para garantir que erros sejam tratados corretamente
  Future<void> _handleSyncAllTables() async {
    // Verificação de segurança para evitar múltiplas sincronizações
    if (isSyncing) {
      print("⚠️ Sincronização já em andamento, ignorando nova solicitação");
      return;
    }

    // Mostra um diálogo de carregamento para feedback visual imediato
    _mostrarCarregando("Sincronizando todas as tabelas...");

    try {
      setState(() {
        isSyncing = true;
      });

      // Verifica conexão com internet antes de prosseguir
      bool hasInternet = await _syncService.hasInternetConnection();
      if (!hasInternet) {
        // Fecha o diálogo de carregamento
        Navigator.of(context).pop();

        setState(() {
          isSyncing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Sem conexão com a internet. Verifique sua conexão e tente novamente.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Executa a sincronização com timeout de segurança
      final results = await _syncWithTimeout();

      // Fecha o diálogo de carregamento
      Navigator.of(context).pop();

      // Recarrega os dados do cliente após a sincronização
      await carregarClientesLocal();

      setState(() {
        isSyncing = false;
      });

      // Cria uma mensagem com os resultados
      if (results != null && results.isNotEmpty) {
        String mensagem = 'Sincronização concluída:\n';
        results.forEach((tabela, quantidade) {
          mensagem += '$tabela: $quantidade registros\n';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagem),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sincronização concluída com sucesso!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Fecha o diálogo de carregamento em caso de erro
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print("❌ Erro na sincronização: $e");

      setState(() {
        isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para evitar que a sincronização fique travada
  Future<Map<String, int>?> _syncWithTimeout() async {
    try {
      return await Future.any([
        _syncService.syncAllData(),
        Future.delayed(Duration(minutes: 2), () {
          throw TimeoutException('Tempo limite excedido na sincronização');
        }),
      ]);
    } on TimeoutException {
      throw TimeoutException(
          'A sincronização demorou muito tempo e foi cancelada. Tente novamente.');
    }
  }

  // Método para limpar todas as tabelas com tratamento de erros aprimorado
  Future<void> _handleClearAllTables() async {
    try {
      // Mostrar diálogo de carregamento
      _mostrarCarregando("Limpando todas as tabelas...");

      await _syncService.clearAllTables();

      // Fechar diálogo de carregamento
      Navigator.of(context).pop();

      // Recarregar a lista depois da limpeza
      setState(() {
        clientes = [];
        clientesFiltrados = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Todas as tabelas foram limpas com sucesso!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // Fechar diálogo de carregamento em caso de erro
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      print("❌ Erro ao limpar tabelas: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao limpar tabelas: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para carregar clientes do banco de dados local
  Future<void> carregarClientesLocal() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // Usar o DAO para buscar todos os clientes localmente
      List<Cliente> listaLocal =
          await _clienteDao.getAll((json) => Cliente.fromJson(json));

      setState(() {
        clientes = listaLocal;
        clientesFiltrados = listaLocal;
        isLoading = false;
      });

      // Se o banco estiver vazio, tenta sincronizar com a API
      if (listaLocal.isEmpty) {
        sincronizarComAPI();
      }
    } catch (e) {
      print("❌ Erro ao buscar clientes do banco local: $e");
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = "Erro ao buscar dados locais: $e";
      });
    }
  }

  // Método para sincronizar dados com a API e salvar localmente
  Future<void> sincronizarComAPI() async {
    if (isSyncing) return; // Evita múltiplas sincronizações simultâneas

    setState(() {
      isSyncing = true;
    });

    try {
      // Buscar da API
      List<Cliente> listaAPI = await ClienteService.buscarClientes();

      // Salvar no banco local
      for (var cliente in listaAPI) {
        await _clienteDao.insertOrUpdate(cliente.toJson(), 'codcli');
      }

      // Recarregar dados do banco local
      List<Cliente> listaAtualizada =
          await _clienteDao.getAll((json) => Cliente.fromJson(json));

      setState(() {
        clientes = listaAtualizada;
        clientesFiltrados = listaAtualizada;
        isSyncing = false;
      });

      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dados sincronizados com sucesso!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print("❌ Erro na sincronização: $e");
      setState(() {
        isSyncing = false;
        // Não mudar hasError para true, pois ainda temos dados locais
      });

      // Mostrar mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar dados: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para filtrar clientes com base no texto de pesquisa
  void filtrarClientes(String query) {
    final String termoBusca = query.toLowerCase().trim();

    setState(() {
      if (termoBusca.isEmpty) {
        clientesFiltrados = clientes;
      } else {
        clientesFiltrados = clientes.where((cliente) {
          return (cliente.nomcli.toLowerCase().contains(termoBusca)) ||
              (cliente.numtel001.toLowerCase().contains(termoBusca)) ||
              (cliente.endcli.toLowerCase().contains(termoBusca));
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Clientes"),
        backgroundColor: Color(0xFF5D5CDE),
        elevation: 0,
        actions: [
          // Botão para sincronizar com a API
          isSyncing
              ? Container(
                  padding: EdgeInsets.all(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.sync),
                  onPressed: sincronizarComAPI,
                  tooltip: 'Sincronizar com a API',
                ),

          // Botão para recarregar do banco local
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: carregarClientesLocal,
            tooltip: 'Atualizar lista local',
          ),
        ],
      ),
      // Usar o AppDrawer com os métodos de tratamento aprimorados
      drawer: AppDrawer(
        clearAllTables: _handleClearAllTables,
        syncAllTables: _handleSyncAllTables,
      ),
      body: Column(
        children: [
          // Barra de Pesquisa
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: 'Pesquisar cliente...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF5D5CDE)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          filtrarClientes('');
                          _searchFocus.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Color(0xFF5D5CDE), width: 1.5),
                ),
              ),
              style: TextStyle(fontSize: 16),
              onChanged: filtrarClientes,
            ),
          ),

          // Divisor entre a barra de pesquisa e a lista
          Divider(height: 1, thickness: 1, color: Colors.grey[300]),

          // Conteúdo principal
          Expanded(
            child: RefreshIndicator(
              onRefresh: carregarClientesLocal,
              color: Color(0xFF5D5CDE),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  // Método para mostrar diálogo de carregamento
  void _mostrarCarregando(String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
              ),
              SizedBox(width: 20),
              Text(mensagem),
            ],
          ),
        );
      },
    );
  }

  // Restante do código permanece inalterado...
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
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando clientes...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 60),
            SizedBox(height: 16),
            Text(
              'Erro ao carregar clientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Tentar banco local'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF5D5CDE),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: carregarClientesLocal,
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: Icon(Icons.sync),
                  label: Text('Sincronizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: sincronizarComAPI,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Mensagem diferente se há uma pesquisa ativa ou não
    final bool isPesquisaAtiva = _searchController.text.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 40),
        Icon(
          isPesquisaAtiva ? Icons.search_off : Icons.people_outline,
          size: 70,
          color: Colors.grey[400],
        ),
        SizedBox(height: 16),
        Text(
          isPesquisaAtiva
              ? 'Nenhum cliente encontrado'
              : 'Nenhum cliente no banco de dados local',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            isPesquisaAtiva
                ? 'Não encontramos nenhum cliente com os termos da sua pesquisa.'
                : 'O banco de dados local está vazio. Tente sincronizar com a API.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPesquisaAtiva)
              TextButton.icon(
                icon: Icon(Icons.clear),
                label: Text('Limpar pesquisa'),
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF5D5CDE),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  _searchController.clear();
                  filtrarClientes('');
                  _searchFocus.unfocus();
                },
              ),
            if (!isPesquisaAtiva)
              ElevatedButton.icon(
                icon: Icon(Icons.sync),
                label: Text('Sincronizar com API'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5D5CDE),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: sincronizarComAPI,
              ),
          ],
        ),
      ],
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

// Classe para lidar com o timeout
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
