// lib/widgets/card_produtos.dart (Nome de arquivo sugerido)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Necessário para Provider.of
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart'; // Seu ChangeNotifier

// Constantes de cor, se usadas apenas aqui, podem ficar aqui.
// Se usadas globalmente, defina em um arquivo de tema ou constantes.
const Color kCardPrimaryColor = Color(0xFF5D5CDE);
const Color kCardSuccessColor = Color(0xFF43A047);

class ProdutoDetalhe extends StatelessWidget {
  final ProdutoModel produto;
  // Callback para notificar a tela pai sobre a intenção de adicionar ao carrinho
  final void Function(int quantidade, double descontoPercentual) onAddToCart;
  final int clienteTabela;

  const ProdutoDetalhe({
    super.key, // Usando super.key
    required this.produto,
    required this.onAddToCart, // Este callback é crucial
    this.clienteTabela = 1,
  });
  // O parâmetro 'Carrinho carrinho' foi REMOVIDO daqui

  double get precoAtual =>
      clienteTabela == 1 ? produto.vlrtab1 : produto.vlrtab2;

  String formatarPreco(double preco) =>
      'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';

  void _mostrarDetalhesProduto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // O Modal não precisa mais do 'carrinho' passado diretamente.
        // Ele usará o mesmo onAddToCart ou Provider.of<Carrinho>(modalContext) internamente se precisar LER algo.
        return ProdutoDetalheModal(
          produto: produto,
          onAddToCart: onAddToCart, // Passa o mesmo callback
          clienteTabela: clienteTabela,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Para ler o estado atual do carrinho (ex: para o texto do botão)
    // Usamos Provider.of<Carrinho>(context) que OUVE as mudanças.
    final carrinhoProvider = Provider.of<Carrinho>(context);
    final bool isProdutoNoCarrinho = carrinhoProvider.itens.containsKey(produto);
    final int quantidadeNoCarrinho = carrinhoProvider.itens[produto] ?? 0;

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
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey[100],
                width: double.infinity,
                child: Icon(
                  Icons.inventory_2_outlined, // Ícone genérico
                  color: kCardPrimaryColor.withOpacity(0.7),
                  size: 40, // Aumentado para melhor visualização
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Para espaçar o conteúdo
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cód: ${produto.codprd ?? "N/A"}', // Acesso seguro
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          produto.dcrprd,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                          maxLines: 2, // Ajustado para 2 linhas
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          produto.nommrc,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatarPreco(precoAtual),
                          style: const TextStyle(
                            fontSize: 13, // Aumentado
                            fontWeight: FontWeight.bold, // Negrito
                            color: kCardPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 28, // Altura ajustada
                          child: TextButton.icon(
                            icon: Icon(
                              isProdutoNoCarrinho ? Icons.check_circle : Icons.add_shopping_cart,
                              size: 14, // Tamanho do ícone
                            ),
                            label: Text(
                              isProdutoNoCarrinho
                                  ? '$quantidadeNoCarrinho NO CARRINHO'
                                  : 'ADICIONAR',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), // Fonte menor
                            ),
                            onPressed: () {
                              // Adiciona 1 unidade com 0% de desconto por padrão
                              // A tela pai (ProdutoScreen) que implementa onAddToCart
                              // usará o Provider e o CarrinhoService.
                              onAddToCart(1, 0.0);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: isProdutoNoCarrinho
                                  ? kCardSuccessColor 
                                  : kCardPrimaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4), // Borda mais suave
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8), // Padding ajustado
                            ),
                          ),
                        ),
                      ],
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

// --- MODAL DE DETALHES E ADIÇÃO ---
class ProdutoDetalheModal extends StatefulWidget {
  final ProdutoModel produto;
  // Callback para notificar a tela pai (ProdutoScreen)
  final void Function(int quantidade, double descontoPercentual) onAddToCart;
  final int clienteTabela;

  const ProdutoDetalheModal({
    super.key,
    required this.produto,
    required this.onAddToCart, // Recebe o callback
    required this.clienteTabela,
  });
  // O parâmetro 'Carrinho carrinho' foi REMOVIDO daqui

  @override
  State<ProdutoDetalheModal> createState() => _ProdutoDetalheModalState();
}

class _ProdutoDetalheModalState extends State<ProdutoDetalheModal> {
  final TextEditingController _quantidadeController = TextEditingController(text: "1");
  final TextEditingController _descontoController = TextEditingController(text: "0");
  final FocusNode _quantidadeFocus = FocusNode();
  final FocusNode _descontoFocus = FocusNode();
  final ScrollController _scrollController = ScrollController(); // Para rolar quando o teclado aparecer

  int quantidade = 1;
  double descontoPercentual = 0.0; // Desconto é percentual

  @override
  void initState() {
    super.initState();
    // Lê o estado atual do carrinho para pré-popular os campos se o produto já estiver lá
    // É importante fazer isso no initState OU didChangeDependencies se usar context
    // Aqui, vamos assumir que se o modal é aberto, é para uma nova adição ou ajuste.
    // Para pré-popular, precisaríamos do Provider aqui:
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    //   if (carrinhoProvider.itens.containsKey(widget.produto)) {
    //     _quantidadeController.text = carrinhoProvider.itens[widget.produto].toString();
    //     _descontoController.text = (carrinhoProvider.descontos[widget.produto] ?? 0.0).toStringAsFixed(0);
    //     setState(() {
    //       quantidade = carrinhoProvider.itens[widget.produto]!;
    //       descontoPercentual = carrinhoProvider.descontos[widget.produto] ?? 0.0;
    //     });
    //   }
    // });

    _quantidadeController.addListener(_onQuantidadeChange);
    _descontoController.addListener(_onDescontoChange);
    _quantidadeFocus.addListener(_handleFocusChange);
    _descontoFocus.addListener(_handleFocusChange);
  }

  void _onQuantidadeChange() {
    final valor = int.tryParse(_quantidadeController.text);
    if (valor != null && valor > 0) {
      if (quantidade != valor) setState(() => quantidade = valor);
    } else if (_quantidadeController.text.isEmpty) {
        if (quantidade != 0) setState(() => quantidade = 0); // Permite apagar para digitar
    }
  }

  void _onDescontoChange() {
    final valor = double.tryParse(_descontoController.text);
    if (valor != null && valor >= 0) {
      double descontoFinal = valor;
      if (widget.produto.perdscmxm > 0 && valor > widget.produto.perdscmxm) {
        descontoFinal = widget.produto.perdscmxm;
        // Atualiza o controller se o valor foi limitado
        if (_descontoController.text != descontoFinal.toStringAsFixed(0)) { // Evita loop
            WidgetsBinding.instance.addPostFrameCallback((_){ // Adia a atualização do controller
                _descontoController.text = descontoFinal.toStringAsFixed(0);
                _descontoController.selection = TextSelection.fromPosition(TextPosition(offset: _descontoController.text.length));
            });
        }
      }
      if (descontoPercentual != descontoFinal) setState(() => descontoPercentual = descontoFinal);
    } else if (_descontoController.text.isEmpty) {
        if (descontoPercentual != 0) setState(() => descontoPercentual = 0);
    }
  }

  void _handleFocusChange() {
    if (_quantidadeFocus.hasFocus || _descontoFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () { // Leve atraso
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _quantidadeController.removeListener(_onQuantidadeChange);
    _descontoController.removeListener(_onDescontoChange);
    _quantidadeFocus.removeListener(_handleFocusChange);
    _descontoFocus.removeListener(_handleFocusChange);
    _quantidadeController.dispose();
    _descontoController.dispose();
    _quantidadeFocus.dispose();
    _descontoFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double get precoBase => widget.clienteTabela == 1
      ? widget.produto.vlrtab1
      : widget.produto.vlrtab2;
  double get precoFinalUnitario => precoBase * (1 - (descontoPercentual / 100));
  double get subtotalItem => precoFinalUnitario * quantidade;

  String formatarPreco(double preco) {
    return 'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  void _confirmarAdicao() {
    final qtdFinal = int.tryParse(_quantidadeController.text) ?? 0;
    final descFinal = double.tryParse(_descontoController.text) ?? 0.0;

    if (qtdFinal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade deve ser maior que zero.'), backgroundColor: Colors.red),
      );
      return;
    }
    // A lógica de validação de desconto máximo já está em _onDescontoChange
    
    FocusScope.of(context).unfocus(); // Fecha teclado
    widget.onAddToCart(qtdFinal, descFinal); // Chama o callback para a tela pai
    Navigator.pop(context); // Fecha o modal
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      // Ajusta altura para não ficar muito grande em telas maiores e permitir scroll
      height: MediaQuery.of(context).size.height * 0.7 + keyboardHeight, 
      margin: EdgeInsets.only(bottom: keyboardHeight > 0 ? 0 : MediaQuery.of(context).padding.bottom), // Evita que o teclado sobreponha
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)), // Raio maior
      ),
      child: Column(
        children: [
          // AppBar do Modal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kCardPrimaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Adicionar ao Carrinho', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Conteúdo Rolável
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Detalhes do Produto
                  Text(widget.produto.dcrprd, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Cód: ${widget.produto.codprd ?? "N/A"}  •  Marca: ${widget.produto.nommrc}", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text("Preço Tabela ${widget.clienteTabela}: ${formatarPreco(precoBase)}", style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                  if (descontoPercentual > 0)
                    Text("Preço com ${descontoPercentual.toStringAsFixed(1)}% Desc.: ${formatarPreco(precoFinalUnitario)}", style: TextStyle(fontSize: 14, color: kCardSuccessColor, fontWeight: FontWeight.w500)),
                  
                  const Divider(height: 32),

                  // Quantidade
                  Text("Quantidade:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantidadeController,
                    focusNode: _quantidadeFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        isDense: true,
                        hintText: "1",
                    ),
                    style: const TextStyle(fontSize: 16),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => FocusScope.of(context).requestFocus(_descontoFocus),
                  ),
                  const SizedBox(height: 16),

                  // Desconto
                  Text("Desconto (%):", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descontoController,
                    focusNode: _descontoFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      isDense: true,
                      suffixText: "%",
                      hintText: widget.produto.perdscmxm > 0 ? "Máx: ${widget.produto.perdscmxm.toStringAsFixed(0)}%" : "0",
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500])
                    ),
                    style: const TextStyle(fontSize: 16),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onSubmitted: (_) => _confirmarAdicao(),
                  ),
                  const SizedBox(height: 24),

                  // Resumo do Item
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal do Item:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text(formatarPreco(subtotalItem), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kCardPrimaryColor)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Espaço para scroll
                ],
              ),
            ),
          ),
          // Barra Inferior com Botão
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0,-2)),
              ]
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text("CONFIRMAR E ADICIONAR"),
                onPressed: _confirmarAdicao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCardPrimaryColor,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}