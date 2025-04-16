import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/screens/carrinhoscreen.dart';

// Classe para acessar os dados de clientes
class ClienteRepository {
  final ClienteDao _clienteDao = ClienteDao();
  
  Future<List<Cliente>> getClientes() async {
    try {
      return await _clienteDao.getAll((json) => Cliente.fromJson(json));
    } catch (e) {
      debugPrint('Erro ao buscar clientes: $e');
      return [];
    }
  }
}

class ClientesComCarrinhoScreen extends StatefulWidget {
  const ClientesComCarrinhoScreen({super.key});

  @override
  State<ClientesComCarrinhoScreen> createState() => _ClientesComCarrinhoScreenState();
}

class _ClientesComCarrinhoScreenState extends State<ClientesComCarrinhoScreen> {
  final CarrinhoDao _carrinhoDao = CarrinhoDao();
  final ClienteRepository _clienteRepository = ClienteRepository();
  final Logger _logger = Logger();
  
  // Constantes
  final Color primaryColor = const Color(0xFF5D5CDE);
  
  // Estado
  List<Cliente> _clientesComCarrinho = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _carregarClientesComCarrinhoAberto();
  }

  Future<void> _carregarClientesComCarrinhoAberto() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Primeiro, carrega todos os clientes
      List<Cliente> todosClientes = await _clienteRepository.getClientes();
      _logger.d("Carregados ${todosClientes.length} clientes");
      
      // Lista para armazenar clientes com carrinho aberto
      List<Cliente> clientesComCarrinho = [];
      
      // Para cada cliente, verifica se tem carrinho não finalizado
      for (var cliente in todosClientes) {
        List<CarrinhoItem> itensCarrinho = 
            await _carrinhoDao.getItensCliente(cliente.codcli, apenasNaoFinalizados: true);
        
        if (itensCarrinho.isNotEmpty) {
          clientesComCarrinho.add(cliente);
          _logger.d("Cliente ${cliente.nomcli} tem ${itensCarrinho.length} itens no carrinho");
        }
      }
      
      if (mounted) {
        setState(() {
          _clientesComCarrinho = clientesComCarrinho;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e("Erro ao carregar clientes com carrinho: $e");
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    String message = error.toString();

    if (message.contains('DatabaseException') ||
        message.contains('SQLException')) {
      return 'Erro no banco de dados local';
    } else if (message.contains('FormatException')) {
      return 'Erro de formato de dados';
    }

    return 'Erro ao carregar clientes: $message';
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _carregarClientesComCarrinhoAberto,
        color: primaryColor,
        child: _buildMainContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Clientes com Carrinho",
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar',
          onPressed: _carregarClientesComCarrinhoAberto,
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_hasError) {
      return _buildErrorState();
    }

    if (_clientesComCarrinho.isEmpty) {
      return _buildEmptyState();
    }

    return _buildClientesList();
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
              _errorMessage,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              onPressed: _carregarClientesComCarrinhoAberto,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum cliente com carrinho aberto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Os clientes aparecerão aqui quando tiverem itens em seus carrinhos',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientesList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _clientesComCarrinho.length,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final cliente = _clientesComCarrinho[index];
        return _buildClienteCard(cliente);
      },
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    // Função para obter as iniciais do nome do cliente
    String getInitials(String name) {
      if (name.isEmpty) return '?';
      List<String> names = name.split(' ');
      if (names.length == 1) {
        return names[0].substring(0, 1).toUpperCase();
      }
      return names[0].substring(0, 1).toUpperCase() + 
             (names.length > 1 ? names[1].substring(0, 1).toUpperCase() : '');
    }

    // Formatar telefone para exibição
    String formatarTelefone(String telefone) {
      if (telefone.isEmpty) return 'Não informado';
      
      // Limpa qualquer formatação existente
      telefone = telefone.replaceAll(RegExp(r'\D'), '');
      
      if (telefone.length <= 8) {
        return telefone;
      } else if (telefone.length == 9) {
        return '${telefone.substring(0, 5)}-${telefone.substring(5)}';
      } else if (telefone.length == 10) {
        return '(${telefone.substring(0, 2)}) ${telefone.substring(2, 6)}-${telefone.substring(6)}';
      } else if (telefone.length == 11) {
        return '(${telefone.substring(0, 2)}) ${telefone.substring(2, 7)}-${telefone.substring(7)}';
      }
      
      return telefone;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CarrinhoScreen(
                cliente: cliente,
                codcli: cliente.codcli,
              ),
            ),
          ).then((_) {
            _carregarClientesComCarrinhoAberto();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Avatar com iniciais
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Text(
                  getInitials(cliente.nomcli),
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Informações do cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nomcli,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${cliente.codcli}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      formatarTelefone(cliente.numtel001),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Ícone de carrinho
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_cart,
                  color: primaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}