import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';

class ProdutoDetalhe extends StatelessWidget {
  final Produto produto;
  final Carrinho carrinho;
  final void Function(int quantidade, double desconto) onAddToCart;
  final int clienteTabela;

  const ProdutoDetalhe({
    Key? key,
    required this.produto,
    required this.carrinho,
    required this.onAddToCart,
    this.clienteTabela = 1,
  }) : super(key: key);

  // CÁLCULOS E FORMATAÇÃO

  double get precoAtual =>
      clienteTabela == 1 ? produto.vlrtab1 : produto.vlrtab2;

  String formatarPreco(double preco) =>
      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';

  bool get isProdutoNoCarrinho => carrinho.itens.containsKey(produto);

  int get quantidadeNoCarrinho => carrinho.itens[produto] ?? 0;

  void _adicionarAoCarrinho(BuildContext context) {
    carrinho.adicionarItem(produto, 1, 0);
    onAddToCart(1, 0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${produto.dcrprd} adicionado ao carrinho'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green[700],
      ),
    );
  }

  void _mostrarDetalhesProduto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProdutoDetalheModal(
        produto: produto,
        carrinho: carrinho,
        onAddToCart: onAddToCart,
        clienteTabela: clienteTabela,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarDetalhesProduto(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem ou ícone
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey[100],
                width: double.infinity,
                child: Icon(
                  Icons.inventory_2,
                  color: Color(0xFF5D5CDE),
                  size: 24,
                ),
              ),
            ),
            // Informações do produto
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Código
                    Text(
                      'Cód: ${produto.codprd}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),

                    // Nome do produto
                    Expanded(
                      child: Text(
                        produto.dcrprd,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Marca
                    Text(
                      produto.nommrc,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Preço
                    SizedBox(height: 4),
                    Text(
                      formatarPreco(precoAtual),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5D5CDE),
                      ),
                    ),

                    // Botão de adicionar
                    SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: TextButton(
                        onPressed: () => _adicionarAoCarrinho(context),
                        style: TextButton.styleFrom(
                          backgroundColor: isProdutoNoCarrinho
                              ? Colors.green[700]
                              : Color(0xFF5D5CDE),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          isProdutoNoCarrinho
                              ? '${quantidadeNoCarrinho}x no carrinho'
                              : 'Adicionar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProdutoDetalheModal extends StatefulWidget {
  final Produto produto;
  final Carrinho carrinho;
  final void Function(int quantidade, double desconto) onAddToCart;
  final int clienteTabela;

  const ProdutoDetalheModal({
    Key? key,
    required this.produto,
    required this.carrinho,
    required this.onAddToCart,
    required this.clienteTabela,
  }) : super(key: key);

  @override
  _ProdutoDetalheModalState createState() => _ProdutoDetalheModalState();
}

class _ProdutoDetalheModalState extends State<ProdutoDetalheModal> {
  // Controllers
  final TextEditingController _quantidadeController =
      TextEditingController(text: "1");
  final TextEditingController _descontoController =
      TextEditingController(text: "0");
  final FocusNode _quantidadeFocus = FocusNode();
  final FocusNode _descontoFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Estado
  int quantidade = 1;
  double desconto = 0.0;
  final Color primaryColor = Color(0xFF5D5CDE);

  @override
  void initState() {
    super.initState();
    _quantidadeController.addListener(_atualizarQuantidade);
    _descontoController.addListener(_atualizarDesconto);
    _quantidadeFocus.addListener(_handleFocusChange);
    _descontoFocus.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _quantidadeController.removeListener(_atualizarQuantidade);
    _descontoController.removeListener(_atualizarDesconto);
    _quantidadeFocus.removeListener(_handleFocusChange);
    _descontoFocus.removeListener(_handleFocusChange);
    _quantidadeController.dispose();
    _descontoController.dispose();
    _quantidadeFocus.dispose();
    _descontoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // CÁLCULOS E FORMATAÇÃO

  void _atualizarQuantidade() {
    final valor = int.tryParse(_quantidadeController.text);
    if (valor != null && valor > 0) {
      setState(() {
        quantidade = valor;
      });
    }
  }

  void _atualizarDesconto() {
    final valor = double.tryParse(_descontoController.text);
    if (valor != null && valor >= 0) {
      if (temLimiteDesconto) {
        final descontoFinal = valor > descontoMaximo ? descontoMaximo : valor;
        setState(() {
          desconto = descontoFinal;
          if (descontoFinal != valor) {
            _descontoController.text = descontoFinal.toString();
          }
        });
      } else {
        setState(() {
          desconto = valor;
        });
      }
    }
  }

  void _handleFocusChange() {
    if (_quantidadeFocus.hasFocus || _descontoFocus.hasFocus) {
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  bool get temLimiteDesconto => widget.produto.perdscmxm > 0;
  double get descontoMaximo => widget.produto.perdscmxm;
  double get precoAtual => widget.clienteTabela == 1
      ? widget.produto.vlrtab1
      : widget.produto.vlrtab2;
  double get precoComDesconto => precoAtual * (1 - desconto / 100);

  String formatarPreco(double preco) {
    return 'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // AÇÕES

  void _adicionarAoCarrinho() {
    // Fechar teclado
    FocusScope.of(context).unfocus();

    // Adicionar ao carrinho
    widget.carrinho.adicionarItem(widget.produto, quantidade, desconto);
    widget.onAddToCart(quantidade, desconto);
    Navigator.pop(context);

    // Feedback
    String mensagem =
        '${quantidade}x ${widget.produto.dcrprd} adicionado ao carrinho';
    if (desconto > 0) {
      mensagem += ' com ${desconto.toStringAsFixed(1)}% de desconto';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // WIDGETS

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.only(bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(child: _buildContent()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Detalhes do Produto',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      children: [
        // Cabeçalho
        _buildCodigoProduto(),
        SizedBox(height: 12),
        _buildInfoProduto(),
        SizedBox(height: 16),

        // Preços
        _buildSecaoPrecos(),
        SizedBox(height: 16),
        Divider(height: 1),
        SizedBox(height: 16),

        // Características do produto
        _buildCaracteristicas(),
        SizedBox(height: 16),
        Divider(height: 1),
        SizedBox(height: 16),

        // Campos de entrada
        _buildCamposEntrada(),
        SizedBox(height: 80), // Espaço extra para scroll
      ],
    );
  }

  Widget _buildCodigoProduto() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: Colors.grey[300]!), // Usando Border.all em vez de BorderSide
      ),
      child: Text(
        'Código: ${widget.produto.codprd}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoProduto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.produto.dcrprd,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Marca: ${widget.produto.nommrc}",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoPrecos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preço atual
        Row(
          children: [
            Text(
              'Preço na Tabela ${widget.clienteTabela}:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(width: 8),
            Text(
              formatarPreco(precoAtual),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: primaryColor,
              ),
            ),
          ],
        ),

        // Preço com desconto (quando houver)
        if (desconto > 0) ...[
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Preço com desconto:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(width: 8),
              Text(
                formatarPreco(precoComDesconto),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],

        // Preço alternativo
        SizedBox(height: 4),
        Text(
          'Preço na Tabela ${widget.clienteTabela == 1 ? "2" : "1"}: ${formatarPreco(widget.clienteTabela == 1 ? widget.produto.vlrtab2 : widget.produto.vlrtab1)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCaracteristicas() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoTag('Unidade', widget.produto.codundprd),
        _buildInfoTag('Volume', '${widget.produto.vol}'),
        if (widget.produto.qtdetq != null)
          _buildInfoTag('Estoque', '${widget.produto.qtdetq}'),
        _buildInfoTag('Qtd/Vol', '${widget.produto.qtdvol}'),
        _buildInfoTag('Múlt. Venda', '${widget.produto.qtdmulvda}'),
        _buildInfoTag(
          'Desc. Máx',
          temLimiteDesconto ? '${descontoMaximo}%' : 'Sem limite',
          color: temLimiteDesconto ? Colors.orange[700] : Colors.green[700],
        ),
      ],
    );
  }

  Widget _buildInfoTag(String label, String value, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: (color ?? primaryColor)
                .withOpacity(0.3)), // Usando Border.all em vez de BorderSide
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          color: color ?? primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCamposEntrada() {
    return Column(
      children: [
        // Quantidade
        Row(
          children: [
            Text(
              'Quantidade:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Spacer(),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _quantidadeController,
                focusNode: _quantidadeFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 13),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onEditingComplete: () =>
                    FocusScope.of(context).requestFocus(_descontoFocus),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        // Desconto
        Row(
          children: [
            Text(
              'Desconto (%):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Spacer(),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _descontoController,
                focusNode: _descontoFocus,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  isDense: true,
                  suffixText: '%',
                  hintText: temLimiteDesconto
                      ? 'Máx: ${descontoMaximo}%'
                      : 'Sem limite',
                  hintStyle: TextStyle(fontSize: 10),
                ),
                style: TextStyle(fontSize: 13),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onEditingComplete: () => FocusScope.of(context).unfocus(),
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Total
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors
                    .grey[300]!), // Usando Border.all em vez de BorderSide
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                formatarPreco(precoComDesconto * quantidade),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(
                color:
                    Colors.grey[200]!)), // Usando Border com um lado específico
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: _adicionarAoCarrinho,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(
            'Adicionar ao Carrinho',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}