import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/condicao_pagamento_model.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:logger/logger.dart';

// Separate business logic into a dedicated service
class PedidoService {
  final Logger _logger = Logger();
  late final CarrinhoService _carrinhoService;
  
  PedidoService({required RepositoryManager repositoryManager}) {
    _carrinhoService = CarrinhoService(repositoryManager: repositoryManager);
  }

  Future<PedidoResult> processarPedido({
    required Carrinho carrinho,
    required Cliente cliente,
    required String observacao,
    required String formaPagamento,
    required String formaPagamentoDesc,
  }) async {
    try {
      // Generate order number
      final String numPedido = _gerarNumeroPedido(cliente);
      
      // Generate PDF
      final String? pdfPath = await _gerarPDF(
        carrinho: carrinho,
        cliente: cliente,
        observacao: observacao,
        formaPagamento: formaPagamentoDesc,
        numPedido: numPedido,
      );

      if (pdfPath == null) {
        return PedidoResult.erro('Falha ao gerar PDF');
      }

      // Try to send to API
      final bool enviado = await _enviarParaAPI(
        carrinho: carrinho,
        cliente: cliente,
        observacao: observacao,
        formaPagamento: formaPagamento,
        numPedido: numPedido,
      );

      if (enviado) {
        // Finalize cart after successful API call
        final result = await _carrinhoService.finalizarCarrinho(cliente);
        if (result.isSuccess) {
          return PedidoResult.sucesso(numPedido, pdfPath);
        } else {
          return PedidoResult.erro('Erro ao finalizar carrinho: ${result.errorMessage}');
        }
      } else {
        // Save locally for later transmission
        await _salvarPedidoLocal(
          carrinho: carrinho,
          cliente: cliente,
          observacao: observacao,
          formaPagamento: formaPagamento,
          numPedido: numPedido,
        );

        final result = await _carrinhoService.finalizarCarrinho(cliente);
        if (result.isSuccess) {
          return PedidoResult.sucessoLocal(numPedido, pdfPath);
        } else {
          return PedidoResult.erro('Erro ao finalizar carrinho após salvar localmente');
        }
      }
    } catch (e, s) {
      _logger.e('Erro ao processar pedido', error: e, stackTrace: s);
      return PedidoResult.erro('Erro inesperado: $e');
    }
  }

  String _gerarNumeroPedido(Cliente cliente) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    return '$timestamp-${cliente.codcli}';
  }

  Future<String?> _gerarPDF({
    required Carrinho carrinho,
    required Cliente cliente,
    required String observacao,
    required String formaPagamento,
    required String numPedido,
  }) async {
    // Implementation for PDF generation
    // Return file path or null if failed
    return null; // Placeholder
  }

  Future<bool> _enviarParaAPI({
    required Carrinho carrinho,
    required Cliente cliente,
    required String observacao,
    required String formaPagamento,
    required String numPedido,
  }) async {
    // Implementation for API call
    return false; // Placeholder
  }

  Future<void> _salvarPedidoLocal({
    required Carrinho carrinho,
    required Cliente cliente,
    required String observacao,
    required String formaPagamento,
    required String numPedido,
  }) async {
    // Implementation for local storage
  }
}

// Result class for better error handling
class PedidoResult {
  final bool success;
  final String? numPedido;
  final String? pdfPath;
  final String? errorMessage;
  final bool isLocal;

  PedidoResult.sucesso(this.numPedido, this.pdfPath)
      : success = true,
        errorMessage = null,
        isLocal = false;

  PedidoResult.sucessoLocal(this.numPedido, this.pdfPath)
      : success = true,
        errorMessage = null,
        isLocal = true;

  PedidoResult.erro(this.errorMessage)
      : success = false,
        numPedido = null,
        pdfPath = null,
        isLocal = false;
}

// Configuration class for constants
class AppConfig {
  static const String apiUrl = 'http://duotecsuprilev.ddns.com.br:8082/v1/pedido';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const String vendedorPadrao = '001';
}

// Simplified UI Controller
class CarrinhoController extends ChangeNotifier {
  bool _isProcessing = false;
  String? _errorMessage;
  
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  late final PedidoService _pedidoService;
  final Logger _logger = Logger();

  CarrinhoController({required RepositoryManager repositoryManager}) {
    _pedidoService = PedidoService(repositoryManager: repositoryManager);
  }

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  Future<void> atualizarQuantidade(
    Carrinho carrinho,
    ProdutoModel produto,
    int quantidade,
    Cliente cliente,
  ) async {
    _setProcessing(true);
    try {
      carrinho.atualizarQuantidade(produto, quantidade);
      await _persistirCarrinho(carrinho, cliente);
      _setError(null);
    } catch (e) {
      _logger.e('Erro ao atualizar quantidade', error: e);
      _setError('Erro ao atualizar quantidade: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> atualizarDesconto(
    Carrinho carrinho,
    ProdutoModel produto,
    double desconto,
    Cliente cliente,
  ) async {
    _setProcessing(true);
    try {
      carrinho.atualizarDesconto(produto, desconto);
      await _persistirCarrinho(carrinho, cliente);
      _setError(null);
    } catch (e) {
      _logger.e('Erro ao atualizar desconto', error: e);
      _setError('Erro ao atualizar desconto: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> removerProduto(
    Carrinho carrinho,
    ProdutoModel produto,
    Cliente cliente,
  ) async {
    _setProcessing(true);
    try {
      carrinho.removerItem(produto);
      await _persistirCarrinho(carrinho, cliente);
      _setError(null);
    } catch (e) {
      _logger.e('Erro ao remover produto', error: e);
      _setError('Erro ao remover produto: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<PedidoResult> finalizarPedido({
    required Carrinho carrinho,
    required Cliente cliente,
    required String observacao,
    required String formaPagamento,
    required String formaPagamentoDesc,
  }) async {
    _setProcessing(true);
    try {
      final result = await _pedidoService.processarPedido(
        carrinho: carrinho,
        cliente: cliente,
        observacao: observacao,
        formaPagamento: formaPagamento,
        formaPagamentoDesc: formaPagamentoDesc,
      );
      
      if (result.success) {
        _setError(null);
      } else {
        _setError(result.errorMessage);
      }
      
      return result;
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _persistirCarrinho(Carrinho carrinho, Cliente cliente) async {
  // Usa o carrinhoService já existente dentro do _pedidoService
  final result = await _pedidoService._carrinhoService.salvarAlteracoesCarrinho(carrinho, cliente);
  
  if (!result.isSuccess) {
    throw Exception(result.errorMessage);
  }
}

}

// Simplified main screen
class CarrinhoScreen extends StatefulWidget {
  final Cliente? cliente;
  final int? codcli;

  const CarrinhoScreen({
    super.key,
    this.cliente,
    required this.codcli,
  });

  @override
  State<CarrinhoScreen> createState() => _CarrinhoScreenState();
}

class _CarrinhoScreenState extends State<CarrinhoScreen> {
  late final CarrinhoController _controller;
  late final List<CondicaoPagamentoModel> _condicoesPagamento;

  @override
  void initState() {
    super.initState();
    final repositoryManager = context.read<RepositoryManager>();
    _controller = CarrinhoController(repositoryManager: repositoryManager);
    _condicoesPagamento = _carregarCondicoesPagamento();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CondicaoPagamentoModel> _carregarCondicoesPagamento() {
    // Load payment conditions - could be moved to a separate service
    // Remove unused jsonData variable and implement proper parsing
    return [
      CondicaoPagamentoModel(
        codcndpgt: 1, 
        dcrcndpgt: "A VISTA", 
        perdsccel: 0.0, 
        staati: "S"
      ),
      CondicaoPagamentoModel(
        codcndpgt: 2, 
        dcrcndpgt: "C/APRESENTACAO", 
        perdsccel: 0.0, 
        staati: "S"
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
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
          builder: (context, carrinho, child) {
            return Consumer<CarrinhoController>(
              builder: (context, controller, child) {
                return _buildBody(carrinho, controller);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(Carrinho carrinho, CarrinhoController controller) {
    if (controller.isProcessing) {
      return _buildLoadingState();
    }

    if (controller.errorMessage != null) {
      return _buildErrorState(controller.errorMessage!);
    }

    if (carrinho.isEmpty) {
      return _buildEmptyCart();
    }

    return _buildCartContent(carrinho, controller);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
          ),
          SizedBox(height: 24),
          Text('Processando...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
            const SizedBox(height: 24),
            Text(
              'Erro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
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
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text("Voltar para produtos"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D5CDE),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(Carrinho carrinho, CarrinhoController controller) {
    return Column(
      children: [
        if (widget.cliente != null) _buildClienteInfo(),
        Expanded(
          child: _buildCartItemsList(carrinho, controller),
        ),
        _buildCartSummary(carrinho, controller),
      ],
    );
  }

  Widget _buildClienteInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: const Color(0xFF5D5CDE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Color(0xFF5D5CDE),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.cliente!.nomcli ?? 'Cliente sem nome',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  "Código: ${widget.cliente!.codcli}",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemsList(Carrinho carrinho, CarrinhoController controller) {
    final produtos = carrinho.itens.keys.toList();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final produto = produtos[index];
        return CartItemWidget(
          produto: produto,
          carrinho: carrinho,
          controller: controller,
          cliente: widget.cliente,
        );
      },
    );
  }

  Widget _buildCartSummary(Carrinho carrinho, CarrinhoController controller) {
    final tabelaPreco = widget.cliente?.codtab ?? 1;
    final total = carrinho.calcularValorTotal(tabelaPreco);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(
                  'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D5CDE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: controller.isProcessing
                  ? null
                  : () => _mostrarDialogoFinalizarPedido(carrinho, controller),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D5CDE),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: controller.isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Processando...'),
                      ],
                    )
                  : const Text('Finalizar Carrinho'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoFinalizarPedido(
    Carrinho carrinho,
    CarrinhoController controller,
  ) async {
    if (widget.cliente == null) {
      _mostrarErroClienteNaoAssociado();
      return;
    }

    String observacao = '';
    CondicaoPagamentoModel? formaPagamentoSelecionada = 
        _condicoesPagamento.isNotEmpty ? _condicoesPagamento.first : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => PedidoDialog(
        cliente: widget.cliente!,
        carrinho: carrinho,
        condicoesPagamento: _condicoesPagamento,
        onObservacaoChanged: (value) => observacao = value,
        onFormaPagamentoChanged: (value) => formaPagamentoSelecionada = value,
      ),
    );

    if (result == true && formaPagamentoSelecionada != null) {
      final pedidoResult = await controller.finalizarPedido(
        carrinho: carrinho,
        cliente: widget.cliente!,
        observacao: observacao,
        formaPagamento: formaPagamentoSelecionada!.codcndpgt.toString(),
        formaPagamentoDesc: formaPagamentoSelecionada!.dcrcndpgt,
      );

      if (pedidoResult.success && mounted) {
        // Clear cart and show success
        Provider.of<Carrinho>(context, listen: false).limpar();
        _mostrarSucesso(pedidoResult);
      }
    }
  }

  void _mostrarErroClienteNaoAssociado() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Atenção"),
        content: const Text(
          "Não há cliente associado a este pedido.",
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

  void _mostrarSucesso(PedidoResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text("Pedido Finalizado"),
          ],
        ),
        content: Text(
          result.isLocal
              ? "Pedido salvo localmente (Nº: ${result.numPedido})"
              : "Pedido enviado com sucesso (Nº: ${result.numPedido})",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

// Separate widget for cart items
class CartItemWidget extends StatelessWidget {
  final ProdutoModel produto;
  final Carrinho carrinho;
  final CarrinhoController controller;
  final Cliente? cliente;

  const CartItemWidget({
    super.key,
    required this.produto,
    required this.carrinho,
    required this.controller,
    required this.cliente,
  });

  @override
  Widget build(BuildContext context) {
    final quantidade = carrinho.itens[produto] ?? 0;
    final desconto = carrinho.descontos[produto] ?? 0.0;
    final tabelaPreco = cliente?.codtab ?? 1;
    final preco = produto.getPrecoParaTabela(tabelaPreco);
    final precoComDesconto = preco * (1 - desconto / 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF5D5CDE),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.dcrprd,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cód: ${produto.codprd}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'R\$ ${precoComDesconto.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5D5CDE),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity controls
                Row(
                  children: [
                    IconButton(
                      onPressed: quantidade > 1
                          ? () => controller.atualizarQuantidade(
                                carrinho,
                                produto,
                                quantidade - 1,
                                cliente!,
                              )
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$quantidade'),
                    IconButton(
                      onPressed: () => controller.atualizarQuantidade(
                        carrinho,
                        produto,
                        quantidade + 1,
                        cliente!,
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                
                // Remove button
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remover', style: TextStyle(color: Colors.red)),
                  onPressed: () => controller.removerProduto(
                    carrinho,
                    produto,
                    cliente!,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Separate dialog widget
class PedidoDialog extends StatefulWidget {
  final Cliente cliente;
  final Carrinho carrinho;
  final List<CondicaoPagamentoModel> condicoesPagamento;
  final Function(String) onObservacaoChanged;
  final Function(CondicaoPagamentoModel?) onFormaPagamentoChanged;

  const PedidoDialog({
    super.key,
    required this.cliente,
    required this.carrinho,
    required this.condicoesPagamento,
    required this.onObservacaoChanged,
    required this.onFormaPagamentoChanged,
  });

  @override
  State<PedidoDialog> createState() => _PedidoDialogState();
}

class _PedidoDialogState extends State<PedidoDialog> {
  CondicaoPagamentoModel? _formaSelecionada;

  @override
  void initState() {
    super.initState();
    _formaSelecionada = widget.condicoesPagamento.isNotEmpty
        ? widget.condicoesPagamento.first
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finalizar Pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Observação',
              hintText: 'Digite uma observação (opcional)',
            ),
            maxLines: 3,
            onChanged: widget.onObservacaoChanged,
          ),
          const SizedBox(height: 16),
          if (widget.condicoesPagamento.isNotEmpty)
            DropdownButtonFormField<CondicaoPagamentoModel>(
              value: _formaSelecionada,
              decoration: const InputDecoration(
                labelText: 'Forma de Pagamento',
              ),
              items: widget.condicoesPagamento.map((condicao) {
                return DropdownMenuItem(
                  value: condicao,
                  child: Text(condicao.dcrcndpgt),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _formaSelecionada = value;
                });
                widget.onFormaPagamentoChanged(value);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Finalizar'),
        ),
      ],
    );
  }
}