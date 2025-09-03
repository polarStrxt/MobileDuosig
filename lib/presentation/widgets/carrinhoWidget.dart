// lib/widgets/carrinho_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:logger/logger.dart';

/// Widget responsável pela exibição e gerenciamento do carrinho de compras
/// Integra com Repository pattern para persistência de dados
class CarrinhoWidget extends StatefulWidget {
  final Cliente cliente;
  final RepositoryManager repositoryManager;

  const CarrinhoWidget({
    super.key,
    required this.cliente,
    required this.repositoryManager,
  });

  @override
  State<CarrinhoWidget> createState() => _CarrinhoWidgetState();
}

class _CarrinhoWidgetState extends State<CarrinhoWidget> {
  final Logger _logger = Logger();
  
  // Estados da UI
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  CarrinhoModel? _carrinhoAtual;

  // Getters para facilitar acesso aos repositories
  CarrinhoRepository get _carrinhoRepo => widget.repositoryManager.carrinhos;
  CarrinhoItemRepository get _itemRepo => widget.repositoryManager.carrinhoItens;
  ProdutoRepository get _produtoRepo => widget.repositoryManager.produtos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _carregarCarrinhoDoBanco();
      }
    });
  }

  /// Carrega o carrinho do banco de dados e sincroniza com o Provider
  Future<void> _carregarCarrinhoDoBanco() async {
    if (!mounted) return;
    
    _setLoading(true);
    
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      
      // Busca ou cria carrinho aberto para o cliente
      _carrinhoAtual = await _carrinhoRepo.getOuCriarCarrinhoAberto(widget.cliente.codcli);
      
      if (_carrinhoAtual == null) {
        throw Exception('Não foi possível criar/recuperar carrinho');
      }
      
      // Busca os itens do carrinho
      final itensCarrinho = await _itemRepo.getItensPorIdCarrinho(_carrinhoAtual!.id!);
      
      // Limpa o provider antes de popular
      carrinhoProvider.limpar();
      
      // Popula o provider com os dados do banco
      for (final item in itensCarrinho) {
        final produto = await _produtoRepo.getProdutoByCodigo(item.codprd);
        if (produto != null) {
          final descontoPercentual = _calcularDescontoPercentual(
            item.precoUnitarioRegistrado,
            item.descontoItem,
          );
          carrinhoProvider.adicionarItem(produto, item.quantidade, descontoPercentual);
        }
      }
      
      _logger.i('Carrinho carregado: ${itensCarrinho.length} itens');
      _clearError();
      
    } catch (e, stackTrace) {
      _logger.e('Erro ao carregar carrinho', error: e, stackTrace: stackTrace);
      _setError('Erro ao carregar carrinho: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Persiste as alterações do carrinho no banco de dados
  Future<void> _persistirAlteracoesCarrinho() async {
    if (!mounted || _carrinhoAtual == null) return;
    
    _setSaving(true);
    
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      
      // Atualiza totais do carrinho
      final subtotal = carrinhoProvider.calcularSubtotal(widget.cliente.codtab);
      final totalDescontos = carrinhoProvider.calcularTotalDescontosValor(widget.cliente.codtab);
      final valorTotal = carrinhoProvider.calcularValorTotal(widget.cliente.codtab);
      
      await _carrinhoRepo.atualizarTotaisCarrinho(
        _carrinhoAtual!.id!,
        bruto: subtotal,
        descontos: totalDescontos,
        liquido: valorTotal,
      );
      
      // Limpa itens antigos
      await _itemRepo.limparItensDoCarrinho(_carrinhoAtual!.id!);
      
      // Insere itens atuais
      for (final entry in carrinhoProvider.itens.entries) {
        final produto = entry.key;
        final quantidade = entry.value;
        final descontoPercentual = carrinhoProvider.descontos[produto] ?? 0.0;
        
        final precoUnitario = _obterPrecoUnitarioProduto(produto, widget.cliente.codtab);
        final descontoValor = precoUnitario * (descontoPercentual / 100);
        
        final item = CarrinhoItemModel(
          idCarrinho: _carrinhoAtual!.id!,
          codprd: produto.codprd ?? 0,
          quantidade: quantidade,
          precoUnitarioRegistrado: precoUnitario,
          descontoItem: descontoValor,
          dataAdicao: DateTime.now(),
        );
        
        await _itemRepo.salvarOuAtualizarItem(item);
      }
      
      _logger.i('Alterações do carrinho persistidas com sucesso');
      
    } catch (e, stackTrace) {
      _logger.e('Erro ao persistir carrinho', error: e, stackTrace: stackTrace);
      _showError('Erro ao salvar alterações: ${e.toString()}');
    } finally {
      _setSaving(false);
    }
  }

  /// Adiciona item ao carrinho - Exposição pública para uso externo
  Future<void> adicionarItem(
    ProdutoModel produto,
    int quantidade,
    double descontoPercentual,
  ) async {
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.adicionarItem(produto, quantidade, descontoPercentual);
      await _persistirAlteracoesCarrinho();
    } catch (e) {
      _logger.e('Erro ao adicionar item', error: e);
      _showError('Erro ao adicionar item');
    }
  }

  /// Remove item do carrinho
  Future<void> _handleRemoverItem(ProdutoModel produto) async {
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.removerItem(produto);
      await _persistirAlteracoesCarrinho();
    } catch (e) {
      _logger.e('Erro ao remover item', error: e);
      _showError('Erro ao remover item');
    }
  }

  /// Atualiza quantidade de um item
  Future<void> _handleAtualizarQuantidade(ProdutoModel produto, int novaQuantidade) async {
    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.atualizarQuantidade(produto, novaQuantidade);
      await _persistirAlteracoesCarrinho();
    } catch (e) {
      _logger.e('Erro ao atualizar quantidade', error: e);
      _showError('Erro ao atualizar quantidade');
    }
  }

  /// Remove método não utilizado para limpar warnings

  /// Finaliza o pedido
  Future<void> _handleFinalizarPedido() async {
    if (!mounted || _carrinhoAtual == null) return;
    
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    if (carrinhoProvider.isEmpty) {
      _showError('Carrinho está vazio!');
      return;
    }
    
    _setLoading(true);
    
    try {
      // Atualiza status do carrinho para finalizado
      final sucesso = await _carrinhoRepo.atualizarStatusCarrinho(
        _carrinhoAtual!.id!,
        'finalizado',
      );
      
      if (sucesso) {
        _logger.i('Pedido finalizado para cliente ${widget.cliente.codcli}');
        carrinhoProvider.limpar();
        _showSuccess('Pedido finalizado com sucesso!');
        
        // TODO: Implementar lógica de criação de pedido
        // TODO: Navegar para tela de confirmação
      } else {
        throw Exception('Falha ao finalizar carrinho no banco');
      }
      
    } catch (e, stackTrace) {
      _logger.e('Erro ao finalizar pedido', error: e, stackTrace: stackTrace);
      _showError('Erro ao finalizar pedido: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Métodos auxiliares para gerenciamento de estado
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) _errorMessage = null;
      });
    }
  }

  void _setSaving(bool saving) {
    if (mounted) {
      setState(() => _isSaving = saving);
    }
  }

  void _setError(String error) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
    }
  }

  void _clearError() {
    if (mounted) {
      setState(() => _errorMessage = null);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Obtém o preço unitário de um produto considerando a tabela do cliente
  double _obterPrecoUnitarioProduto(ProdutoModel produto, int codtab) {
    // Retorna o preço baseado na tabela do cliente
    switch (codtab) {
      case 1:
        return produto.vlrtab1;
      case 2:
        return produto.vlrtab2;
      default:
        return produto.vlrbasvda; // Preço base como fallback
    }
  }

  /// Calcula desconto percentual baseado em valores absolutos
  double _calcularDescontoPercentual(double precoUnitario, double descontoValor) {
    if (precoUnitario <= 0) return 0.0;
    return (descontoValor / precoUnitario) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carrinho - ${widget.cliente.nomcli}'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Consumer<Carrinho>(
        builder: (context, carrinhoUi, child) {
          return _buildBody(carrinhoUi);
        },
      ),
    );
  }

  Widget _buildBody(Carrinho carrinhoUi) {
    // Estado de carregamento inicial
    if (_isLoading && carrinhoUi.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando carrinho...'),
          ],
        ),
      );
    }

    // Estado de erro
    if (_errorMessage != null && carrinhoUi.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _carregarCarrinhoDoBanco,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // Carrinho vazio
    if (carrinhoUi.isEmpty && !_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Seu carrinho está vazio',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Carrinho com itens
    return Column(
      children: [
        Expanded(child: _buildListaItens(carrinhoUi)),
        _buildResumoCarrinho(carrinhoUi),
      ],
    );
  }

  Widget _buildListaItens(Carrinho carrinhoUi) {
    return RefreshIndicator(
      onRefresh: _carregarCarrinhoDoBanco,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: carrinhoUi.itens.length,
        itemBuilder: (context, index) {
          final produto = carrinhoUi.itens.keys.elementAt(index);
          final quantidade = carrinhoUi.itens[produto] ?? 0;
          final descontoPercentual = carrinhoUi.descontos[produto] ?? 0.0;
          final precoUnitario = carrinhoUi.precoUnitarioComDesconto(produto, widget.cliente.codtab);
          final subtotal = precoUnitario * quantidade;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produto.dcrprd,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quantidade: $quantidade'),
                            Text('Preço unitário: R\$ ${precoUnitario.toStringAsFixed(2)}'),
                            if (descontoPercentual > 0)
                              Text(
                                'Desconto: ${descontoPercentual.toStringAsFixed(1)}%',
                                style: const TextStyle(color: Colors.green),
                              ),
                            Text(
                              'Subtotal: R\$ ${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: quantidade > 1 ? () => _handleAtualizarQuantidade(produto, quantidade - 1) : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Diminuir quantidade',
                              ),
                              IconButton(
                                onPressed: () => _handleAtualizarQuantidade(produto, quantidade + 1),
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Aumentar quantidade',
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => _handleRemoverItem(produto),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remover item',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumoCarrinho(Carrinho carrinhoUi) {
    final subtotal = carrinhoUi.calcularSubtotal(widget.cliente.codtab);
    final totalDescontos = carrinhoUi.calcularTotalDescontosValor(widget.cliente.codtab);
    final valorTotal = carrinhoUi.calcularValorTotal(widget.cliente.codtab);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RESUMO DO PEDIDO',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 24),
          _buildResumoLinha('Subtotal:', 'R\$ ${subtotal.toStringAsFixed(2)}'),
          if (totalDescontos > 0)
            _buildResumoLinha(
              'Descontos:',
              '- R\$ ${totalDescontos.toStringAsFixed(2)}',
              color: Colors.green,
            ),
          const Divider(height: 16),
          _buildResumoLinha(
            'Valor Total:',
            'R\$ ${valorTotal.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading || carrinhoUi.isEmpty ? null : _handleFinalizarPedido,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Finalizando...'),
                    ],
                  )
                : const Text(
                    'Finalizar Pedido',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoLinha(
    String label,
    String valor, {
    Color? color,
    TextStyle? style,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style?.copyWith(color: color) ?? TextStyle(color: color),
          ),
          Text(
            valor,
            style: style?.copyWith(color: color) ?? TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}