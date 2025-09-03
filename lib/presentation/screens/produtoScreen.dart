import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_produto_model.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/presentation/screens/carrinhoScreen.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:flutter_docig_venda/presentation/widgets/cardProdutos.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/data/repositories/repository_manager.dart' as repo_manager;

class ProdutoScreen extends StatefulWidget {
  final Cliente? cliente;

  const ProdutoScreen({super.key, this.cliente});

  @override
  State<ProdutoScreen> createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends State<ProdutoScreen> {
  final Color primaryColor = const Color(0xFF5D5CDE);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Estado da tela
  List<ProdutoModel> _produtos = [];
  List<ProdutoModel> _produtosFiltrados = [];
  bool _isLoadingProdutos = true;
  bool _isSearching = false;
  String? _errorMessageProdutos;
  bool _usaProdutosEspecificos = false;
  bool _recuperacaoCarrinhoInicialFeita = false;

  // Repositórios
  ProdutoRepository? _produtoRepository;
  ClienteProdutoRepository? _clienteProdutoRepository;
  RepositoryManager? _repositoryManager;
  CarrinhoService? _carrinhoService;
  final Logger _logger = Logger();
  
  // Estado de inicialização
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initError;
  bool _isDisposed = false;

  // NOVO: Controles específicos para evitar loops
  bool _isLoadingOperation = false;
  bool _preventProviderLoop = false;

  @override
  void initState() {
    super.initState();
    _configurarListeners();
    
    // CRÍTICO: Inicialização imediata no initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _initializeServices();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // REMOVIDO: Não fazemos mais inicialização aqui para evitar loops
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _configurarListeners() {
    _searchController.addListener(_onSearchChanged);
  }

  // CORREÇÃO CRÍTICA: Search listener simplificado
  void _onSearchChanged() {
    if (_isDisposed || _preventProviderLoop) return;
    
    final query = _searchController.text;
    _filtrarProdutosSemSetState(query);
    
    // Só muda estado se necessário
    final isSearchingNow = query.isNotEmpty;
    if (_isSearching != isSearchingNow && mounted) {
      setState(() {
        _isSearching = isSearchingNow;
      });
    }
  }

  void _filtrarProdutosSemSetState(String query) {
    final String termoBusca = query.toLowerCase().trim();
    
    if (termoBusca.isEmpty) {
      _produtosFiltrados = List.from(_produtos);
    } else {
      _produtosFiltrados = _produtos.where((produto) {
        final codigoProduto = produto.codprd?.toString().toLowerCase() ?? '';
        if (codigoProduto.startsWith(termoBusca)) return true;
        
        final palavrasDescricao = produto.dcrprd.toLowerCase().split(' ');
        if (palavrasDescricao.any((p) => p.trim().startsWith(termoBusca))) return true;
        
        final palavrasMarca = produto.nommrc.toLowerCase().split(' ');
        if (palavrasMarca.any((p) => p.trim().startsWith(termoBusca))) return true;
        
        return false;
      }).toList();
    }
  }

  Future<void> _initializeServices() async {
    if (_isDisposed || _isInitializing) return;
    
    _isInitializing = true;
    
    try {
      _logger.i("🔄 Inicializando serviços...");
      
      RepositoryManager? repositoryManager;
      
      try {
        // CRÍTICO: Usa listen: false para evitar reconstruções
        repositoryManager = Provider.of<RepositoryManager>(context, listen: false);
        _logger.i("✅ RepositoryManager via Provider");
        
      } catch (e) {
        _logger.w("⚠️ Fallback: Criando repositórios locais");
        final dbHelper = DatabaseHelper.instance;
        await dbHelper.database;
        repositoryManager = RepositoryManager(dbHelper);
      }
      
      if (_isDisposed) return;
      
      _repositoryManager = repositoryManager;
      _produtoRepository = _repositoryManager!.produtos;
      _clienteProdutoRepository = _repositoryManager!.clienteProduto;
      
      _carrinhoService = CarrinhoService(
        repositoryManager: _repositoryManager!,
      );
      
      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
        
        _logger.i("✅ Serviços inicializados");
        
        // Carrega produtos
        await _carregarProdutos();
        
        // Recupera carrinho apenas UMA VEZ
        if (widget.cliente != null && !_recuperacaoCarrinhoInicialFeita && !_isDisposed) {
          _recuperacaoCarrinhoInicialFeita = true;
          _tentarRecuperarCarrinhoDoBanco();
        }
      }
      
    } catch (e, stackTrace) {
      _logger.e("❌ Erro na inicialização", error: e, stackTrace: stackTrace);
      if (!_isDisposed && mounted) {
        setState(() {
          _initError = e.toString();
          _isInitializing = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _carregarProdutos() async {
    if (!mounted || !_isInitialized || _isDisposed || _isLoadingOperation) return;

    _isLoadingOperation = true;
    
    try {
      _logger.i("🔄 Carregando produtos...");
      
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingProdutos = true;
          _errorMessageProdutos = null;
          _usaProdutosEspecificos = false;
        });
      }

      List<ProdutoModel> produtosCarregados = [];
      
      if (widget.cliente != null && widget.cliente!.codcli != null) {
        final temProdutosEspecificos = await _clienteProdutoRepository!
            .clienteTemProdutosEspecificos(widget.cliente!.codcli!);
        
        if (_isDisposed) return;
        
        if (temProdutosEspecificos) {
          produtosCarregados = await _clienteProdutoRepository!
              .getProdutosPorCliente(widget.cliente!.codcli!);
          _usaProdutosEspecificos = true;
        } else {
          produtosCarregados = await _produtoRepository!.getProdutosAtivos();
        }
      } else {
        produtosCarregados = await _produtoRepository!.getProdutosAtivos();
      }

      if (_isDisposed) return;

      _logger.i("✅ ${produtosCarregados.length} produtos carregados");

      if (mounted && !_isDisposed) {
        setState(() {
          _produtos = produtosCarregados;
          _produtosFiltrados = produtosCarregados;
          _isLoadingProdutos = false;
        });
      }
    } catch (e, s) {
      _logger.e("❌ Erro ao carregar produtos", error: e, stackTrace: s);
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingProdutos = false;
          _errorMessageProdutos = e.toString();
        });
      }
    } finally {
      _isLoadingOperation = false;
    }
  }

  Future<void> _tentarRecuperarCarrinhoDoBanco() async {
    if (widget.cliente == null || widget.cliente!.codcli == null || _isDisposed) return;

    try {
      _preventProviderLoop = true; // CRÍTICO: Previne loop do Provider
      
      Carrinho? carrinhoProvider;
      try {
        carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      } catch (e) {
        _logger.w("⚠️ Carrinho Provider não disponível: $e");
        return;
      } finally {
        _preventProviderLoop = false;
      }

      if (_isDisposed) return;

      if (carrinhoProvider.isEmpty) {
        _logger.i("🔍 Verificando carrinho pendente...");
        
        final ApiResult<bool> temPendenteResult = 
            await _carrinhoService!.clienteTemCarrinhoPendente(widget.cliente!);

        if (!mounted || _isDisposed) return;

        if (temPendenteResult.isSuccess && temPendenteResult.data == true) {
          final bool? deveRecuperar = await _perguntarRecuperarCarrinho();
          if (mounted && !_isDisposed && deveRecuperar == true) {
            await _executarRecuperacaoCarrinho(carrinhoProvider);
          }
        }
      }
    } catch (e) {
      _logger.e("❌ Erro ao verificar carrinho: $e");
    } finally {
      _preventProviderLoop = false;
    }
  }

  Future<bool?> _perguntarRecuperarCarrinho() {
    if (_isDisposed) return Future.value(false);
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "Carrinho Pendente",
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text("IGNORAR", style: TextStyle(color: Colors.grey[700])),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0,
                      ),
                      child: const Text("RECUPERAR"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executarRecuperacaoCarrinho(Carrinho carrinhoProvider) async {
    if (_isDisposed) return;
    
    try {
      _preventProviderLoop = true;
      
      final resultado = await _carrinhoService!.recuperarCarrinho(widget.cliente!);
      if (!mounted || _isDisposed) return;

      if (resultado.isSuccess && resultado.data != null) {
        carrinhoProvider.limpar();
        resultado.data!.itens.forEach((produto, quantidade) {
          final desconto = resultado.data!.descontos[produto] ?? 0.0;
          carrinhoProvider.adicionarItem(produto, quantidade, desconto);
        });
        
        _mostrarMensagem("Carrinho recuperado!", cor: Colors.green[700]);
      } else {
        _mostrarMensagem(
          "Erro ao recuperar carrinho: ${resultado.errorMessage}",
          cor: Colors.red[700],
        );
      }
    } catch (e) {
      _logger.e("❌ Erro ao executar recuperação: $e");
    } finally {
      _preventProviderLoop = false;
    }
  }

  Future<void> _adicionarProdutoAoCarrinho(
    ProdutoModel produto,
    int quantidade,
    double descontoPercentual,
  ) async {
    if (_isDisposed || _preventProviderLoop) return;
    
    if (widget.cliente == null || widget.cliente!.codcli == null) {
      _mostrarMensagem('Selecione um cliente.', cor: Colors.red[700]);
      return;
    }

    try {
      _preventProviderLoop = true;
      
      Carrinho? carrinhoProvider;
      try {
        carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      } catch (e) {
        _mostrarMensagem('Erro no sistema do carrinho', cor: Colors.red[700]);
        return;
      }

      if (_isDisposed) return;

      carrinhoProvider.adicionarItem(produto, quantidade, descontoPercentual);

      // Salva assincronamente SEM aguardar
      _carrinhoService!
          .salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
          .then((result) {
        if (!mounted || _isDisposed) return;
        if (!result.isSuccess) {
          _logger.e("❌ Falha ao salvar carrinho: ${result.errorMessage}");
        } else {
          _logger.i("✅ Carrinho salvo");
        }
      }).catchError((error) {
        _logger.e("❌ Erro ao salvar carrinho", error: error);
      });
      
    } catch (e) {
      _logger.e("❌ Erro ao adicionar produto: $e");
    } finally {
      _preventProviderLoop = false;
    }
  }

  void _limparPesquisa() {
    if (_isDisposed) return;
    _searchController.clear();
    _searchFocus.unfocus();
  }

  void _irParaCarrinho() {
    if (_isDisposed || _preventProviderLoop) return;
    
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);

      if (carrinhoProvider.isEmpty) {
        _mostrarMensagem('O carrinho está vazio.', cor: Colors.grey[800]);
        return;
      }
      
      if (widget.cliente == null || widget.cliente!.codcli == null) {
        _mostrarMensagem('Selecione um cliente.', cor: Colors.red[700]);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CarrinhoScreen(
            cliente: widget.cliente,
            codcli: widget.cliente!.codcli!,
          ),
        ),
      );
    } catch (e) {
      _logger.e("❌ Erro ao navegar: $e");
    }
  }

  void _mostrarMensagem(String mensagem, {Color? cor}) {
    if (!mounted || _isDisposed) return;
    
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: cor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _logger.w("⚠️ Erro ao mostrar SnackBar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return _buildErrorScreen();
    }

    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildInfoBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                if (!_isDisposed && !_isLoadingOperation) {
                  await _carregarProdutos();
                }
              },
              color: primaryColor,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCartFAB(),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Erro", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                "Erro ao inicializar sistema",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_initError!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text('Voltar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Inicializando...", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            const Text("Inicializando sistema..."),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      titleSpacing: 16,
      iconTheme: const IconThemeData(color: Colors.white),
      title: widget.cliente != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Produtos",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                ),
                Text(
                  "Cliente: ${widget.cliente!.nomcli}",
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : const Text(
              "Catálogo de Produtos",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, size: 22, color: Colors.white),
          tooltip: 'Atualizar Produtos',
          onPressed: (_isDisposed || _isLoadingOperation) ? null : _carregarProdutos,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          hintText: "Pesquisar produto...",
          fillColor: Colors.white,
          filled: true,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                  onPressed: _limparPesquisa,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildInfoBar() {
    // CRÍTICO: Info bar sem Consumer para quebrar o loop
    int quantidadeCarrinho = 0;
    
    try {
      if (!_preventProviderLoop) {
        final carrinho = Provider.of<Carrinho>(context, listen: false);
        quantidadeCarrinho = carrinho.quantidadeTotal;
      }
    } catch (e) {
      // Ignora erro silenciosamente
    }

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (widget.cliente != null) ...[
                  Icon(Icons.list_alt, size: 14, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text(
                    "Tabela: ${widget.cliente?.codtab ?? 'N/A'}",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.inventory_2, size: 14, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  "${_produtosFiltrados.length}/${_produtos.length} produtos",
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Text(
                  "$quantidadeCarrinho itens",
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          if (_usaProdutosEspecificos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, size: 12, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    "Específicos",
                    style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoadingProdutos) return _buildLoadingState();
    if (_errorMessageProdutos != null) return _buildErrorState();
    if (_produtosFiltrados.isEmpty && !_isSearching) {
      return _buildEmptyState(isSearching: false);
    }
    if (_produtosFiltrados.isEmpty && _isSearching) {
      return _buildEmptyState(isSearching: true);
    }
    return _buildProductGrid();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: primaryColor),
          const SizedBox(height: 16),
          const Text("Carregando produtos...", style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text("Erro ao carregar produtos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _errorMessageProdutos ?? "Erro desconhecido",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: (_isDisposed || _isLoadingOperation) ? null : _carregarProdutos,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Tentar Novamente"),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearching}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? "Nenhum produto encontrado"
                  : _usaProdutosEspecificos
                      ? "Nenhum produto específico cadastrado"
                      : "Nenhum produto disponível",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? "Tente buscar por outro termo"
                  : _usaProdutosEspecificos
                      ? "Este cliente não possui produtos específicos cadastrados"
                      : "Aguarde a sincronização dos produtos",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _isDisposed ? null : _limparPesquisa,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text("Limpar Pesquisa"),
                style: TextButton.styleFrom(foregroundColor: primaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _produtosFiltrados.length,
      itemBuilder: (context, index) {
        ProdutoModel produto = _produtosFiltrados[index];
        return ProdutoDetalhe(
          produto: produto,
          onAddToCart: (quantidade, descontoPercentual) {
            if (!_isDisposed && !_preventProviderLoop) {
              _adicionarProdutoAoCarrinho(produto, quantidade, descontoPercentual);
            }
          },
          clienteTabela: widget.cliente?.codtab ?? 1,
        );
      },
    );
  }

  Widget _buildCartFAB() {
    // CRÍTICO: FAB sem Consumer para evitar loop infinito
    int totalItens = 0;
    
    try {
      if (!_preventProviderLoop) {
        final carrinho = Provider.of<Carrinho>(context, listen: false);
        totalItens = carrinho.quantidadeTotal;
      }
    } catch (e) {
      // Ignora erro silenciosamente
    }

    final bool isEnabled = totalItens > 0 && !_isDisposed && !_preventProviderLoop;
    
    return FloatingActionButton.extended(
      onPressed: isEnabled ? _irParaCarrinho : null,
      backgroundColor: isEnabled ? primaryColor : Colors.grey,
      icon: Badge(
        isLabelVisible: totalItens > 0,
        label: Text('$totalItens'),
        child: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
      ),
      label: const Text(
        "Carrinho",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      elevation: 2,
    );
  }
}