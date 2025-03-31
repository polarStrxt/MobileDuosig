import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/services/apiProduto.dart';
import 'package:flutter_docig_venda/widgets/cardProdutos.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/screens/carrinhoScreen.dart';
import 'package:flutter_docig_venda/widgets/carrinhoWidget.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart'; // Importação do DAO

class ProdutoScreen extends StatefulWidget {
  final Cliente? cliente; // Cliente atual para filtrar produtos específicos

  const ProdutoScreen({Key? key, this.cliente}) : super(key: key);

  @override
  _ProdutoScreenState createState() => _ProdutoScreenState();
}

class _ProdutoScreenState extends State<ProdutoScreen> {
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  List<Produto> produtos = [];
  List<Produto> produtosFiltrados = [];
  final Carrinho carrinho = Carrinho();
  bool isLoading = true;
  bool isSearching = false;
  bool isSyncing = false;
  String? errorMessage;

  // Instância do DAO de produtos
  final ProdutoDao _produtoDao = ProdutoDao();

  // Controlador para atualização por scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    carregarProdutosDoDb();

    // Limpar pesquisa quando o usuário digitar
    searchController.addListener(() {
      setState(() {
        isSearching = searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Método para carregar produtos do banco de dados local
  Future<void> carregarProdutosDoDb() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Buscar o total de produtos no banco de dados
      final db = await _produtoDao.database;
      List<Map<String, dynamic>> countResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM ${_produtoDao.tableName}');
      final int produtosCount = countResult.first['count'] as int;

      // Se não tiver produtos, tentar carregar da API
      if (produtosCount == 0) {
        setState(() {
          errorMessage = 'Não há produtos no banco de dados local.';
          isLoading = false;
        });
        return;
      }

      // Buscar todos os produtos do banco de dados
      List<Produto> lista =
          await _produtoDao.getAll((json) => Produto.fromJson(json));

      setState(() {
        produtos = lista;
        produtosFiltrados = lista;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Erro ao buscar produtos do banco de dados: $e");
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // Método para sincronizar produtos com a API e atualizar o banco de dados
  Future<void> sincronizarProdutos() async {
    setState(() {
      isSyncing = true;
      errorMessage = null;
    });

    try {
      // Buscar produtos da API
      List<Produto> produtosApi = await ProdutoService.buscarProdutos();

      // Limpar a tabela de produtos
      await _produtoDao.clearTable();

      // Inserir os novos produtos no banco de dados
      for (var produto in produtosApi) {
        await _produtoDao.insertOrUpdate(produto.toJson(), 'codprd');
      }

      // Carregar os produtos atualizados
      List<Produto> lista =
          await _produtoDao.getAll((json) => Produto.fromJson(json));

      setState(() {
        produtos = lista;
        produtosFiltrados = lista;
        isSyncing = false;
      });

      // Mostrar mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${produtosApi.length} produtos sincronizados com sucesso!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print("❌ Erro ao sincronizar produtos: $e");
      setState(() {
        isSyncing = false;
        errorMessage = 'Erro na sincronização: ${e.toString()}';
      });

      // Mostrar mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: ${e.toString()}'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Restante do código permanece igual...
  void filtrarProdutos(String query) {
    final String termoBusca = query.toLowerCase().trim();

    setState(() {
      if (termoBusca.isEmpty) {
        produtosFiltrados = produtos;
      } else {
        produtosFiltrados = produtos.where((produto) {
          return produto.dcrprd.toLowerCase().contains(termoBusca) ||
              produto.codprd.toString().contains(termoBusca) ||
              produto.nommrc.toLowerCase().contains(termoBusca);
        }).toList();
      }
    });
  }

  void limparPesquisa() {
    searchController.clear();
    setState(() {
      produtosFiltrados = produtos;
      isSearching = false;
    });
    searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Restante do código permanece igual...
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF5D5CDE),
        elevation: 0,
        title: widget.cliente != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Produtos",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Cliente: ${widget.cliente!.nomcli}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Text("Catálogo de Produtos"),
        actions: [
          // Botão para sincronizar produtos com a API
          IconButton(
            icon: isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ))
                : Icon(Icons.sync),
            tooltip: 'Sincronizar com API',
            onPressed: isSyncing ? null : sincronizarProdutos,
          ),
          // Botão para recarregar produtos do banco de dados
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Atualizar produtos',
            onPressed: carregarProdutosDoDb,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de pesquisa com estilo melhorado
          Container(
            color: Color(0xFF5D5CDE),
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                onChanged: filtrarProdutos,
                decoration: InputDecoration(
                  hintText: "Pesquisar produto por nome, código ou marca...",
                  prefixIcon: Icon(Icons.search, color: Color(0xFF5D5CDE)),
                  suffixIcon: isSearching
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: limparPesquisa,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),

          // Informações da tabela de preço e contagem de produtos
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (widget.cliente != null) ...[
                  Icon(Icons.list_alt, size: 16, color: Colors.grey[700]),
                  SizedBox(width: 8),
                  Text(
                    "Tabela: ${widget.cliente!.codtab}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 16),
                ],
                Icon(Icons.inventory_2, size: 16, color: Colors.grey[700]),
                SizedBox(width: 8),
                Text(
                  "${produtosFiltrados.length}/${produtos.length} produtos",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Conteúdo principal
          Expanded(
            child: RefreshIndicator(
              onRefresh: carregarProdutosDoDb,
              color: Color(0xFF5D5CDE),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildCartFAB(),
    );
  }

  // Os métodos abaixo permanecem inalterados...
  Widget _buildMainContent() {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (produtosFiltrados.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductGrid();
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
            'Carregando produtos...',
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
              'Erro ao carregar produtos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              errorMessage ?? 'Ocorreu um erro desconhecido.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            // Botão para sincronizar (se não há produtos no banco de dados)
            ElevatedButton.icon(
              icon: Icon(Icons.sync),
              label: Text('Sincronizar produtos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: sincronizarProdutos,
            ),
            SizedBox(height: 12),
            // Botão para recarregar do banco de dados
            TextButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Verificar banco de dados'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF5D5CDE),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: carregarProdutosDoDb,
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
          isSearching ? Icons.search_off : Icons.inventory,
          size: 70,
          color: Colors.grey[400],
        ),
        SizedBox(height: 16),
        Text(
          isSearching
              ? 'Nenhum produto encontrado'
              : 'Nenhum produto disponível',
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
            isSearching
                ? 'Não encontramos produtos com os termos da sua pesquisa.'
                : 'Não há produtos disponíveis no banco de dados local.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: 24),
        if (isSearching)
          Center(
            child: TextButton.icon(
              icon: Icon(Icons.clear),
              label: Text('Limpar pesquisa'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF5D5CDE),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: limparPesquisa,
            ),
          )
        else
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.sync),
              label: Text('Sincronizar com a API'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: sincronizarProdutos,
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
        childAspectRatio: 0.8, // Aumentado para evitar overflow
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: produtosFiltrados.length,
      itemBuilder: (context, index) {
        Produto produto = produtosFiltrados[index];
        return ProdutoDetalhe(
          produto: produto,
          carrinho: carrinho,
          onAddToCart: () {
            setState(() {}); // Atualiza a UI quando adicionar ao carrinho
          },
          clienteTabela: widget.cliente?.codtab ?? 1,
        );
      },
    );
  }

  Widget _buildCartFAB() {
    final int totalItens = carrinho.quantidadeTotal;

    return FloatingActionButton.extended(
      onPressed: () {
        // Verifica se há itens no carrinho
        if (totalItens == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'O carrinho está vazio. Adicione produtos para continuar.'),
              backgroundColor: Colors.grey[800],
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        // Cria o CarrinhoWidget e navega para a tela
// No método _buildCartFAB() do ProdutoScreen
        final CarrinhoWidget carrinhoWidget = CarrinhoWidget(
          itens: carrinho.itens,
          cliente: widget.cliente,
          descontos: carrinho.descontos, // Adicionando os descontos aqui
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarrinhoScreen(carrinho: carrinhoWidget),
          ),
        ).then((_) {
          // Atualiza a UI quando retornar do carrinho
          setState(() {});
        });
      },
      backgroundColor: Color(0xFF5D5CDE),
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shopping_cart, color: Colors.white),
          if (totalItens > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  '$totalItens',
                  style: TextStyle(
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
      label: Text(
        "Ver carrinho",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      elevation: 4,
    );
  }
}
