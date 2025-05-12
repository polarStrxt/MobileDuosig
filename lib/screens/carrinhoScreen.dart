import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/widgets/gerarpdfsimples.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// Modelo para condição de pagamento
class CondicaoPagamento {
  final int codcndpgt;
  final String dcrcndpgt;
  final double perdsccel;
  final String staati;

  CondicaoPagamento({
    required this.codcndpgt,
    required this.dcrcndpgt,
    required this.perdsccel,
    required this.staati,
  });

  factory CondicaoPagamento.fromJson(Map<String, dynamic> json) {
    return CondicaoPagamento(
      codcndpgt: json['codcndpgt'],
      dcrcndpgt: json['dcrcndpgt'],
      perdsccel: json['perdsccel'].toDouble(),
      staati: json['staati'],
    );
  }
}

class CarrinhoScreen extends StatefulWidget {
  final Cliente? cliente;
  final int codcli;

  const CarrinhoScreen({
    super.key,
    this.cliente,
    required this.codcli,
  });

  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  // Lista de condições de pagamento
  late List<CondicaoPagamento> _condicoesPagamento = [];

  // Service for cart operations
  final CarrinhoService _carrinhoService = CarrinhoService();
  final Logger _logger = Logger();

  // Estado de carregamento
  final bool _isLoading = false; // Made final since not changed after init
  String? _errorMessage;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _carregarCondicoesPagamento();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Método para carregar as condições de pagamento
  void _carregarCondicoesPagamento() {
    // Usando o JSON fornecido
    const String jsonData = '''
    [
      {
        "codcndpgt": 1,
        "dcrcndpgt": "A VISTA",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 2,
        "dcrcndpgt": "C/APRESENTACAO",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 3,
        "dcrcndpgt": "C/ ENTREGA",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 4,
        "dcrcndpgt": "A PRAZO",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 5,
        "dcrcndpgt": "30 DIAS",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 42,
        "dcrcndpgt": "TABLET",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 6,
        "dcrcndpgt": "5% DESCONTO  A VISTA DINHEIRO",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 7,
        "dcrcndpgt": "5% DESCONTO BOLETO 7 DIAS",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 11,
        "dcrcndpgt": "35/42",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 8,
        "dcrcndpgt": "21/28/35 DIAS",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 13,
        "dcrcndpgt": "21/28/35/42/49",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 20,
        "dcrcndpgt": "BONIFICACAO",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 9,
        "dcrcndpgt": "28/35/42 DD",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 14,
        "dcrcndpgt": "DD BCO",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 10,
        "dcrcndpgt": "35 DD",
        "perdsccel": 0,
        "staati": "S"
      },
      {
        "codcndpgt": 15,
        "dcrcndpgt": "3% DESCONTO BOLETO 7 DD",
        "perdsccel": 0,
        "staati": "S"
      }
    ]
    ''';

    try {
      final List<dynamic> decodedData = jsonDecode(jsonData);
      _condicoesPagamento =
          decodedData.map((item) => CondicaoPagamento.fromJson(item)).toList();
      _logger.i('Carregadas ${_condicoesPagamento.length} condições de pagamento');
    } catch (e) {
      _logger.e('Erro ao carregar condições de pagamento: $e');
      // Criar lista vazia para evitar erros
      _condicoesPagamento = [];
    }
  }

  // Método para atualizar o desconto de um produto
  Future<void> atualizarDesconto(ProdutoModel produto, double novoDesconto) async {
    if (_isDisposed) return;

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    
    // Validar o desconto (entre 0 e 100)
    novoDesconto = novoDesconto.clamp(0.0, 100.0);
    
    // Atualizar o desconto no carrinho compartilhado
    carrinhoProvider.descontos[produto] = novoDesconto;
    
    // Notificar ouvintes para atualizar a UI - Fixed notifyListeners issue
    setState(() {});
    
    // Persistir as alterações no banco de dados
    _persistirCarrinhoAposAlteracao(carrinhoProvider);
  }

  // Método para remover um produto do carrinho
  Future<void> _removerProduto(ProdutoModel produto) async {
    if (_isDisposed) return;

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    
    // Remover produto do carrinho compartilhado
    carrinhoProvider.itens.remove(produto);
    carrinhoProvider.descontos.remove(produto);
    
    // Notificar ouvintes para atualizar a UI - Fixed notifyListeners issue
    setState(() {});
    
    // Persistir as alterações no banco de dados
    _persistirCarrinhoAposAlteracao(carrinhoProvider);
  }

  // Método para atualizar a quantidade de um produto
  Future<void> _atualizarQuantidade(ProdutoModel produto, int quantidade) async {
    if (_isDisposed) return;

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);

    if (quantidade <= 0) {
      await _removerProduto(produto);
      return;
    }

    // Atualizar a quantidade no carrinho compartilhado
    carrinhoProvider.itens[produto] = quantidade;
    
    // Notificar ouvintes para atualizar a UI - Fixed notifyListeners issue
    setState(() {});
    
    // Persistir as alterações no banco de dados
    _persistirCarrinhoAposAlteracao(carrinhoProvider);
  }

  // Método auxiliar para persistir alterações do carrinho
  void _persistirCarrinhoAposAlteracao(Carrinho carrinhoProvider) {
    if (widget.cliente == null) return;
    
    _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
        .then((result) {
      if (!result.isSuccess && mounted) {
        _logger.e("Falha ao salvar carrinho no banco: ${result.errorMessage}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar alteração: ${result.errorMessage}"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Carrinho",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF5D5CDE),
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<Carrinho>(
        builder: (context, carrinhoProvider, child) {
          return _buildBody(carrinhoProvider);
        },
      ),
    );
  }

  Widget _buildBody(Carrinho carrinhoProvider) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (carrinhoProvider.isEmpty) {
      return _buildEmptyCart();
    }

    return _buildCartContent(carrinhoProvider);
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Carregando itens...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
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
            Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
            const SizedBox(height: 24),
            const Text(
              'Não foi possível carregar o carrinho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D5CDE),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 72,
              color: Color(0xFFBBBBBB),
            ),
            const SizedBox(height: 24),
            Text(
              "Seu carrinho está vazio",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Adicione produtos para continuar com a compra",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text("Voltar para produtos"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D5CDE),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true), // Pass true to reload products
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(Carrinho carrinhoProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cliente info card (if available)
        if (widget.cliente != null) _buildClienteInfo(),

        // Cart items list
        Expanded(
          child: _buildCartItemsList(carrinhoProvider),
        ),

        // Cart summary
        _buildCartSummary(carrinhoProvider),
      ],
    );
  }

  Widget _buildClienteInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF5D5CDE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF5D5CDE),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cliente!.nomcli,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Código: ${widget.cliente!.codcli} • Tabela: ${widget.cliente!.codtab}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(Carrinho carrinhoProvider) {
    final produtos = carrinhoProvider.itens.keys.toList();
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final produto = produtos[index];
        return _buildCartItem(produto, carrinhoProvider);
      },
    );
  }

  Widget _buildCartItem(ProdutoModel produto, Carrinho carrinhoProvider) {
    final int tabelaPreco = widget.cliente?.codtab ?? 1;
    final int quantidade = carrinhoProvider.itens[produto] ?? 0;
    final double preco = produto.getPrecoParaTabela(tabelaPreco);
    final double desconto = carrinhoProvider.descontos[produto] ?? 0.0;
    final double precoComDesconto = preco * (1 - desconto / 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Product info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon placeholder
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF5D5CDE),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.dcrprd,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cód: ${produto.codprd} • ${produto.nommrc}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Price with discount
                      Row(
                        children: [
                          if (desconto > 0) ...[
                            Text(
                              'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            'R\$ ${precoComDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: desconto > 0
                                  ? Colors.green[700]
                                  : Colors.black87,
                            ),
                          ),
                          if (desconto > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green[100]!),
                              ),
                              child: Text(
                                '-${desconto.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom section with quantity control and discount
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // Quantity row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quantidade',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Row(
                      children: [
                        _buildQuantityButton(
                          Icons.remove,
                          quantidade > 1
                              ? () => _atualizarQuantidade(produto, quantidade - 1)
                              : null,
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '$quantidade',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _buildQuantityButton(
                          Icons.add,
                          () => _atualizarQuantidade(produto, quantidade + 1),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Discount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Desconto',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 32,
                      child: TextFormField(
                        initialValue: desconto.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: desconto > 0
                              ? Colors.green[700]
                              : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          suffixText: '%',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        onChanged: (value) {
                          final novoDesconto = double.tryParse(value) ?? 0.0;
                          atualizarDesconto(produto, novoDesconto);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Subtotal and remove button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'R\$ ${(precoComDesconto * quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red[600],
                      ),
                      label: Text(
                        'Remover',
                        style: TextStyle(
                          color: Colors.red[600],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.red[200]!),
                        ),
                        backgroundColor: Colors.red[50],
                      ),
                      onPressed: () => _removerProduto(produto),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Ink(
        decoration: BoxDecoration(
          color: onPressed == null ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color:
                onPressed == null ? Colors.grey[300]! : const Color(0xFF5D5CDE),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color:
                onPressed == null ? Colors.grey[500] : const Color(0xFF5D5CDE),
          ),
        ),
      ),
    );
  }

  Widget _buildCartSummary(Carrinho carrinhoProvider) {
    final int tabelaPreco = widget.cliente?.codtab ?? 1;
    
    // Implementação do método ausente para calcular o subtotal sem desconto
    double calcularSubtotalSemDesconto() {
      double total = 0.0;
      carrinhoProvider.itens.forEach((produto, quantidade) {
        total += produto.getPrecoParaTabela(tabelaPreco) * quantidade;
      });
      return total;
    }
    
    final double totalSemDesconto = calcularSubtotalSemDesconto();
    final double totalComDesconto = carrinhoProvider.calcularValorTotal(tabelaPreco);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  'R\$ ${totalSemDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (totalSemDesconto > totalComDesconto) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Descontos',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    '-R\$ ${(totalSemDesconto - totalComDesconto).toStringAsFixed(2).replaceAll('.', ',')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'R\$ ${totalComDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D5CDE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transfer button
            ElevatedButton(
              onPressed: () {
                if (widget.cliente == null) {
                  _mostrarErroClienteNaoAssociado();
                } else {
                  _mostrarDialogoTransferirCarrinho(carrinhoProvider);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5CDE),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Finalizar Carrinho',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarErroClienteNaoAssociado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atenção"),
        content: const Text(
          "Não há cliente associado a este pedido. A transferência não poderá ser realizada.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoTransferirCarrinho(Carrinho carrinhoProvider) async {
    if (!mounted) return;

    String observacao = '';
    CondicaoPagamento? formaPagamentoSelecionada =
        _condicoesPagamento.isNotEmpty ? _condicoesPagamento.first : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF5D5CDE),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.send_outlined,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Text(
                "Transferir Carrinho",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente info
                if (widget.cliente != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          color: Color(0xFF5D5CDE),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.cliente!.nomcli,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "Cód: ${widget.cliente!.codcli}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Resumo do pedido
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resumo do pedido:",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Itens:"),
                          Text("${carrinhoProvider.itens.length}"),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total:"),
                          Text(
                            "R\$ ${carrinhoProvider.calcularValorTotal(widget.cliente?.codtab ?? 1).toStringAsFixed(2).replaceAll('.', ',')}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5D5CDE),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Observação
                const Text(
                  "Observação (opcional):",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[400]!),
                    ),
                    hintText: "Digite qualquer observação sobre o pedido",
                    contentPadding: const EdgeInsets.all(12),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => observacao = value,
                ),
                const SizedBox(height: 16),

                // Forma de Pagamento
                const Text(
                  "Forma de Pagamento:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _condicoesPagamento.isEmpty
                    ? const Text("Não há condições de pagamento disponíveis")
                    : StatefulBuilder(builder: (context, setState) {
                        return DropdownButtonFormField<CondicaoPagamento>(
                          isExpanded: true,
                          value: formaPagamentoSelecionada,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon:
                                const Icon(Icons.payment_outlined, size: 20),
                          ),
                          items: _condicoesPagamento.map((condicao) {
                            return DropdownMenuItem<CondicaoPagamento>(
                              value: condicao,
                              child: Text(
                                condicao.dcrcndpgt,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() {
                                formaPagamentoSelecionada = newValue;
                              });
                            }
                          },
                        );
                      }),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D5CDE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Capturar os valores antes de fechar o diálogo
                    final String obs = observacao;
                    final String codPagto =
                        formaPagamentoSelecionada?.codcndpgt.toString() ?? '1';
                    final String descPagto = 
                        formaPagamentoSelecionada?.dcrcndpgt ?? 'A VISTA';

                    Navigator.pop(context);
                    _transferirCarrinho(
                      carrinhoProvider: carrinhoProvider,
                      observacao: obs,
                      formaPagamento: codPagto,
                      formaPagamentoDesc: descPagto,
                    );
                  },
                  child: const Text("Transferir"),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      ),
    );
  }

  // Método para transferir o carrinho (enviar POST)
  Future<void> _transferirCarrinho({
    required Carrinho carrinhoProvider,
    String observacao = '',
    String formaPagamento = '1',
    String formaPagamentoDesc = 'A VISTA',
  }) async {
    if (!mounted) return;

    final int tabelaPreco = widget.cliente?.codtab ?? 1;
    final BuildContext contextAtual = context;

    // Mostrar diálogo de progresso
    BuildContext? dialogContext;
    showDialog(
      context: contextAtual,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Transferindo dados do carrinho..."),
            ],
          ),
        );
      },
    );

    try {
      // Preparar a lista de produtos no formato requerido
      List<Map<String, dynamic>> produtosJson = [];

      carrinhoProvider.itens.forEach((produto, quantidade) {
        double preco = produto.getPrecoParaTabela(tabelaPreco);
        double desconto = carrinhoProvider.descontos[produto] ?? 0.0;

        produtosJson.add({
          "cod_produto": produto.codprd.toString(),
          "quantidade": quantidade,
          "vlr_unitario": preco,
          "per_desconto": desconto,
        });
      });

      // Gerar número de pedido no formato YYYYMMDD-CCC
      final DateTime agora = DateTime.now();
      final String dataFormatada = "${agora.year}"
          "${agora.month.toString().padLeft(2, '0')}"
          "${agora.day.toString().padLeft(2, '0')}";
      final String codigoCliente =
          (widget.cliente?.codcli ?? '000').toString().padLeft(3, '0');
      final String numPedido = "$dataFormatada-$codigoCliente";
      final String dataHoraCompleta = "${dataFormatada}_"
          "${agora.hour.toString().padLeft(2, '0')}"
          "${agora.minute.toString().padLeft(2, '0')}"
          "${agora.second.toString().padLeft(2, '0')}";
      final String idPedido = dataHoraCompleta.toUpperCase();
      final String dataPedido = DateFormat('dd/MM/yyyy').format(DateTime.now());

      // Objeto JSON completo para envio
      final Map<String, dynamic> dadosPedido = {
        "num_pedido": numPedido,
        "id": idPedido,
        "data_pedido": dataPedido,
        "cod_cliente": widget.cliente?.codcli.toString() ?? "",
        "vlr_pedido": carrinhoProvider.calcularValorTotal(tabelaPreco),
        "cod_vendedor": "001", // Código do vendedor fixo
        "cod_condicao_pagto": formaPagamento,
        "dcr_condicao_pagto": formaPagamentoDesc,
        "observacao": observacao,
        "produtos": produtosJson,
      };

      // Logar o JSON que será enviado
      _logger.i('Enviando JSON: ${jsonEncode(dadosPedido)}');

      // Enviar requisição POST
      final Uri uri =
          Uri.parse('http://duotecsuprilev.ddns.com.br:8082/v1/pedido');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(dadosPedido),
      );

      // Fechar diálogo de progresso
      if (dialogContext != null &&
          Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      // Verificar resposta
      _logger.i('Resposta (${response.statusCode}): ${response.body}');

      if (!mounted) return; // Added mounted check after async operation

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Transferência bem-sucedida - Marcar itens como finalizados ATRAVÉS DO SERVICE
        final resultado = await _carrinhoService.finalizarCarrinho(widget.cliente!);
        
        if (!mounted) return; // Added mounted check after async operation
        
        if (!resultado.isSuccess) {
          _logger.e('Erro ao finalizar carrinho: ${resultado.errorMessage}');
          _mostrarErroFinalizacaoCarrinho(resultado.errorMessage ?? 'Erro desconhecido');
          return;
        }

        // Limpar o carrinho na memória (Provider)
        Provider.of<Carrinho>(contextAtual, listen: false).limpar();

        // Mostrar mensagem de sucesso
        await _mostrarDialogoSucesso(
          contextAtual, 
          numPedido, 
          carrinhoProvider, 
          observacao,
          formaPagamentoDesc,
        );
      } else {
        // Erro na transferência
        await _mostrarDialogoErro(contextAtual, response, dadosPedido);
      }
    } catch (e) {
      // Fechar diálogo de progresso
      if (dialogContext != null &&
          Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      // Verificar se o widget ainda está montado
      if (!mounted) return;

      // Mostrar diálogo de erro de conexão
      await _mostrarDialogoErroConexao(
          contextAtual, e, observacao, formaPagamento, carrinhoProvider);
    }
  }

  void _mostrarErroFinalizacaoCarrinho(String mensagem) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro ao finalizar carrinho no banco: $mensagem'),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _mostrarDialogoSucesso(
    BuildContext contextAtual,
    String numPedido,
    Carrinho carrinhoProvider,
    String observacao,
    String formaPagamentoDesc,
  ) async {
    if (!mounted) return; // Added mounted check
    
    await showDialog(
      context: contextAtual,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Controlador para a animação
        return StatefulBuilder(
          builder: (context, setState) {
            // Inicia a animação quando o diálogo é exibido
            return AlertDialog(
              contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              title: Row(
                children: [
                  Text("Sucesso!", style: TextStyle(color: Colors.green[700])),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animação de sucesso
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Container(
                        height: 120,
                        width: 120,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 12 * value,
                              spreadRadius: 4 * value,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Transform.scale(
                            scale: value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.green[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Texto com fade-in
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeInOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        const Text(
                          "Carrinho transferido com sucesso!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.numbers, size: 18, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text(
                                "Pedido: $numPedido",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Sinalizar que não há necessidade de recarregar carrinho
                    Navigator.of(contextAtual).pop(false);
                  },
                  child: const Text("OK"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text("Gerar PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D5CDE),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _gerarPDFComDadosSalvos(
                      carrinhoProvider: carrinhoProvider,
                      observacao: observacao,
                      contextAtual: contextAtual,
                      numPedido: numPedido,
                      formaPagamento: formaPagamentoDesc,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Método para gerar PDF com dados do Provider
  Future<void> _gerarPDFComDadosSalvos({
    required Carrinho carrinhoProvider,
    required BuildContext contextAtual,
    String observacao = '',
    String nomeVendedor = '',
    String nomeClienteResponsavel = '',
    String emailCliente = '',
    String formaPagamento = '',
    String numPedido = '',
  }) async {
    if (!mounted) return; // Added mounted check
    
    // Diálogo de contexto para progresso
    BuildContext? dialogContext;

    // Mostrar progresso
    showDialog(
      context: contextAtual,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Gerando PDF..."),
            ],
          ),
        );
      },
    );

    try {
      if (carrinhoProvider.isEmpty) {
        // Fechar diálogo de progresso
        if (dialogContext != null &&
            Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        }

        if (!mounted) return; // Added mounted check
        
        ScaffoldMessenger.of(contextAtual).showSnackBar(
          SnackBar(
            content: const Text("Não há dados para gerar o PDF"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Sinalizar que não há necessidade de recarregar carrinho
        Navigator.of(contextAtual).pop(false);
        return;
      }

      // Converter os dados do provider para o formato esperado pelo gerador de PDF
      final Map<ProdutoModel, int> produtosSalvos = Map.from(carrinhoProvider.itens);
      final Map<ProdutoModel, double> descontosSalvos = Map.from(carrinhoProvider.descontos);

      // Gerar PDF com os mapas do provider
      final filePath = await PdfGeneratorSimples.gerarPdfSimples(
        produtosSalvos,
        descontosSalvos,
        widget.cliente,
        observacao,
        nomeVendedor,
        nomeClienteResponsavel,
        emailCliente,
        formaPagamento,
        numPedido,
      );

      // Fechar diálogo de progresso
      if (dialogContext != null &&
          Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (!mounted) return; // Added mounted check

      if (filePath != null) {
        // Mostrar diálogo de sucesso com opções
        await showDialog(
          context: contextAtual,
          builder: (BuildContext context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.green[600], size: 24),
                const SizedBox(width: 8),
                const Text("PDF Gerado", style: TextStyle(fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("O arquivo foi salvo com sucesso!"),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    filePath,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Sinalizar que não há necessidade de recarregar carrinho
                  Navigator.of(contextAtual).pop(false);
                },
                child: const Text("OK"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 18),
                label: const Text("Compartilhar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D5CDE),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await PdfGeneratorSimples.compartilharArquivo(filePath);
                  
                  if (!mounted) return; // Added mounted check
                  
                  // Sinalizar que não há necessidade de recarregar carrinho
                  Navigator.of(contextAtual).pop(false);
                },
              ),
            ],
          ),
        );
      } else {
        // Mostrar erro
        if (!mounted) return; // Added mounted check
        
        ScaffoldMessenger.of(contextAtual).showSnackBar(
          SnackBar(
            content: const Text("Erro ao gerar PDF"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Sinalizar que não há necessidade de recarregar carrinho
        Navigator.of(contextAtual).pop(false);
      }
    } catch (e) {
      // Fechar diálogo de progresso se estiver aberto
      if (dialogContext != null &&
          Navigator.of(dialogContext!, rootNavigator: true).canPop()) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (!mounted) return; // Added mounted check

      // Mostrar erro
      ScaffoldMessenger.of(contextAtual).showSnackBar(
        SnackBar(
          content: Text("Erro ao gerar PDF: $e"),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Sinalizar que não há necessidade de recarregar carrinho
      Navigator.of(contextAtual).pop(false);
    }
  }

  Future<void> _mostrarDialogoErro(
    BuildContext contextAtual,
    http.Response response,
    Map<String, dynamic> dadosPedido,
  ) async {
    if (!mounted) return; // Added mounted check
    
    // Tentar analisar a resposta de erro como JSON
    Map<String, dynamic>? responseJson;
    String errorMessage = "Erro desconhecido";

    try {
      if (response.body.isNotEmpty) {
        responseJson = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = responseJson['message'] ??
            responseJson['error'] ??
            "Erro ao transferir carrinho";
      }
    } catch (e) {
      errorMessage = response.body.isNotEmpty
          ? response.body
          : "Erro ao transferir carrinho (Código: ${response.statusCode})";
    }

    // Exibir detalhes do erro em diálogo simplificado
    await showDialog(
      context: contextAtual,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            Text("Erro", style: TextStyle(color: Colors.red[700])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Não foi possível transferir o carrinho",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detalhes do erro:",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Código: ${response.statusCode}"),
                  const SizedBox(height: 4),
                  Text("Mensagem: $errorMessage"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fechar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D5CDE),
              foregroundColor: Colors.white,
            ),
            child: const Text("Tentar Novamente"),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoErroConexao(
    BuildContext contextAtual,
    dynamic error,
    String observacao,
    String formaPagamento,
    Carrinho carrinhoProvider,
  ) async {
    if (!mounted) return; // Added mounted check
    
    await showDialog(
      context: contextAtual,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red[600], size: 24),
            const SizedBox(width: 8),
            Text("Erro de Conexão", style: TextStyle(color: Colors.red[700])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Não foi possível conectar ao servidor",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Verifique sua conexão com a internet e tente novamente.",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fechar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (mounted) {
                _transferirCarrinho(
                  carrinhoProvider: carrinhoProvider,
                  observacao: observacao,
                  formaPagamento: formaPagamento,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D5CDE),
              foregroundColor: Colors.white,
            ),
            child: const Text("Tentar Novamente"),
          ),
        ],
      ),
    );
  }
}