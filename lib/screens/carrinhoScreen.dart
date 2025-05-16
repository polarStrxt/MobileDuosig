import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/condicao_pagamento.dart';
import 'package:flutter_docig_venda/widgets/gerarpdfsimples.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/models/carrinho_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

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

  // Estado de carregamento e processamento
  bool _isProcessingAction = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carregarCondicoesPagamento();
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
    if (!mounted) return;
    
    setState(() {
      _isProcessingAction = true;
    });

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Corrigido: Usar o método do Provider em vez de modificar o mapa diretamente
      carrinhoProvider.atualizarDesconto(produto, novoDesconto);
      
      // Persistir as alterações no banco de dados através do service
      await _persistirCarrinhoAposAlteracao(carrinhoProvider);
    } catch (e) {
      _logger.e('Erro ao atualizar desconto: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar desconto: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  // Método para remover um produto do carrinho
  Future<void> _removerProduto(ProdutoModel produto) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessingAction = true;
    });

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Corrigido: Usar o método do Provider em vez de modificar o mapa diretamente
      carrinhoProvider.removerItem(produto);
      
      // Persistir as alterações no banco de dados através do service
      await _persistirCarrinhoAposAlteracao(carrinhoProvider);
    } catch (e) {
      _logger.e('Erro ao remover produto: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao remover produto: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  // Método para atualizar a quantidade de um produto
  Future<void> _atualizarQuantidade(ProdutoModel produto, int quantidade) async {
    if (!mounted) return;
    
    setState(() {
      _isProcessingAction = true;
    });

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Corrigido: Usar o método do Provider em vez de modificar o mapa diretamente
      carrinhoProvider.atualizarQuantidade(produto, quantidade);
      
      // Persistir as alterações no banco de dados através do service
      await _persistirCarrinhoAposAlteracao(carrinhoProvider);
    } catch (e) {
      _logger.e('Erro ao atualizar quantidade: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar quantidade: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  // Método auxiliar para persistir alterações do carrinho
  Future<void> _persistirCarrinhoAposAlteracao(Carrinho carrinhoProvider) async {
    if (widget.cliente == null || widget.cliente!.codcli == null) {
      _logger.w("Persistir: Cliente ou codcli nulo.");
      return;
    }
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final result = await _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!);
      
      if (!mounted) return;
      
      if (!result.isSuccess) {
        _logger.e("Falha ao salvar carrinho no banco: ${result.errorMessage}");
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar alteração: ${result.errorMessage}"),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          )
        );
      } else {
        _logger.i("Carrinho atualizado no banco.");
      }
    } catch (e, s) {
      _logger.e("Erro crítico ao persistir carrinho", error: e, stackTrace: s);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("Erro crítico ao salvar."), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
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
    if (_isProcessingAction) {
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
            color: Colors.black.withAlpha(13), // Corrigido: withOpacity -> withAlpha
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
              color: const Color(0xFF5D5CDE).withAlpha(25), // Corrigido: withOpacity -> withAlpha
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
            color: Colors.black.withAlpha(13), // Corrigido: withOpacity -> withAlpha
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
    
    // Calcular o subtotal sem desconto
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
            color: Colors.black.withAlpha(20), // Corrigido: withOpacity -> withAlpha
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
              onPressed: _isProcessingAction 
                ? null 
                : () {
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
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isProcessingAction
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Processando...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : const Text(
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

  // MÉTODO REFATORADO: _transferirCarrinho para implementar o novo fluxo
  Future<void> _transferirCarrinho({
    required Carrinho carrinhoProvider,
    String observacao = '',
    String formaPagamento = '1',
    String formaPagamentoDesc = 'A VISTA',
  }) async {
    if (!mounted || widget.cliente == null || widget.cliente!.codcli == null) {
      _logger.e("Transferência abortada: widget desmontado ou cliente inválido.");
      if (mounted) {
        _mostrarMensagemErroGeral("Cliente inválido. Não é possível transferir.");
      }
      return;
    }

    setState(() { _isProcessingAction = true; });

    BuildContext? dialogContext;
    // Usar um ValueNotifier para mudar o texto do diálogo de progresso
    ValueNotifier<String> progressoNotifier = ValueNotifier("Processando seu pedido...");

    showDialog(
      context: context, // Usar context da tela para o diálogo inicial
      barrierDismissible: false,
      builder: (buildDialogContext) {
        dialogContext = buildDialogContext;
        return ValueListenableBuilder<String>(
          valueListenable: progressoNotifier,
          builder: (context, message, child) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(message),
                ],
              ),
            );
          },
        );
      },
    );

    String? filePathDoPdfGerado; // Para armazenar o caminho do PDF
    String numPedidoFinalGerado = ""; // Para armazenar o número do pedido

    try {
      // 1. Buscar CarrinhoModel do banco e Salvar Observação Localmente
      final carrinhosDao = CarrinhosDao(); // Idealmente injetado
      CarrinhoModel? carrinhoDoBanco = await carrinhosDao.getCarrinhoAberto(widget.cliente!.codcli!);

      if (carrinhoDoBanco != null && carrinhoDoBanco.id != null) {
        if (carrinhoDoBanco.observacoes != observacao) {
          await carrinhosDao.atualizarObservacoesCarrinho(carrinhoDoBanco.id!, observacao);
          _logger.i("Observação salva no carrinho local ID BD: ${carrinhoDoBanco.id}");
          // Removidas referências a propriedades e métodos que não existem em Carrinho
        }
      } else {
        _logger.w("Nenhum carrinho local aberto para cliente ${widget.cliente!.codcli}. Observação não será salva localmente.");
        // Se não há carrinho, a geração do num_pedido usará fallback, e o PDF também refletirá isso.
      }

      // 2. Gerar Identificadores do Pedido
      final DateTime agoraParaPedido = DateTime.now();
      if (carrinhoDoBanco != null && carrinhoDoBanco.id != null) {
        String dataCriacaoStr = DateFormat('yyyyMMdd').format(carrinhoDoBanco.dataCriacao);
        numPedidoFinalGerado = "$dataCriacaoStr-${widget.cliente!.codcli}-${carrinhoDoBanco.id}";
      } else {
        String dataFormatadaFallback = DateFormat('yyyyMMdd').format(agoraParaPedido);
        numPedidoFinalGerado = "$dataFormatadaFallback-${widget.cliente!.codcli.toString().padLeft(3, '0')}-NO_CART_ID";
      }
      _logger.i("Número do Pedido Gerado: $numPedidoFinalGerado");

      // 3. TENTAR GERAR O PDF
      progressoNotifier.value = "Gerando PDF do pedido...";
      _logger.d("Tentando gerar PDF com numPedido: $numPedidoFinalGerado e observacao: $observacao");

      // Para _gerarPDFComDadosSalvos, vamos passar uma cópia do estado atual do provider
      // para garantir que o PDF reflita o que o usuário está vendo.
      final Carrinho carrinhoAtualParaPdf = Carrinho(
          itens: Map.from(carrinhoProvider.itens),
          descontos: Map.from(carrinhoProvider.descontos),
      );

      // O PdfGeneratorSimples precisa do Cliente, e outros dados que já temos.
      filePathDoPdfGerado = await _gerarPDFComDadosSalvos(
          carrinhoParaGeracao: carrinhoAtualParaPdf, // Passa o estado atual
          contextAtual: context, // Passa o context da tela
          observacao: observacao,
          cliente: widget.cliente,
          formaPagamento: formaPagamentoDesc,
          numPedido: numPedidoFinalGerado
      );

      if (!mounted) return;

      if (filePathDoPdfGerado == null) {
        _logger.e("Falha ao gerar PDF. Pedido NÃO será enviado.");
        if (dialogContext != null) Navigator.of(dialogContext!, rootNavigator: true).pop();
        setState(() { _isProcessingAction = false; });
        _mostrarMensagemErroGeral("Falha ao gerar o PDF. O pedido não foi enviado. Por favor, tente novamente.");
        return;
      }
      _logger.i("PDF gerado com sucesso em: $filePathDoPdfGerado");

      // 4. Se PDF OK, TENTAR ENVIAR PARA API
      progressoNotifier.value = "Enviando pedido para a central...";
      final int tabelaPreco = widget.cliente!.codtab;
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

      final Map<String, dynamic> dadosPedido = {
        "num_pedido": numPedidoFinalGerado,
        "id": numPedidoFinalGerado, // Usando o mesmo para o ID do JSON
        "data_pedido": DateFormat('dd/MM/yyyy').format(agoraParaPedido),
        "cod_cliente": widget.cliente!.codcli.toString(),
        "vlr_pedido": carrinhoProvider.calcularValorTotal(tabelaPreco),
        "cod_vendedor": "001",
        "cod_condicao_pagto": formaPagamento,
        "dcr_condicao_pagto": formaPagamentoDesc,
        "observacoes": observacao,
        "produtos": produtosJson,
      };

      _logger.i('Enviando JSON para API: ${jsonEncode(dadosPedido)}');
      final Uri uri = Uri.parse('http://duotecsuprilev.ddns.com.br:8082/v1/pedido');
      final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dadosPedido));

      if (dialogContext != null && mounted) Navigator.of(dialogContext!, rootNavigator: true).pop();
      if (!mounted) return;

      _logger.i('Resposta da API (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) { // SUCESSO NO POST
        _logger.i("POST para API bem-sucedido. Finalizando carrinho local...");
        final resultadoFinalizacaoLocal = await _carrinhoService.finalizarCarrinho(widget.cliente!);
        if (!mounted) return;

        if (resultadoFinalizacaoLocal.isSuccess) {
          Provider.of<Carrinho>(context, listen: false).limpar();
          setState(() { _isProcessingAction = false; });
          await _mostrarDialogoPedidoEnviadoComPdf(context, numPedidoFinalGerado, filePathDoPdfGerado);
        } else {
          setState(() { _isProcessingAction = false; });
          _mostrarMensagemErroGeral(
              "Pedido enviado (Nº: $numPedidoFinalGerado) e PDF gerado, mas erro ao fechar carrinho local. Contate suporte. Carrinho na tela será limpo.");
          Provider.of<Carrinho>(context, listen: false).limpar();
        }
      } else { // FALHA NO POST
        setState(() { _isProcessingAction = false; });
        await _mostrarDialogoErroEnvioComPdfGerado(context, response, dadosPedido, filePathDoPdfGerado);
      }

    } catch (e, s) {
      _logger.e("Erro crítico em _transferirCarrinho", error: e, stackTrace: s);
      if (dialogContext != null && mounted) Navigator.of(dialogContext!, rootNavigator: true).pop();
      if (!mounted) return;
      setState(() { _isProcessingAction = false; });
      await _mostrarDialogoErroConexao(context, e, observacao, formaPagamento, carrinhoProvider);
    } finally {
       progressoNotifier.dispose(); // Limpa o notifier
    }
  }

  // MÉTODO REFATORADO: _gerarPDFComDadosSalvos para retornar o caminho do arquivo
  Future<String?> _gerarPDFComDadosSalvos({ // Retorna o caminho do arquivo ou null
    required Carrinho carrinhoParaGeracao, // Recebe uma instância de Carrinho com os dados
    required BuildContext contextAtual,    // Contexto da tela
    required String observacao,            // Agora é parâmetro obrigatório 
    Cliente? cliente,
    String formaPagamento = '',
    String numPedido = '',
    String nomeVendedor = 'Vendedor Padrão',
    String? nomeClienteResponsavel,
    String? emailCliente,
  }) async {
    if (!mounted) return null;

    // Usar um ValueNotifier para o diálogo de progresso interno desta função
    ValueNotifier<String> pdfProgressoNotifier = ValueNotifier("Gerando PDF...");
    BuildContext? pdfDialogContext;

    showDialog(
      context: contextAtual, // Usa o context da tela
      barrierDismissible: false,
      builder: (buildDialogCtx) {
        pdfDialogContext = buildDialogCtx;
        return ValueListenableBuilder<String>(
            valueListenable: pdfProgressoNotifier,
            builder: (ctx, message, _) => AlertDialog(
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(), const SizedBox(height: 20), Text(message)
                ]),
            ),
        );
      },
    );

    try {
      if (carrinhoParaGeracao.isEmpty) {
        _logger.w("PDF: Carrinho para geração está vazio.");
        if (pdfDialogContext != null && mounted) Navigator.of(pdfDialogContext!, rootNavigator: true).pop();
        _mostrarMensagemErroGeral("Não há itens no carrinho para gerar o PDF.");
        return null;
      }

      // Usa os dados de carrinhoParaGeracao
      final filePath = await PdfGeneratorSimples.gerarPdfSimples(
        Map.from(carrinhoParaGeracao.itens),       // Passa cópias para segurança
        Map.from(carrinhoParaGeracao.descontos),
        cliente ?? widget.cliente,
        observacao,
        nomeVendedor,
        nomeClienteResponsavel ?? cliente?.nomcli ?? widget.cliente?.nomcli ?? "Consumidor",
        emailCliente ?? cliente?.emailcli ?? widget.cliente?.emailcli ?? "",
        formaPagamento,
        numPedido,
      );

      if (pdfDialogContext != null && mounted) Navigator.of(pdfDialogContext!, rootNavigator: true).pop();

      if (filePath != null) {
        _logger.i("PDF gerado com sucesso em $filePath");
        // Não mostre diálogo de sucesso aqui, apenas retorne o path
        // O _transferirCarrinho cuidará do feedback ao usuário.
        return filePath;
      } else {
        _logger.e("PDF: PdfGeneratorSimples.gerarPdfSimples retornou nulo.");
        if(mounted) _mostrarMensagemErroGeral("Erro desconhecido ao gerar PDF.");
        return null;
      }
    } catch (e, s) {
      _logger.e("PDF: Erro crítico em _gerarPDFComDadosSalvos", error: e, stackTrace: s);
      if (pdfDialogContext != null && mounted) Navigator.of(pdfDialogContext!, rootNavigator: true).pop();
      if(mounted) _mostrarMensagemErroGeral("Erro inesperado ao gerar PDF: $e");
      return null;
    } finally {
      pdfProgressoNotifier.dispose();
    }
  }

  // Método para mostrar mensagem de erro geral
  void _mostrarMensagemErroGeral(String mensagem) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // NOVO DIÁLOGO: Para mostrar pedido enviado com sucesso + PDF gerado
  Future<void> _mostrarDialogoPedidoEnviadoComPdf(BuildContext ctx, String numPedido, String filePath) async {
    if (!mounted) return;
    
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
          title: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green[700], size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Pedido Enviado com Sucesso", 
                  style: TextStyle(color: Colors.green[700], fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Seu pedido foi enviado para a central e o PDF foi gerado com sucesso!",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.numbers, size: 18, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Número do Pedido: $numPedido",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 18, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "PDF gerado em:",
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        filePath,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: const Text("Compartilhar PDF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await PdfGeneratorSimples.compartilharArquivo(filePath);
                if (mounted && context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // NOVO DIÁLOGO: Para mostrar erro no envio para API mas com PDF gerado
  Future<void> _mostrarDialogoErroEnvioComPdfGerado(
    BuildContext ctx, 
    http.Response response, 
    Map<String, dynamic> dadosPedido,
    String filePath
  ) async {
    if (!mounted) return;
    
    // Tentar extrair mensagem de erro da resposta
    String? errorMessage;
    try {
      if (response.body.isNotEmpty) {
        final responseData = jsonDecode(response.body);
        if (responseData is Map && responseData.containsKey('message')) {
          errorMessage = responseData['message'];
        }
      }
    } catch (_) {}
    
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 16),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Atenção: Pedido Não Enviado", 
                  style: TextStyle(color: Colors.deepOrange),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "O PDF do pedido foi gerado com sucesso, mas houve um problema ao enviar para a central.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
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
                      "Erro (${response.statusCode}): ${errorMessage ?? 'Erro de comunicação com o servidor'}",
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red[700]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Você pode tentar novamente ou compartilhar o PDF gerado.",
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          "PDF disponível em:",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        filePath,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
            OutlinedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: const Text("Compartilhar PDF"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D5CDE),
              ),
              onPressed: () async {
                await PdfGeneratorSimples.compartilharArquivo(filePath);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Tentar Novamente"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Fechar o diálogo
                Navigator.of(context).pop();
                
                // Tentar enviar novamente o pedido diretamente com os dados já preparados
                // _reenviarPedido(dadosPedido, filePath);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _mostrarDialogoErroConexao(
    BuildContext contextAtual,
    dynamic error,
    String observacao,
    String formaPagamento,
    Carrinho carrinhoProvider,
  ) async {
    if (!mounted) return;
    
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