// lib/screens/produto_screen.dart (Nome de arquivo sugerido)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/widgets/cardProdutos.dart'; // Considere renomear para card_produtos.dart
import 'package:flutter_docig_venda/widgets/carrinho.dart'; // Seu ChangeNotifier
import 'package:flutter_docig_venda/screens/carrinhoScreen.dart'; // Considere renomear para carrinho_screen.dart
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart'; // Considere renomear para carrinho_service.dart
import 'package:flutter_docig_venda/services/api_client.dart'; // Necessário para ApiResult
import 'package:logger/logger.dart';

class ProdutoScreen extends StatefulWidget {
  final Cliente? cliente; // Usar ClienteModel consistentemente

  const ProdutoScreen({super.key, this.cliente});

  @override
  State<ProdutoScreen> createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends State<ProdutoScreen> {
  final Color primaryColor = Color(0xFF5D5CDE);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<ProdutoModel> _produtos = [];
  List<ProdutoModel> _produtosFiltrados = [];
  bool _isLoadingProdutos = true;
  bool _isSearching = false;
  // Estes campos são usados, o linter pode estar equivocado ou o código que ele analisa é diferente
  bool _isSyncing = false; 
  String? _errorMessageProdutos;
  bool _usandoDadosExemplo = false; 
  
  bool _recuperacaoCarrinhoInicialFeita = false;

  final ProdutoDao _produtoDao = ProdutoDao();
  final CarrinhoService _carrinhoService = CarrinhoService();
  final Logger _logger = Logger();

  // --- INSTÂNCIA LOCAL DO CARRINHO REMOVIDA ---

  @override
  void initState() {
    super.initState();
    _carregarProdutosDoDb();
    _configurarListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recuperacaoCarrinhoInicialFeita && widget.cliente != null) {
      _tentarRecuperarCarrinhoDoBanco();
      _recuperacaoCarrinhoInicialFeita = true;
    }
  }

  void _configurarListeners() {
    _searchController.addListener(() {
      final query = _searchController.text;
      _filtrarProdutos(query); // Chama o filtro
      final isSearchingNow = query.isNotEmpty;
      if (_isSearching != isSearchingNow) { // Evita setState desnecessário
        if (mounted) {
          setState(() {
            _isSearching = isSearchingNow;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // O listener anônimo é removido com o dispose do controller
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _tentarRecuperarCarrinhoDoBanco() async {
    if (widget.cliente == null || widget.cliente!.codcli == null) return;

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Captura antes do await

    if (carrinhoProvider.isEmpty) {
      _logger.i("Carrinho (Provider) vazio. Verificando pendente...");
      // Considerar um setState para _isLoadingRecuperacao = true se tiver UI específica
      try {
        final ApiResult<bool> temPendenteResult = await _carrinhoService.clienteTemCarrinhoPendente(widget.cliente!);

        if (!mounted) return;

        if (temPendenteResult.isSuccess && temPendenteResult.data == true) {
          final bool? deveRecuperar = await _perguntarRecuperarCarrinho(); // null safety
          if (mounted && deveRecuperar == true) {
            await _executarRecuperacaoCarrinho(carrinhoProvider, scaffoldMessenger);
          }
        } else if (mounted && !temPendenteResult.isSuccess) {
          _mostrarMensagem(scaffoldMessenger, "Erro ao verificar carrinho: ${temPendenteResult.errorMessage}", cor: Colors.orange[700]);
        }
      } catch (e) {
        _logger.e("Erro ao verificar/recuperar carrinho: $e");
        if (mounted) {
          _mostrarMensagem(scaffoldMessenger, "Erro ao verificar carrinho: $e", cor: Colors.red[700]);
        }
      } finally {
        // if (mounted) setState(() => _isLoadingRecuperacao = false);
      }
    } else {
      _logger.i("Provider já populado.");
    }
  }

  Future<bool?> _perguntarRecuperarCarrinho() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog( // Usar dialogContext aqui
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart, color: primaryColor, size: 20),
                  SizedBox(width: 8),
                  Text("Carrinho Pendente", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ],
              ),
              SizedBox(height: 16),
              Text(
                "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.",
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false), // Usar dialogContext
                    child: Text("IGNORAR", style: TextStyle(color: Colors.grey[700])),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext, true), // Usar dialogContext
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, elevation: 0),
                    child: Text("RECUPERAR"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executarRecuperacaoCarrinho(Carrinho carrinhoProvider, ScaffoldMessengerState scaffoldMessenger) async {
    _logger.i("Executando recuperação de carrinho para o Provider...");
    // setState(() => _isLoading = true); // ou um _isLoadingRecuperacao

    try {
      final resultado = await _carrinhoService.recuperarCarrinho(widget.cliente!);
      if (!mounted) return;

      if (resultado.isSuccess && resultado.data != null) {
        carrinhoProvider.limpar();
        resultado.data!.itens.forEach((produto, quantidade) {
          final desconto = resultado.data!.descontos[produto] ?? 0.0;
          carrinhoProvider.adicionarItem(produto, quantidade, desconto);
        });
        _logger.i("Carrinho recuperado e Provider atualizado.");
        _mostrarMensagem(scaffoldMessenger, "Carrinho recuperado!", cor: Colors.green[700]);
      } else {
        _mostrarMensagem(scaffoldMessenger, "Não recuperar carrinho: ${resultado.errorMessage}", cor: Colors.red[700]);
      }
    } catch (e) {
      _logger.e("Erro ao executar recuperação: $e");
      if (mounted) {
        _mostrarMensagem(scaffoldMessenger, "Erro ao recuperar: $e", cor: Colors.red[700]);
      }
    } finally {
        // if (mounted) setState(() => _isLoading = false); // ou _isLoadingRecuperacao
    }
  }

  Future<void> _carregarProdutosDoDb() async {
    if (mounted) {
      setState(() {
        _isLoadingProdutos = true;
        _errorMessageProdutos = null;
      });
    } else {
      return; 
    }

    try {
      _logger.i("ProdutoScreen: Iniciando _carregarProdutosDoDb()...");
      List<ProdutoModel> lista = await _produtoDao.getAll((json) => ProdutoModel.fromJson(json));
      
      // ----- LOG DETALHADO -----
      _logger.i("ProdutoScreen: Produtos carregados do _produtoDao.getAll(): ${lista.length} itens.");
      if (lista.isEmpty) {
        _logger.w("ProdutoScreen: A lista retornada pelo DAO está VAZIA.");
      } else {
        for (var p in lista) {
          _logger.d("ProdutoScreen: DAO retornou -> ID: ${p.codprd}, Nome: ${p.dcrprd}, Preço T1: ${p.vlrtab1}");
        }
      }
      // -------------------------

      if (mounted) {
        setState(() {
          _produtos = lista;
          _produtosFiltrados = lista; // Inicializa filtrados com todos os produtos
          _isLoadingProdutos = false;
        });
      }
    } catch (e, s) { // Adiciona stacktrace ao log
      _logger.e("ProdutoScreen: Erro em _carregarProdutosDoDb()", error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _isLoadingProdutos = false;
          _errorMessageProdutos = e.toString();
        });
      }
    }
  }
  
  // Os métodos _gerarProdutosExemplo e _sincronizarProdutos podem ser mantidos como estão,
  // apenas garanta que _mostrarMensagem use a variável scaffoldMessenger capturada.
  // List<ProdutoModel> _gerarProdutosExemplo() { ... }
  // Future<void> _sincronizarProdutos() async { ... }


  Future<void> _adicionarProdutoAoCarrinho(
      ProdutoModel produto, int quantidade, double descontoPercentual) async {
    if (widget.cliente == null || widget.cliente!.codcli == null ) {
      _logger.e('Cliente não definido ou sem código.');
      _mostrarMensagem(ScaffoldMessenger.of(context),'Selecione um cliente.', cor: Colors.red[700]);
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    carrinhoProvider.adicionarItem(produto, quantidade, descontoPercentual);
    // _mostrarMensagem(scaffoldMessenger, '${produto.dcrprd} adicionado.', cor: Colors.grey[800]); // Feedback opcional

    _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
        .then((result) {
            if (!mounted) return; // Verifica se o widget ainda está montado
            if (!result.isSuccess) {
                 _logger.e("Falha salvar carrinho: ${result.errorMessage}");
                 _mostrarMensagem(scaffoldMessenger,'Erro ao salvar carrinho', cor: Colors.red[700]);
            } else {
               _logger.i("Carrinho salvo.");
            }
        }).catchError((error, stackTrace) {
            _logger.e("Erro não tratado salvar carrinho", error: error, stackTrace: stackTrace);
            if (mounted) {
               _mostrarMensagem(scaffoldMessenger,'Erro inesperado ao salvar', cor: Colors.red[700]);
           }
        });
  }

  void _filtrarProdutos(String query) {
    final String termoBusca = query.toLowerCase().trim();
    setState(() {
      if (termoBusca.isEmpty) {
        _produtosFiltrados = List.from(_produtos); // Cria nova lista para evitar referência
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
    });
  }

  void _limparPesquisa() {
    _searchController.clear(); // O listener chamará _filtrarProdutos
    _searchFocus.unfocus();
  }

  void _irParaCarrinho() {
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    // ----- CORREÇÃO: Use a variável local scaffoldMessenger -----
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (carrinhoProvider.isEmpty) { // Verifica usando o provider
      _mostrarMensagem(scaffoldMessenger, 'O carrinho está vazio.', cor: Colors.grey[800]);
      return;
    }
    if (widget.cliente == null || widget.cliente!.codcli == null) {
      _mostrarMensagem(scaffoldMessenger, 'Selecione um cliente.', cor: Colors.red[700]);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarrinhoScreen(
          cliente: widget.cliente,
          codcli: widget.cliente!.codcli, // Acesso seguro após verificação
        ),
      ),
    );
    // A lógica .then() para limpar _carrinho local foi removida
  }

  void _mostrarMensagem(ScaffoldMessengerState messenger, String mensagem, {Color? cor}) {
     if (!mounted) return;
     try {
       messenger.hideCurrentSnackBar();
       messenger.showSnackBar(
         SnackBar(
           content: Text(mensagem),
           backgroundColor: cor,
           behavior: SnackBarBehavior.floating,
           duration: const Duration(seconds: 2),
         ),
       );
     } catch (e) {
       _logger.w("Erro ao mostrar SnackBar (contexto pode estar inválido): $e");
     }
   }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildInfoBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _carregarProdutosDoDb,
              color: primaryColor,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCartFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
     return AppBar(
       backgroundColor: primaryColor,
       elevation: 0,
       titleSpacing: 16,
       title: widget.cliente != null
           ? Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text("Produtos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                 Text(
                   // Acesso seguro, já que widget.cliente foi verificado
                   "Cliente: ${widget.cliente!.nomcli}", 
                   style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                   overflow: TextOverflow.ellipsis,
                 ),
               ],
             )
           : const Text("Catálogo de Produtos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
       actions: [
         // IconButton( // Ícone de sincronizar exemplos (se for manter)
         //   icon: _isSyncing ? CircularProgressIndicator(...) : Icon(Icons.sync),
         //   onPressed: _isSyncing ? null : _sincronizarProdutos, // Método _sincronizarProdutos precisa ser definido
         // ),
         IconButton(
           icon: const Icon(Icons.refresh, size: 22),
           tooltip: 'Atualizar Produtos',
           onPressed: _carregarProdutosDoDb,
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
        // onChanged já está coberto pelo listener em _configurarListeners
        decoration: InputDecoration(
          hintText: "Pesquisar produto...",
          fillColor: Colors.white,
          filled: true,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                  onPressed: _limparPesquisa, // Certifique-se que _limparPesquisa está definido
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
    return Consumer<Carrinho>( 
      builder: (context, carrinhoProvider, child) {
        final int quantidadeTotalCarrinho = carrinhoProvider.quantidadeTotal;
        return Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (widget.cliente != null) ...[
                    Icon(Icons.list_alt, size: 14, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                      // Acesso seguro com fallback
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
                    "$quantidadeTotalCarrinho itens", 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              // if (_usandoDadosExemplo) Container( /* ... */ ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    if (_isLoadingProdutos) return _buildLoadingState();
    if (_errorMessageProdutos != null) return _buildErrorState();
    if (_produtosFiltrados.isEmpty && !_isSearching) return _buildEmptyState(isSearching: false);
    if (_produtosFiltrados.isEmpty && _isSearching) return _buildEmptyState(isSearching: true);
    return _buildProductGrid();
  }

  Widget _buildLoadingState() { /* ... Seu código (parece OK) ... */ return const Center(child: CircularProgressIndicator());}
  Widget _buildErrorState() { /* ... Seu código (parece OK) ... */ return const Center(child: Text("Erro"));}
  Widget _buildEmptyState({required bool isSearching}) { /* ... Seu código (ajuste a mensagem com base em isSearching)... */ return Center(child: Text(isSearching ? "Nenhum produto encontrado" : "Nenhum produto disponível"));}


  Widget _buildProductGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      // --- CORREÇÃO: Adicionar gridDelegate ---
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75, // Ajuste conforme o visual do seu CardProdutos
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _produtosFiltrados.length,
      // Dentro de _buildProductGrid, no itemBuilder do GridView:
itemBuilder: (context, index) {
    ProdutoModel produto = _produtosFiltrados[index];
    return ProdutoDetalhe( // OU CardProdutos
      produto: produto,
      // AQUI ESTÁ O PROBLEMA: O widget ProdutoDetalhe ainda espera 'carrinho'
      onAddToCart: (quantidade, descontoPercentual) {
        _adicionarProdutoAoCarrinho(produto, quantidade, descontoPercentual);
      },
      clienteTabela: widget.cliente?.codtab ?? 1,
    );
  },
    );
  }

  Widget _buildCartFAB() {
    return Consumer<Carrinho>(
      builder: (context, carrinhoProvider, child) {
        final int totalItens = carrinhoProvider.quantidadeTotal;
        return FloatingActionButton.extended(
          onPressed: totalItens == 0 ? null : _irParaCarrinho,
          backgroundColor: totalItens == 0 ? Colors.grey : primaryColor,
          icon: Badge(
            isLabelVisible: totalItens > 0,
            label: Text('$totalItens'),
            child: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          ),
          label: const Text("Carrinho", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
          elevation: 2,
        );
      },
    );
  }
}