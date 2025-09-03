import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart'; // Corrigido: nome do arquivo
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/presentation/screens/carrinhoScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart'; // Para RepositoryManager

class ClientesComCarrinhoScreen extends StatefulWidget {
  const ClientesComCarrinhoScreen({super.key});

  @override
  State<ClientesComCarrinhoScreen> createState() => _ClientesComCarrinhoScreenState();
}

class _ClientesComCarrinhoScreenState extends State<ClientesComCarrinhoScreen> {
  late final CarrinhoService _carrinhoService;
  final Logger _logger = Logger();
  
  final Color primaryColor = const Color(0xFF5D5CDE);
  
  List<Cliente> _clientesComCarrinho = []; // Corrigido: Usar ClienteModel consistentemente
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Correção: Inicializar CarrinhoService com RepositoryManager
    final repositoryManager = context.read<RepositoryManager>();
    _carrinhoService = CarrinhoService(repositoryManager: repositoryManager);
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final resultado = await _carrinhoService.getClientesComCarrinhosAbertos(); 
      
      if (!mounted) return;
      
      if (resultado.isSuccess && resultado.data != null) {
        setState(() {
          _clientesComCarrinho = resultado.data!;
          _isLoading = false;
        });
        _logger.d("Carregados ${_clientesComCarrinho.length} clientes com carrinho pendente");
      } else {
         setState(() {
           _hasError = true;
           _errorMessage = resultado.errorMessage ?? "Falha ao buscar clientes com carrinho.";
           _isLoading = false;
         });
         _logger.w("Falha ao carregar clientes com carrinho: $_errorMessage");
      }
    } catch (e) {
      _logger.e("Erro crítico ao carregar clientes com carrinho: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
          _clientesComCarrinho = [];
        });
      }
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    if (error.toString().contains('SocketException') || 
        error.toString().contains('Connection refused')) {
      return "Falha na conexão. Verifique sua internet e tente novamente.";
    }
    if (error.toString().contains('TimeoutException')) {
      return "O servidor demorou muito para responder. Tente novamente.";
    }
    return "Erro ao carregar os dados: ${error.toString()}";
  }

  void _mostrarSnackBar(String mensagem, Color cor) {
    if (!mounted) return;
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

  Future<void> _abrirCarrinhoCliente(Cliente cliente) async {
    if (cliente.codcli == null) {
      _mostrarSnackBar("Cliente selecionado é inválido (sem código).", Colors.red);
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    
    // Capturar referências antes de operações async
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Variável para controlar o dialog
    bool dialogShown = false;

    try {
      // Mostrar dialog de loading
      if (mounted) {
        dialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando carrinho...'),
                ],
              ),
            );
          },
        );
      }

      carrinhoProvider.limpar(); 
      final resultado = await _carrinhoService.recuperarCarrinho(cliente);
      
      // Fechar dialog se ainda estiver aberto
      if (dialogShown && mounted) {
        navigator.pop(); // Remove o dialog
        dialogShown = false;
      }

      if (!mounted) return;

      if (resultado.isSuccess && resultado.data != null) {
        resultado.data!.itens.forEach((produto, quantidade) {
          final desconto = resultado.data!.descontos[produto] ?? 0.0;
          carrinhoProvider.adicionarItem(produto, quantidade, desconto);
        });
        
        // Navegar para tela do carrinho
        await navigator.push(
          MaterialPageRoute(
            builder: (ctx) => CarrinhoScreen(
              cliente: cliente,
              codcli: cliente.codcli,
            ),
          ),
        );
        
        // Recarregar dados ao voltar
        if (mounted) {
          _carregarDados();
        }
      } else {
        if (mounted) {
          _mostrarSnackBar(resultado.errorMessage ?? 'Erro ao carregar carrinho', Colors.red);
        }
      }
    } catch (e) {
      _logger.e('Erro ao abrir carrinho: $e');
      
      // Fechar dialog se ainda estiver aberto
      if (dialogShown && mounted) {
        navigator.pop();
      }
      
      if (mounted) {
        _mostrarSnackBar('Erro ao abrir carrinho: $e', Colors.red);
      }
    }
  }
  
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    List<String> names = name.split(' ');
    if (names.isEmpty || names.first.isEmpty) return '?';
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }
    if (names.length > 1 && names[1].isNotEmpty) {
        return names[0].substring(0, 1).toUpperCase() + 
               names[1].substring(0, 1).toUpperCase();
    }
    return names[0].substring(0, 1).toUpperCase();
  }

  String _formatarTelefone(String? telefone) {
    if (telefone == null || telefone.isEmpty) return 'Não informado';
    
    String cleaned = telefone.replaceAll(RegExp(r'\D'), '');
    
    if (cleaned.length == 11) { // Celular com DDD
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.length == 10) { // Telefone fixo com DDD
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 9) { // Celular sem DDD
      return '${cleaned.substring(0, 5)}-${cleaned.substring(5)}';
    } else if (cleaned.length == 8) { // Telefone fixo sem DDD
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4)}';
    }
    
    return telefone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _carregarDados,
        color: primaryColor,
        child: _buildMainContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text("Carrinhos Pendentes", style: TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar',
          onPressed: _isLoading ? null : _carregarDados,
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) return _buildLoadingState();
    if (_hasError) return _buildErrorState();
    if (_clientesComCarrinho.isEmpty) return _buildEmptyState();
    return _buildClientesList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text("Carregando carrinhos pendentes...", 
              style: TextStyle(color: Colors.grey))
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
            Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              'Erro ao carregar dados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
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
            Icon(Icons.shopping_cart_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sem carrinhos pendentes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Nenhum cliente tem um carrinho aberto no momento.',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
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
        final Cliente cliente = _clientesComCarrinho[index];
        return _buildClienteCard(cliente);
      },
    );
  }

  Widget _buildClienteCard(Cliente cliente) {
    // Correção: Usar withValues() ao invés de withOpacity()
    final transparentPrimaryColor = primaryColor.withValues(alpha: 0.1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _abrirCarrinhoCliente(cliente);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: transparentPrimaryColor,
                child: Text(
                  _getInitials(cliente.nomcli),
                  style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nomcli ?? 'Cliente sem nome',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${cliente.codcli ?? "N/A"}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (cliente.numtel001 != null && cliente.numtel001!.isNotEmpty)
                      Text(
                        _formatarTelefone(cliente.numtel001),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: transparentPrimaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_cart, color: primaryColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}