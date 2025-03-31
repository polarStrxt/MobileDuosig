import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/carrinhoWidget.dart';
import 'package:flutter_docig_venda/widgets/pdfGenerator.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/widgets/gerarpdfsimples.dart';

class CarrinhoScreen extends StatefulWidget {
  final CarrinhoWidget carrinho;

  const CarrinhoScreen({Key? key, required this.carrinho}) : super(key: key);

  @override
  _CarrinhoScreenState createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  // Mapa local para gerenciar os descontos (inicializado a partir do carrinho)
  late Map<Produto, double> _descontos;

  @override
  void initState() {
    super.initState();

    // Inicializar o mapa de descontos a partir do CarrinhoWidget
    _descontos = Map<Produto, double>.from(widget.carrinho.descontos ?? {});

    // Garantir que todos os produtos tenham um valor de desconto (mesmo que seja 0)
    for (var produto in widget.carrinho.itens.keys) {
      if (!_descontos.containsKey(produto)) {
        _descontos[produto] = 0.0;
      }
    }

    // Define o contexto para o PdfGenerator usar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PdfGenerator.definirContexto(context);
    });
  }

  // Método para atualizar o desconto de um produto
  void atualizarDesconto(Produto produto, double novoDesconto) {
    setState(() {
      // Validar o desconto (entre 0 e 100)
      novoDesconto = novoDesconto.clamp(0.0, 100.0);

      // Atualizar no mapa local
      _descontos[produto] = novoDesconto;

      // Sincronizar com o widget.carrinho.descontos para manter consistência
      // Isso pode exigir alterações adicionais dependendo de como CarrinhoWidget é implementado
      widget.carrinho.descontos[produto] = novoDesconto;
    });
  }

  // Calcula o total do carrinho sem descontos
  double get _totalSemDesconto {
    final int tabelaPreco = widget.carrinho.cliente?.codtab ?? 1;

    return widget.carrinho.itens.entries.fold(
      0,
      (total, item) {
        double preco = tabelaPreco == 1 ? item.key.vlrtab1 : item.key.vlrtab2;
        return total + (preco * item.value);
      },
    );
  }

  // Calcula o total com os descontos aplicados
  double get _totalComDesconto {
    final int tabelaPreco = widget.carrinho.cliente?.codtab ?? 1;

    return widget.carrinho.itens.entries.fold(
      0,
      (total, item) {
        double preco = tabelaPreco == 1 ? item.key.vlrtab1 : item.key.vlrtab2;
        double desconto = _descontos[item.key] ?? 0.0;
        double precoComDesconto = preco * (1 - desconto / 100);
        return total + (precoComDesconto * item.value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Carrinho de Compras"),
        backgroundColor: Color(0xFF5D5CDE),
        elevation: 0,
      ),
      body: widget.carrinho.isEmpty ? _buildEmptyCart() : _buildCartContent(),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "Seu carrinho está vazio",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Adicione produtos para continuar",
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_back),
            label: Text("Voltar para produtos"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5D5CDE),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card de informações do cliente (se houver)
          if (widget.carrinho.cliente != null)
            Card(
              elevation: 2,
              margin: EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                    color: Color(0xFF5D5CDE).withOpacity(0.3), width: 1),
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF5D5CDE).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Cliente do Pedido",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                widget.carrinho.cliente!.nomcli,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Código: ${widget.carrinho.cliente!.codcli}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "Tabela: ${widget.carrinho.cliente!.codtab}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lista de itens do carrinho
          Expanded(
            child: _buildCartItemsList(),
          ),

          // Resumo do carrinho
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Resumo do pedido",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D5CDE),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Subtotal:",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        "R\$ ${_totalSemDesconto.toStringAsFixed(2).replaceAll('.', ',')}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_totalSemDesconto > _totalComDesconto)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Descontos:",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          "-R\$ ${(_totalSemDesconto - _totalComDesconto).toStringAsFixed(2).replaceAll('.', ',')}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "R\$ ${_totalComDesconto.toStringAsFixed(2).replaceAll('.', ',')}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5D5CDE),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Botão para finalizar compra
          ElevatedButton.icon(
            icon: Icon(Icons.summarize),
            label: Text(
              "Finalizar Pedido",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5D5CDE),
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              // Verificar se tem cliente associado
              if (widget.carrinho.cliente == null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("Atenção"),
                    content: Text(
                        "Não há cliente associado a este pedido. O PDF será gerado sem dados do cliente."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Cancelar"),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _gerarPDF();
                        },
                        child: Text("Continuar"),
                      ),
                    ],
                  ),
                );
              } else {
                _gerarPDF();
              }
            },
          ),
        ],
      ),
    );
  }

  // Método para extrair a lógica de geração do PDF
  Future<void> _gerarPDF() async {
    try {
      // Mostrar progresso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Gerando PDF..."),
            ],
          ),
        ),
      );

      // Usar a versão simplificada - passando os descontos do estado local
      final filePath = await PdfGeneratorSimples.gerarPdfSimples(
        widget.carrinho.itens,
        _descontos, // Use o mapa de descontos local
        widget.carrinho.cliente,
      );

      // Fechar diálogo de progresso
      Navigator.of(context, rootNavigator: true).pop();

      if (filePath != null) {
        // Mostrar diálogo de sucesso com opções
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("PDF Gerado com Sucesso!"),
            content: Text("O arquivo foi salvo em:\n$filePath"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Volta para tela anterior
                },
                child: Text("OK"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await PdfGeneratorSimples.compartilharArquivo(filePath);
                },
                child: Text("Compartilhar"),
              ),
            ],
          ),
        );
      } else {
        // Mostrar erro
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Erro ao gerar PDF"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Fechar diálogo de progresso se estiver aberto
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Mostrar erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erro ao gerar PDF: $e"),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCartItemsList() {
    final int tabelaPreco = widget.carrinho.cliente?.codtab ?? 1;

    return ListView.separated(
      itemCount: widget.carrinho.itens.length,
      separatorBuilder: (context, index) => Divider(height: 1),
      itemBuilder: (context, index) {
        // Obtém o produto e quantidade pelo índice
        final produto = widget.carrinho.itens.keys.elementAt(index);
        final quantidade = widget.carrinho.itens[produto] ?? 0;

        // Obtém o preço baseado na tabela do cliente
        final double preco =
            tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;

        // Obtém o desconto do mapa local
        final double desconto = _descontos[produto] ?? 0.0;

        // Calcula o preço com desconto
        final double precoComDesconto = preco * (1 - desconto / 100);

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagem ou placeholder
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.inventory_2,
                          color: Color(0xFF5D5CDE),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Informações do produto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            produto.dcrprd,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Cód: ${produto.codprd} | ${produto.nommrc}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Preço e quantidade
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valor unitário:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        desconto > 0
                            ? Row(
                                children: [
                                  Text(
                                    'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'R\$ ${precoComDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ],
                    ),
                    // Controle de quantidade
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline),
                          color: Color(0xFF5D5CDE),
                          onPressed: quantidade > 1
                              ? () {
                                  setState(() {
                                    widget.carrinho.itens[produto] =
                                        quantidade - 1;
                                  });
                                }
                              : null,
                        ),
                        Text(
                          '$quantidade',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          color: Color(0xFF5D5CDE),
                          onPressed: () {
                            setState(() {
                              widget.carrinho.itens[produto] = quantidade + 1;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                // Campo para editar o desconto
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Desconto:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 70,
                        height: 36,
                        child: TextFormField(
                          initialValue: desconto.toStringAsFixed(0),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: desconto > 0
                                ? Colors.green[700]
                                : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            suffixText: '%',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                          onChanged: (value) {
                            final novoDesconto = double.tryParse(value) ?? 0.0;
                            atualizarDesconto(produto, novoDesconto);
                          },
                        ),
                      ),
                      Spacer(),
                      if (desconto > 0)
                        Text(
                          'Economia: R\$ ${((preco - precoComDesconto) * quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(),
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:'),
                    Text(
                      'R\$ ${(precoComDesconto * quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF5D5CDE),
                      ),
                    ),
                  ],
                ),
                // Botão para remover
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18),
                    label: Text('Remover'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.carrinho.itens.remove(produto);
                        _descontos.remove(produto);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
