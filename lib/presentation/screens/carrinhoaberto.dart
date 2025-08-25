import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/services/cliente_repository.dart'; // Importação correta
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/presentation/screens/carrinhoScreen.dart'; // Nome do arquivo corrigido
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Para ApiResult

class ClientesComCarrinhoScreen extends StatefulWidget {
  const ClientesComCarrinhoScreen({super.key});

  @override
  State<ClientesComCarrinhoScreen> createState() => _ClientesComCarrinhoScreenState();
}

class _ClientesComCarrinhoScreenState extends State<ClientesComCarrinhoScreen> {
  final CarrinhoService _carrinhoService = CarrinhoService();
  final Logger _logger = Logger();
  
  final Color primaryColor = const Color(0xFF5D5CDE);
  
  List<Cliente> _clientesComCarrinho = []; // Corrigido: Cliente -> ClienteModel
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
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
           _hasError = true; // Indica que houve um erro, mesmo que a API tenha retornado 'success = false'
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
    // Implementação simplificada - você pode expandir conforme necessário
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

  Future<void> _abrirCarrinhoCliente(Cliente cliente) async { // Corrigido: Cliente -> ClienteModel
    if (cliente.codcli == null) {
      _mostrarSnackBar("Cliente selecionado é inválido (sem código).", Colors.red);
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context); 
    final navigator = Navigator.of(context); // Captura Navigator
    BuildContext? dialogContext;

    try {
      showDialog(
        context: context, // Usa o context original do método
        barrierDismissible: false,
        builder: (dContext) { // dContext é o BuildContext do Dialog
          dialogContext = dContext;
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

      carrinhoProvider.limpar(); 
      final resultado = await _carrinhoService.recuperarCarrinho(cliente);
      
      // Fecha o diálogo de loading ANTES de qualquer navegação ou SnackBar
      if (dialogContext != null && Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
         Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
      if (!mounted) return; // Verifica 'mounted' DEPOIS do await

      if (resultado.isSuccess && resultado.data != null) {
        resultado.data!.itens.forEach((produto, quantidade) {
          final desconto = resultado.data!.descontos[produto] ?? 0.0;
          carrinhoProvider.adicionarItem(produto, quantidade, desconto);
        });
        
        // Usa a variável 'navigator' capturada
        await navigator.push( // Adiciona await aqui para esperar o retorno da CarrinhoScreen
          MaterialPageRoute(
            builder: (ctx) => CarrinhoScreen(
              cliente: cliente,
              codcli: cliente.codcli!, 
            ),
          ),
        );
        // Recarrega a lista ao voltar, pois o status do carrinho pode ter mudado.
        // A verificação `mounted` já está no início de _carregarDados.
        _carregarDados();

      } else {
        _mostrarSnackBar(resultado.errorMessage ?? 'Erro ao carregar carrinho', Colors.red);
      }
    } catch (e) {
      _logger.e('Erro ao abrir carrinho: $e');
      if (dialogContext != null && Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
         Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
      if (mounted) {
        _mostrarSnackBar('Erro ao abrir carrinho: $e', Colors.red);
      }
    }
  }
  
  String _getInitials(String? name) { // Aceita nulável
    if (name == null || name.isEmpty) return '?';
    List<String> names = name.split(' ');
    if (names.isEmpty || names.first.isEmpty) return '?'; // Checagem adicional
    if (names.length == 1) {
      return names[0].substring(0, 1).toUpperCase();
    }
    if (names.length > 1 && names[1].isNotEmpty) { // Checa se o segundo nome não é vazio
        return names[0].substring(0, 1).toUpperCase() + 
               names[1].substring(0, 1).toUpperCase();
    }
    return names[0].substring(0, 1).toUpperCase(); // Fallback se segundo nome for vazio
  }

  String _formatarTelefone(String? telefone) { // Aceita nulável
    if (telefone == null || telefone.isEmpty) return 'Não informado';
    
    // Implementação básica de formatação de telefone
    // Você pode melhorar conforme sua necessidade
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
    
    return telefone; // Retorna o original se não conseguir formatar
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
      title: const Text("Carrinhos Pendentes", style: TextStyle(fontWeight: FontWeight.w500)), // Título atualizado
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar',
          onPressed: _isLoading ? null : _carregarDados, // Desabilita se já carregando
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
        final Cliente cliente = _clientesComCarrinho[index]; // Corrigido: Cliente -> ClienteModel
        return _buildClienteCard(cliente);
      },
    );
  }

  Widget _buildClienteCard(Cliente cliente) { // Corrigido: Cliente -> ClienteModel
    // Correção para deprecated_member_use
    final transparentPrimaryColor = primaryColor.withOpacity(0.1); 

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1, // Aumentar um pouco a elevação para destaque
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Borda mais suave
        // side: BorderSide(color: Colors.grey[200]!), // Opcional
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
                      cliente.nomcli ?? 'Cliente sem nome', // Trata nomcli nulo
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${cliente.codcli ?? "N/A"}', // Trata codcli nulo
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (cliente.numtel001 != null && cliente.numtel001!.isNotEmpty) // Mostra telefone se existir
                      Text(
                        _formatarTelefone(cliente.numtel001),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8), // Padding em volta do ícone
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