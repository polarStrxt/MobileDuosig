import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';

class ProdutoDetalhe extends StatefulWidget {
  final Produto produto;
  final Carrinho carrinho;
  final VoidCallback onAddToCart;
  final int clienteTabela; // Tabela de preço do cliente

  const ProdutoDetalhe({
    Key? key,
    required this.produto,
    required this.carrinho,
    required this.onAddToCart,
    this.clienteTabela = 1, // Padrão: tabela 1
  }) : super(key: key);

  @override
  _ProdutoDetalheState createState() => _ProdutoDetalheState();
}

class _ProdutoDetalheState extends State<ProdutoDetalhe> {
  int quantidade = 1;

  // Obter o preço correto baseado na tabela de preço do cliente
  double get precoAtual {
    // Se cliente usa tabela 1, use vlrtab1, senão use vlrtab2
    return widget.clienteTabela == 1
        ? widget.produto.vlrtab1
        : widget.produto.vlrtab2;
  }

  // Formatar preço para exibição
  String formatarPreco(double preco) {
    return 'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Verificar se o produto já está no carrinho
  bool get isProdutoNoCarrinho =>
      widget.carrinho.itens.containsKey(widget.produto);

  // Obter quantidade do produto no carrinho, se houver
  int get quantidadeNoCarrinho => widget.carrinho.itens[widget.produto] ?? 0;

  // Correção específica para o Column na linha 82 do cardProdutos.dart
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _mostrarDetalhesProduto(context);
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // Garantir que o Card tenha um tamanho adequado
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Usar LayoutBuilder para ter mais controle sobre o layout
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem ou placeholder (altura adaptativa)
                Container(
                  // Ajustar altura com base no espaço disponível
                  height: constraints.maxHeight * 0.4, // 40% do espaço total
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.inventory_2,
                      size: 32, // Tamanho reduzido
                      color: Color(0xFF5D5CDE),
                    ),
                  ),
                ),

                // Conteúdo do card (60% do espaço restante)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8), // Padding reduzido
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min, // Usar apenas espaço necessário
                      children: [
                        // Código do produto
                        Text(
                          'Cód: ${widget.produto.codprd}',
                          style: TextStyle(
                            fontSize: 10, // Fonte menor
                            color: Colors.grey[600],
                          ),
                        ),

                        SizedBox(height: 2), // Espaçamento menor

                        // Nome do produto
                        Flexible(
                          child: Text(
                            widget.produto.dcrprd,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12, // Fonte menor
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        Spacer(flex: 1), // Espaço flexível

                        // Marca do produto
                        Text(
                          widget.produto.nommrc,
                          style: TextStyle(
                            fontSize: 10, // Fonte menor
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 2), // Espaçamento menor

                        // Preço do produto
                        Text(
                          formatarPreco(precoAtual),
                          style: TextStyle(
                            fontSize: 12, // Fonte menor
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),

                        SizedBox(height: 4), // Espaçamento menor

                        // Botão de adicionar ao carrinho
                        SizedBox(
                          width: double.infinity,
                          height: 28, // Altura fixa menor
                          child: ElevatedButton(
                            onPressed: () {
                              _adicionarAoCarrinho();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isProdutoNoCarrinho
                                  ? Colors.green[600]
                                  : Color(0xFF5D5CDE),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 8), // Padding menor
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    6), // Bordas menos arredondadas
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isProdutoNoCarrinho
                                    ? '${quantidadeNoCarrinho}x no carrinho'
                                    : 'Adicionar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10, // Fonte menor
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _adicionarAoCarrinho() {
    widget.carrinho.adicionarItem(widget.produto, quantidade);
    widget.onAddToCart();

    // Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.produto.dcrprd} adicionado ao carrinho'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarDetalhesProduto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetalheProdutoModal(
        produto: widget.produto,
        carrinho: widget.carrinho,
        onAddToCart: widget.onAddToCart,
        clienteTabela: widget.clienteTabela,
      ),
    );
  }
}

// Widget de modal para detalhes do produto
class _DetalheProdutoModal extends StatefulWidget {
  final Produto produto;
  final Carrinho carrinho;
  final VoidCallback onAddToCart;
  final int clienteTabela;

  const _DetalheProdutoModal({
    Key? key,
    required this.produto,
    required this.carrinho,
    required this.onAddToCart,
    required this.clienteTabela,
  }) : super(key: key);

  @override
  __DetalheProdutoModalState createState() => __DetalheProdutoModalState();
}

class __DetalheProdutoModalState extends State<_DetalheProdutoModal> {
  final TextEditingController _quantidadeController =
      TextEditingController(text: "1");
  final TextEditingController _descontoController =
      TextEditingController(text: "0");
  final FocusNode _quantidadeFocus = FocusNode();
  final FocusNode _descontoFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int quantidade = 1;
  double desconto = 0.0;

  // Chave global para o widget que contém os campos de entrada
  final GlobalKey _inputSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _quantidadeController.addListener(_atualizarQuantidade);
    _descontoController.addListener(_atualizarDesconto);

    // Adicionar listeners aos FocusNodes para rolar até o campo quando ele receber foco
    _quantidadeFocus.addListener(_scrollToFocusedInput);
    _descontoFocus.addListener(_scrollToFocusedInput);
  }

  @override
  void dispose() {
    _quantidadeController.removeListener(_atualizarQuantidade);
    _descontoController.removeListener(_atualizarDesconto);
    _quantidadeFocus.removeListener(_scrollToFocusedInput);
    _descontoFocus.removeListener(_scrollToFocusedInput);
    _quantidadeController.dispose();
    _descontoController.dispose();
    _quantidadeFocus.dispose();
    _descontoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Função para rolar até o campo de entrada focado
  void _scrollToFocusedInput() {
    // Verificar se algum campo tem foco
    if (_quantidadeFocus.hasFocus || _descontoFocus.hasFocus) {
      // Aguardar para garantir que o teclado já está visível
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // Rolar até a seção de entrada
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

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
        // Se perdscmxm > 0, limitar o desconto a esse valor
        double descontoFinal = valor > descontoMaximo ? descontoMaximo : valor;

        setState(() {
          desconto = descontoFinal;
          if (descontoFinal != valor) {
            // Ajustar o texto se o valor exceder o máximo
            _descontoController.text = descontoFinal.toString();
          }
        });
      } else {
        // Se perdscmxm = 0, permitir qualquer valor de desconto
        setState(() {
          desconto = valor;
        });
      }
    }
  }

  // Verificar se há limite de desconto (perdscmxm > 0)
  bool get temLimiteDesconto {
    return widget.produto.perdscmxm > 0;
  }

  // Obter o valor máximo de desconto
  double get descontoMaximo {
    return widget.produto.perdscmxm;
  }

  // Obter o preço correto baseado na tabela de preço do cliente
  double get precoAtual {
    // Se cliente usa tabela 1, use vlrtab1, senão use vlrtab2
    return widget.clienteTabela == 1
        ? widget.produto.vlrtab1
        : widget.produto.vlrtab2;
  }

  // Obter o preço com desconto aplicado
  double get precoComDesconto {
    return precoAtual * (1 - desconto / 100);
  }

  // Formatar preço para exibição
  String formatarPreco(double preco) {
    return 'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    // MUDANÇA AQUI: Usar MediaQuery.viewInsetsBottom para ajustar ao teclado
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;

    // Usar um fraction para definir a altura máxima do modal (70% da tela)
    return FractionallySizedBox(
      heightFactor: 0.9, // Modal ocupa 90% da altura da tela
      child: Padding(
        // Adicionar padding inferior dinâmico quando o teclado estiver visível
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Barra de título com botão fechar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF5D5CDE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalhes do Produto',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        // Fechar teclado antes de fechar o modal
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Conteúdo do modal - CORREÇÃO PARA O PROBLEMA NA LINHA 82
              Expanded(
                child: ListView(
                  controller: _scrollController, // Usar o ScrollController
                  padding: EdgeInsets.all(16),
                  children: [
                    // Imagem ou placeholder
                    Center(
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.inventory_2,
                            size: 50,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Código do produto
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Cód: ${widget.produto.codprd}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Nome do produto
                    Text(
                      widget.produto.dcrprd,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),

                    SizedBox(height: 8),

                    // Marca
                    Text(
                      "Marca: ${widget.produto.nommrc}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Seção de preço
                    _buildInfoSection(
                      'Preço na Tabela ${widget.clienteTabela}',
                      formatarPreco(precoAtual),
                      fontSize: 18,
                      color: Color(0xFF5D5CDE),
                    ),

                    // Preço com desconto (quando houver)
                    if (desconto > 0)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Text(
                              'Preço com desconto:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              formatarPreco(precoComDesconto),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 6),

                    // Preço da outra tabela (informativo)
                    _buildInfoSection(
                      'Preço na Tabela ${widget.clienteTabela == 1 ? 2 : 1}',
                      formatarPreco(widget.clienteTabela == 1
                          ? widget.produto.vlrtab2
                          : widget.produto.vlrtab1),
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),

                    Divider(height: 24),

                    // Informações adicionais do produto combinadas para economizar espaço
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip('Unidade', widget.produto.codundprd),
                        _buildInfoChip('Volume', '${widget.produto.vol}'),
                        if (widget.produto.qtdetq != null)
                          _buildInfoChip('Estoque', '${widget.produto.qtdetq}'),
                        _buildInfoChip('Qtd/Vol', '${widget.produto.qtdvol}'),
                        _buildInfoChip(
                            'Múlt. Venda', '${widget.produto.qtdmulvda}'),
                        _buildInfoChip(
                          'Desc. Máx',
                          temLimiteDesconto
                              ? '${descontoMaximo}%'
                              : 'Sem limite',
                          chipColor: temLimiteDesconto
                              ? Colors.orange[700]
                              : Colors.green[700],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    Divider(height: 16),

                    // Seção de campos de entrada (com chave global para rolagem)
                    Container(
                      key: _inputSectionKey,
                      child: Column(
                        children: [
                          // Campo para digitar quantidade
                          Row(
                            children: [
                              Text(
                                'Quantidade:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              Container(
                                width: 100,
                                child: TextField(
                                  controller: _quantidadeController,
                                  focusNode: _quantidadeFocus,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onEditingComplete: () {
                                    FocusScope.of(context)
                                        .requestFocus(_descontoFocus);
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12),

                          // Campo para informar desconto
                          Row(
                            children: [
                              Text(
                                'Desconto (%):',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              Container(
                                width: 100,
                                child: TextField(
                                  controller: _descontoController,
                                  focusNode: _descontoFocus,
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    suffixText: '%',
                                    hintText: temLimiteDesconto
                                        ? 'Máx: ${descontoMaximo}%'
                                        : 'Sem limite',
                                    hintStyle: TextStyle(fontSize: 10),
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  onEditingComplete: () {
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16),

                          // Total calculado
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formatarPreco(precoComDesconto * quantidade),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5D5CDE),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Espaço adicional para garantir que o botão não cubra conteúdo importante
                          SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Barra inferior com botão de adicionar ao carrinho
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      // Fechar teclado
                      FocusScope.of(context).unfocus();

                      // Adicionar ao carrinho com o desconto
                      widget.carrinho
                          .adicionarItem(widget.produto, quantidade, desconto);
                      widget.onAddToCart();
                      Navigator.pop(context);

                      // Feedback visual
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '${quantidade}x ${widget.produto.dcrprd} adicionado ao carrinho${desconto > 0 ? ' com ${desconto.toStringAsFixed(1)}% de desconto' : ''}'),
                          backgroundColor: Colors.green[600],
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5D5CDE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Adicionar ao Carrinho',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para construir seções de informação em formato mais compacto
  Widget _buildInfoChip(String label, String value, {Color? chipColor}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (chipColor ?? Color(0xFF5D5CDE)).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (chipColor ?? Color(0xFF5D5CDE)).withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: chipColor ?? Color(0xFF5D5CDE),
        ),
      ),
    );
  }

  // Widget para construir seções de informação
  Widget _buildInfoSection(String label, String value,
      {double? fontSize, Color? color}) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
