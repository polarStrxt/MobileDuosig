import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/screens/carrinhoScreen.dart';
import 'package:logger/logger.dart';

class AdicionarProdutoScreen extends StatefulWidget {
  final Cliente? cliente;

  const AdicionarProdutoScreen({super.key, this.cliente});

  @override
  State<AdicionarProdutoScreen> createState() => _AdicionarProdutoScreenState();
}

class _AdicionarProdutoScreenState extends State<AdicionarProdutoScreen> {
  // Constantes
  static const Color kPrimaryColor = Color(0xFF5D5CDE);
  static const Color kErrorColor = Color(0xFFE53935);
  static const Color kSuccessColor = Color(0xFF43A047);
  static const Color kBackgroundColor = Colors.white;
  static const Color kSurfaceColor = Color(0xFFF5F5F5);
  static const Color kTextPrimaryColor = Color(0xFF212121);
  static const Color kTextSecondaryColor = Color(0xFF757575);

  // Controllers e Focus Nodes
  final TextEditingController _codigoProdutoController =
      TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _descontoController = TextEditingController();
  final FocusNode _codigoFocusNode = FocusNode();
  final FocusNode _quantidadeFocusNode = FocusNode();
  final FocusNode _descontoFocusNode = FocusNode();

  // Estado
  ProdutoModel? _produtoSelecionado;
  bool _isLoading = false;
  String? _errorMessage;

  // DAOs e Services
  final ProdutoDao _produtoDao = ProdutoDao();
  final CarrinhoService _carrinhoService = CarrinhoService();
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  void _inicializar() {
    _quantidadeController.text = '1'; // Começar com 1 é mais prático
    _descontoController.text = '0';
    _verificarCarrinhoExistente();
  }

  @override
  void dispose() {
    _codigoProdutoController.dispose();
    _quantidadeController.dispose();
    _descontoController.dispose();
    _codigoFocusNode.dispose();
    _quantidadeFocusNode.dispose();
    _descontoFocusNode.dispose();
    super.dispose();
  }

  // CARRINHO E DADOS

  Future<void> _verificarCarrinhoExistente() async {
    if (widget.cliente == null) return;
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);

    // Só verificar se o carrinho atual estiver vazio
    if (carrinhoProvider.isEmpty) {
      setState(() => _isLoading = true);
      
      try {
        // Verificar se o cliente tem itens pendentes no carrinho
        // Usando clienteTemCarrinhoPendente em vez de verificarSeClienteTemCarrinhoPendente
        final resultado = await _carrinhoService.clienteTemCarrinhoPendente(widget.cliente!);
        
        if (mounted && resultado.isSuccess && resultado.data == true) {
          final deveRecuperar = await _mostrarDialogCarrinhoPendente();
          if (mounted && deveRecuperar == true) {
            await _recuperarItensCarrinho();
          }
        }
      } catch (e) {
        _logErro('Erro ao verificar carrinho existente', e);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool?> _mostrarDialogCarrinhoPendente() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.shopping_cart, color: kPrimaryColor, size: 20),
            SizedBox(width: 8),
            Text("Carrinho Pendente", style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("IGNORAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
            ),
            child: const Text("RECUPERAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _recuperarItensCarrinho() async {
    if (widget.cliente == null || !mounted) return;
    
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    
    setState(() => _isLoading = true);
    
    try {
      final resultado = await _carrinhoService.recuperarCarrinho(widget.cliente!);
      
      if (mounted) {
        if (resultado.isSuccess) {
          // Limpar o carrinho atual no provider
          carrinhoProvider.limpar();
          
          // Recuperar itens e descontos
          _logger.i('Itens recuperados: ${resultado.data?.itens.length ?? 0}');
          
          // Notificações serão enviadas automaticamente pelo Provider
          // após todas as adições estarem concluídas
          setState(() {}); // Atualizar UI após recuperação
          
          _mostrarMensagem(
            "Carrinho recuperado com sucesso",
            cor: kSuccessColor,
          );
        } else {
          _logErro('Falha ao recuperar carrinho', resultado.errorMessage);
          _mostrarMensagem(
            "Erro ao recuperar carrinho: ${resultado.errorMessage}",
            cor: kErrorColor,
          );
        }
      }
    } catch (e) {
      _logErro('Erro ao recuperar itens do carrinho', e);
      if (mounted) {
        _mostrarMensagem(
          "Erro ao recuperar carrinho: $e",
          cor: kErrorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buscarProdutoPorCodigo() async {
    final codigoStr = _codigoProdutoController.text.trim();
    if (codigoStr.isEmpty) {
      _mostrarMensagem('Digite o código do produto', cor: kErrorColor);
      return;
    }

    final codigo = int.tryParse(codigoStr);
    if (codigo == null) {
      _mostrarMensagem('Código de produto inválido', cor: kErrorColor);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _produtoSelecionado = null;
    });

    try {
      final produto = await _produtoDao.getProdutoByCodigo(codigo);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _produtoSelecionado = produto;
        });

        if (produto == null) {
          _mostrarMensagem('Produto não encontrado', cor: kErrorColor);
        } else {
          _quantidadeFocusNode.requestFocus();
        }
      }
    } catch (e) {
      _logErro('Erro ao buscar produto', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro ao buscar produto: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _adicionarAoCarrinho() async {
    if (_produtoSelecionado == null) {
      _mostrarMensagem('Selecione um produto primeiro', cor: kErrorColor);
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem('Selecione um cliente para adicionar ao carrinho',
          cor: kErrorColor);
      return;
    }

    // Validar quantidade
    final quantidade = int.tryParse(_quantidadeController.text) ?? 0;
    if (quantidade <= 0) {
      _mostrarMensagem('A quantidade deve ser maior que zero',
          cor: kErrorColor);
      return;
    }

    // Validar desconto
    final desconto = double.tryParse(_descontoController.text) ?? 0;
    if (desconto < 0 || desconto > 100) {
      _mostrarMensagem('O desconto deve estar entre 0 e 100%',
          cor: kErrorColor);
      return;
    }

    try {
      // Obter o carrinho via Provider
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      
      // Adicionar ao carrinho em memória (via Provider)
      carrinhoProvider.adicionarItem(_produtoSelecionado!, quantidade, desconto);
      
      // Feedback imediato e preparar para próximo produto
      setState(() {
        _produtoSelecionado = null;
        _codigoProdutoController.clear();
        _quantidadeController.text = '1';
        _descontoController.text = '0';
      });
      
      _codigoFocusNode.requestFocus();
      _mostrarMensagem('Produto adicionado ao carrinho', cor: kSuccessColor);
      
      // Persistir alterações no banco de dados
      _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
        .then((resultado) {
          if (!resultado.isSuccess && mounted) {
            _logErro('Falha ao salvar alterações no carrinho', resultado.errorMessage);
            _mostrarMensagem('Erro ao salvar carrinho: ${resultado.errorMessage}',
                cor: kErrorColor);
          }
        });
    } catch (e) {
      _logErro('Erro ao adicionar produto ao carrinho', e);
      _mostrarMensagem('Erro ao adicionar produto: ${e.toString()}',
          cor: kErrorColor);
    }
  }

  void _navegarParaCarrinho() {
    // Verificar estado do carrinho via Provider
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    
    if (carrinhoProvider.isEmpty) {
      _mostrarMensagem('O carrinho está vazio', cor: kTextSecondaryColor);
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem('Selecione um cliente primeiro', cor: kErrorColor);
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
      if (mounted) {
        setState(() {
          // Atualizar UI após retornar do carrinho se necessário
        });
      }
    });
  }

  // UTILIDADES

  void _mostrarMensagem(String mensagem, {required Color cor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _logErro(String mensagem, dynamic erro) {
    _logger.e('$mensagem: $erro');
  }

  // Função para obter o valor do produto de acordo com a tabela de preço do cliente
  double _getValorProdutoTabela(ProdutoModel produto) {
    if (widget.cliente == null) {
      return produto.vlrbasvda; // Valor padrão se não houver cliente
    }

    // Verificar qual tabela de preço usar com base no codtab do cliente
    switch (widget.cliente!.codtab) {
      case 1:
        return produto.vlrtab1 != null ? produto.vlrtab1! : produto.vlrbasvda;
      case 2:
        return produto.vlrtab2 != null ? produto.vlrtab2! : produto.vlrbasvda;
      default:
        return produto.vlrbasvda; // Valor padrão para outras tabelas
    }
  }

  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _construirAppBar(),
      body: _construirCorpo(),
      floatingActionButton: _construirBotaoCarrinho(),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: kPrimaryColor,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Adicionar Produto",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.cliente != null)
            Text(
              "Cliente: ${widget.cliente!.nomcli}",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _construirCorpo() {
    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _construirBarraInfo(),
            const SizedBox(height: 24),
            _construirCampoCodigo(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                  ),
                ),
              )
            else if (_produtoSelecionado != null) ...[
              _construirDetalhesProduto(),
              const SizedBox(height: 24),
              _construirCampoQuantidade(),
              const SizedBox(height: 16),
              _construirCampoDesconto(),
              const SizedBox(height: 24),
              _construirBotaoAdicionar(),
            ] else if (_errorMessage != null)
              _construirMensagemErro(),
          ],
        ),
      ),
    );
  }

  Widget _construirBarraInfo() {
    // Usando Selector para apenas reconstruir quando a quantidade mudar
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, quantidadeTotal, _) {
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: kSurfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 16, color: kTextSecondaryColor),
                const SizedBox(width: 8),
                Text(
                  "Itens no carrinho: $quantidadeTotal",
                  style: const TextStyle(
                    fontSize: 14,
                    color: kTextSecondaryColor,
                  ),
                ),
                if (widget.cliente != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.list_alt_outlined,
                      size: 16, color: kTextSecondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    "Tabela: ${widget.cliente!.codtab}",
                    style: const TextStyle(
                      fontSize: 14,
                      color: kTextSecondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirCampoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Código do Produto",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codigoProdutoController,
          focusNode: _codigoFocusNode,
          decoration: InputDecoration(
            hintText: "Digite o código do produto",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_outlined, color: kPrimaryColor),
              onPressed: _buscarProdutoPorCodigo,
            ),
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _buscarProdutoPorCodigo(),
        ),
      ],
    );
  }

  Widget _construirDetalhesProduto() {
    final produto = _produtoSelecionado!;
    // Usar qtdetq em vez de qtdest para verificar o estoque
    final estoqueDisponivel = (produto.qtdetq ?? 0) > 0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "#${produto.codprd}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    produto.dcrprd,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Marca: ${produto.nommrc}",
              style: const TextStyle(
                color: kTextSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "R\$ ${_getValorProdutoTabela(produto).toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: kPrimaryColor,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estoqueDisponivel
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    estoqueDisponivel
                        ? "Em estoque: ${produto.qtdetq}" 
                        : "Sem estoque",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: estoqueDisponivel ? kSuccessColor : kErrorColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCampoQuantidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quantidade",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _quantidadeController,
          focusNode: _quantidadeFocusNode,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _descontoFocusNode.requestFocus(),
        ),
      ],
    );
  }

  Widget _construirCampoDesconto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Desconto (%)",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descontoController,
          focusNode: _descontoFocusNode,
          decoration: InputDecoration(
            suffixText: "%",
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: kPrimaryColor),
            ),
          ),
          style: const TextStyle(fontSize: 16),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}$')),
          ],
          onSubmitted: (_) => _adicionarAoCarrinho(),
        ),
      ],
    );
  }

  Widget _construirBotaoAdicionar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _adicionarAoCarrinho,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          "ADICIONAR AO CARRINHO",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _construirMensagemErro() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kErrorColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? "Produto não encontrado",
              style: const TextStyle(
                color: kErrorColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotaoCarrinho() {
    // Usando Selector para reconstruir apenas quando a quantidade mudar
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, totalItens, _) {
        return FloatingActionButton.extended(
          onPressed: _navegarParaCarrinho,
          backgroundColor: kPrimaryColor,
          elevation: 2,
          icon: Badge(
            isLabelVisible: totalItens > 0,
            label: Text(
              '$totalItens',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Icon(Icons.shopping_cart_outlined,
                color: Colors.white, size: 20),
          ),
          label: const Text(
            "Carrinho",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}