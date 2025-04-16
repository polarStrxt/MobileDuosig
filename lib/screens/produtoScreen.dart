import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/widgets/cardProdutos.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/screens/carrinhoScreen.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';

class ProdutoScreen extends StatefulWidget {
  final Cliente? cliente;

  const ProdutoScreen({super.key, this.cliente});

  @override
  State<ProdutoScreen> createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends State<ProdutoScreen> {
  // Constantes
  final Color primaryColor = Color(0xFF5D5CDE);

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Estado
  List<Produto> _produtos = [];
  List<Produto> _produtosFiltrados = [];
  final Carrinho _carrinho = Carrinho();
  Map<Produto, double> _descontos = {};
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _usandoDadosExemplo = false;

  // DAOs
  final ProdutoDao _produtoDao = ProdutoDao();
  final CarrinhoDao _carrinhoDao = CarrinhoDao();

  @override
  void initState() {
    super.initState();
    _inicializarDados();
    _configurarListeners();
  }

  void _inicializarDados() {
    _carregarProdutosDoDb();
    _verificarCarrinhoExistente();
  }

  void _configurarListeners() {
    _searchController.addListener(() {
      setState(() {
        _isSearching = _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // CARREGAMENTO DE DADOS

  Future<void> _verificarCarrinhoExistente() async {
    if (widget.cliente == null) return;

    try {
      final itensCarrinho =
          await _carrinhoDao.getItensCliente(widget.cliente!.codcli);

      if (itensCarrinho.isEmpty || !mounted) return;

      final deveRecuperar = await _perguntarRecuperarCarrinho();
      if (deveRecuperar != true) return;

      await _recuperarCarrinho(itensCarrinho);
    } catch (e) {
      debugPrint('❌ Erro ao verificar carrinho existente: $e');
    }
  }

  Future<bool?> _perguntarRecuperarCarrinho() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
                  Text(
                    "Carrinho Pendente",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      foregroundColor: Colors.grey[700],
                    ),
                    child: Text("IGNORAR"),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      elevation: 0,
                    ),
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

  Future<void> _recuperarCarrinho(List<CarrinhoItem> itensCarrinho) async {
    _carrinho.itens.clear();
    _descontos.clear();

    for (var item in itensCarrinho) {
      Produto? produto = await _buscarProdutoPeloCodigo(item.codprd);
      if (produto != null) {
        _carrinho.itens[produto] = item.quantidade;
        if (item.desconto > 0) {
          _descontos[produto] = item.desconto * 100;
        }
      }
    }

    if (!mounted) return;

    setState(() {});

    _mostrarMensagem(
        "Carrinho recuperado com sucesso! (${itensCarrinho.length} itens)",
        cor: Colors.green[700]);
  }

  Future<Produto?> _buscarProdutoPeloCodigo(int codprd) async {
    try {
      return await _produtoDao.getProdutoByCodigo(codprd);
    } catch (e) {
      debugPrint('❌ Erro ao buscar produto $codprd: $e');
      return null;
    }
  }

  Future<void> _carregarProdutosDoDb() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = await _produtoDao.database;
      List<Map<String, dynamic>> countResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM ${_produtoDao.tableName}');
      final int produtosCount = countResult.first['count'] as int;

      if (produtosCount == 0) {
        setState(() {
          _errorMessage = 'Não há produtos no banco de dados local.';
          _isLoading = false;
        });
        return;
      }

      List<Produto> lista =
          await _produtoDao.getAll((json) => Produto.fromJson(json));

      setState(() {
        _produtos = lista;
        _produtosFiltrados = lista;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Erro ao buscar produtos do banco de dados: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Função para gerar produtos de exemplo localmente
  List<Produto> _gerarProdutosExemplo() {
    // Criar 20 produtos de exemplo
    return List.generate(20, (index) {
      final codprd = 1000 + index;
      final dcrprd = "Produto Exemplo ${index + 1}";
      final marca = ["Marca A", "Marca B", "Marca C", "Marca D"][index % 4];
      final preco = (10.0 + (index * 5.75)) * (1 + (index % 3) * 0.1);
      final estoque = (50 + (index * 7)) % 200;
      
      // Ajustando o construtor conforme a definição real da classe Produto
      return Produto(
        codprd: codprd,
        dcrprd: dcrprd,
        nommrc: marca,
        // Parâmetros como definidos na classe
        staati: index % 10 == 0 ? "I" : "A", // A = Ativo, I = Inativo
        qtdmulvda: 1,
        vlrbasvda: preco,
        qtdetq: estoque, // Opcional
        vlrpmcprd: preco * 0.85,
        dtaini: null, // Opcional
        dtafin: null, // Opcional
        vlrtab1: preco,
        vlrtab2: preco * 1.1,
        peracrdsc1: 5.0,
        peracrdsc2: 10.0,
        codundprd: "UN",
        vol: ((index % 5) + 1), // De 1 a 5
        qtdvol: 1,
        perdscmxm: 15.0,
      );
    });
  }

  Future<void> _sincronizarProdutos() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      // Gerar produtos de exemplo localmente em vez de buscar da API
      List<Produto> produtosExemplo = _gerarProdutosExemplo();
      
      await _produtoDao.clearTable();

      for (var produto in produtosExemplo) {
        await _produtoDao.insertOrUpdate(produto.toJson(), 'codprd');
      }

      List<Produto> lista =
          await _produtoDao.getAll((json) => Produto.fromJson(json));

      setState(() {
        _produtos = lista;
        _produtosFiltrados = lista;
        _isSyncing = false;
        _usandoDadosExemplo = true;
      });

      if (!mounted) return;

      _mostrarMensagem(
          '${produtosExemplo.length} produtos de exemplo carregados',
          cor: Colors.green[700]);
    } catch (e) {
      debugPrint("❌ Erro ao carregar produtos de exemplo: $e");

      setState(() {
        _isSyncing = false;
        _errorMessage = 'Erro ao carregar exemplos: ${e.toString()}';
      });

      if (!mounted) return;

      _mostrarMensagem('Erro ao carregar exemplos: ${e.toString()}',
          cor: Colors.red[700]);
    }
  }

  // GESTÃO DO CARRINHO

  Future<void> _adicionarProdutoAoCarrinho(
      Produto produto, int quantidade, double desconto) async {
    _carrinho.itens[produto] = quantidade;

    if (desconto > 0) {
      _descontos[produto] = desconto;
    }

    if (widget.cliente == null) {
      debugPrint('⚠️ Tentativa de adicionar ao carrinho sem cliente definido');
      return;
    }

    try {
      final carrinhoItem = CarrinhoItem(
        codprd: produto.codprd,
        codcli: widget.cliente!.codcli,
        quantidade: quantidade,
        desconto: desconto / 100,
        finalizado: 0,
        dataCriacao: DateTime.now(),
      );

      await _carrinhoDao.salvarItem(carrinhoItem);
      debugPrint('✅ Produto ${produto.codprd} adicionado ao carrinho');
    } catch (e) {
      debugPrint('❌ Erro ao salvar produto no carrinho: $e');
      if (mounted) {
        _mostrarMensagem('Erro ao salvar produto no carrinho',
            cor: Colors.red[700]);
      }
    }

    setState(() {});
  }

  void _irParaCarrinho() {
    final int totalItens = _carrinho.quantidadeTotal;

    if (totalItens == 0) {
      _mostrarMensagem(
          'O carrinho está vazio. Adicione produtos para continuar.',
          cor: Colors.grey[800]);
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem('Selecione um cliente antes de visualizar o carrinho.',
          cor: Colors.red[700]);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarrinhoScreen(
          cliente: widget.cliente,
          codcli: widget.cliente!.codcli,
        ),
      ),
    ).then((_) {
      setState(() {});
      _verificarCarrinhoExistente();
    });
  }

  // PESQUISA E FILTRAGEM

  void _filtrarProdutos(String query) {
    final String termoBusca = query.toLowerCase().trim();

    setState(() {
      if (termoBusca.isEmpty) {
        _produtosFiltrados = _produtos;
      } else {
        _produtosFiltrados = _produtos.where((produto) {
          final codigoProduto = produto.codprd.toString().toLowerCase();
          if (codigoProduto.startsWith(termoBusca)) {
            return true;
          }

          final palavrasDescricao = produto.dcrprd.toLowerCase().split(' ');
          for (var palavra in palavrasDescricao) {
            if (palavra.trim().startsWith(termoBusca)) {
              return true;
            }
          }

          final palavrasMarca = produto.nommrc.toLowerCase().split(' ');
          for (var palavra in palavrasMarca) {
            if (palavra.trim().startsWith(termoBusca)) {
              return true;
            }
          }

          return false;
        }).toList();
      }
    });
  }

  void _limparPesquisa() {
    _searchController.clear();
    setState(() {
      _produtosFiltrados = _produtos;
      _isSearching = false;
    });
    _searchFocus.unfocus();
  }

  // UTILIDADES DE UI

  void _mostrarMensagem(String mensagem, {Color? cor}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // CONSTRUÇÃO DA UI

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
                Text(
                  "Produtos",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "Cliente: ${widget.cliente!.nomcli}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Text(
              "Catálogo de Produtos",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
      actions: [
        IconButton(
          icon: _isSyncing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ))
              : Icon(Icons.sync, size: 22),
          tooltip: 'Carregar Exemplos',
          onPressed: _isSyncing ? null : _sincronizarProdutos,
        ),
        IconButton(
          icon: Icon(Icons.refresh, size: 22),
          tooltip: 'Atualizar',
          onPressed: _carregarProdutosDoDb,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: primaryColor,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _filtrarProdutos,
          decoration: InputDecoration(
            hintText: "Pesquisar produto...",
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[400], size: 18),
                    onPressed: _limparPesquisa,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      color: Colors.grey[100],
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.cliente != null) ...[
                Icon(Icons.list_alt, size: 14, color: Colors.grey[700]),
                SizedBox(width: 6),
                Text(
                  "Tabela: ${widget.cliente!.codtab}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(width: 16),
              ],
              Icon(Icons.inventory_2, size: 14, color: Colors.grey[700]),
              SizedBox(width: 6),
              Text(
                "${_produtosFiltrados.length}/${_produtos.length} produtos",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          if (_usandoDadosExemplo)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[100]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Dados de exemplo",
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_produtosFiltrados.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductGrid();
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
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando produtos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            SizedBox(height: 16),
            Text(
              'Não foi possível carregar os produtos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Ocorreu um erro desconhecido.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            OutlinedButton.icon(
              icon: Icon(Icons.sync),
              label: Text('Carregar Exemplos'),
              onPressed: _sincronizarProdutos,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(24),
      children: [
        SizedBox(height: 40),
        Icon(
          _isSearching ? Icons.search_off : Icons.inventory,
          size: 48,
          color: Colors.grey[400],
        ),
        SizedBox(height: 16),
        Text(
          _isSearching
              ? 'Nenhum produto encontrado'
              : 'Nenhum produto disponível',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          _isSearching
              ? 'Não encontramos produtos com os termos da sua pesquisa.'
              : 'Não há produtos disponíveis no banco de dados local.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            icon: Icon(_isSearching ? Icons.clear : Icons.sync),
            label: Text(_isSearching ? 'Limpar pesquisa' : 'Carregar Exemplos'),
            onPressed: _isSearching ? _limparPesquisa : _sincronizarProdutos,
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(12),
      physics: AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _produtosFiltrados.length,
      itemBuilder: (context, index) {
        Produto produto = _produtosFiltrados[index];
        return ProdutoDetalhe(
          produto: produto,
          carrinho: _carrinho,
          onAddToCart: (quantidade, desconto) async {
            await _adicionarProdutoAoCarrinho(produto, quantidade, desconto);
            setState(() {});
          },
          clienteTabela: widget.cliente?.codtab ?? 1,
        );
      },
    );
  }

  Widget _buildCartFAB() {
    final int totalItens = _carrinho.quantidadeTotal;

    return FloatingActionButton.extended(
      onPressed: _irParaCarrinho,
      backgroundColor: primaryColor,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          if (totalItens > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  '$totalItens',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: Text(
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