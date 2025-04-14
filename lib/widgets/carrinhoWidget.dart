import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';

class CarrinhoWidget extends StatefulWidget {
  // Mapa para guardar os produtos e suas quantidades
  final Map<Produto, int> itens;

  // Cliente associado ao carrinho
  final Cliente? cliente;

  // Mapa para guardar os descontos por produto
  final Map<Produto, double>? descontos;

  const CarrinhoWidget({
    Key? key,
    required this.itens,
    this.cliente,
    this.descontos,
  }) : super(key: key);

  // Método para recuperar carrinho do banco de dados
  Future<void> recuperarCarrinho() async {
    if (cliente == null) return;

    try {
      final carrinhoDao = CarrinhoDao();
      final itensDb = await carrinhoDao.getItensCliente(cliente!.codcli);

      // Limpar itens atuais
      itens.clear();

      // Converter itens do DB para o formato do CarrinhoWidget
      for (var item in itensDb) {
        // Aqui você precisaria buscar o objeto Produto correspondente
        // Exemplo simplificado:
        final produto = await _buscarProdutoPorCodigo(item.codprd);
        if (produto != null) {
          itens[produto] = item.quantidade;

          // Adicionar desconto, se existir
          if (item.desconto > 0 && descontos != null) {
            descontos![produto] = item.desconto;
          }
        }
      }
    } catch (e) {
      print('Erro ao recuperar carrinho: $e');
      rethrow;
    }
  }

  // Método auxiliar para buscar produto por código
  Future<Produto?> _buscarProdutoPorCodigo(int codprd) async {
    // Aqui você implementaria a lógica para buscar o produto
    // pelo código no banco de dados
    // Retorno fictício para exemplo:
    return null;
  }

  @override
  State<CarrinhoWidget> createState() => _CarrinhoWidgetState();
}

class _CarrinhoWidgetState extends State<CarrinhoWidget> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se está carregando
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Verifica se o carrinho está vazio
    if (widget.itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Seu carrinho está vazio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione produtos para continuar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Mostra a lista de itens do carrinho
    return ListView.builder(
      itemCount: widget.itens.length,
      itemBuilder: (context, index) {
        final produto = widget.itens.keys.elementAt(index);
        final quantidade = widget.itens[produto] ?? 0;
        final desconto = widget.descontos?[produto] ?? 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Detalhes do produto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.dcrprd,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Código: ${produto.codprd}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text('Quantidade: $quantidade'),
                      if (desconto > 0)
                        Text(
                            'Desconto: ${(desconto * 100).toStringAsFixed(2)}%'),
                    ],
                  ),
                ),

                // Controles de quantidade
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          _atualizarQuantidade(produto, quantidade - 1),
                    ),
                    Text('$quantidade', style: TextStyle(fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          _atualizarQuantidade(produto, quantidade + 1),
                    ),
                  ],
                ),

                // Botão de remover
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _removerItem(produto),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Método para atualizar a quantidade de um produto
  void _atualizarQuantidade(Produto produto, int novaQuantidade) {
    setState(() {
      if (novaQuantidade <= 0) {
        widget.itens.remove(produto);
        widget.descontos?.remove(produto);
      } else {
        widget.itens[produto] = novaQuantidade;
      }
    });

    // Aqui você pode adicionar lógica para persistir no banco de dados
    _salvarCarrinho();
  }

  // Método para remover um item do carrinho
  void _removerItem(Produto produto) {
    setState(() {
      widget.itens.remove(produto);
      widget.descontos?.remove(produto);
    });

    // Aqui você pode adicionar lógica para persistir no banco de dados
    _salvarCarrinho();
  }

  // Método para salvar o carrinho no banco de dados
  Future<void> _salvarCarrinho() async {
    if (widget.cliente == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final carrinhoDao = CarrinhoDao();

      // Correção 1: Em vez de usar removerItensPorCliente, vamos remover cada item individualmente
      // Primeiro, obter os itens existentes
      final itensExistentes =
          await carrinhoDao.getItensCliente(widget.cliente!.codcli);

      // Remover cada item individualmente
      for (var item in itensExistentes) {
        await carrinhoDao.removerItem(item.codprd, widget.cliente!.codcli);
      }

      // Depois, adicionar cada item atualizado
      for (var entry in widget.itens.entries) {
        final produto = entry.key;
        final quantidade = entry.value;
        final desconto = widget.descontos?[produto] ?? 0.0;

        // Correção 2: Usar 0 (não finalizado) ou 1 (finalizado) em vez de boolean
        final item = CarrinhoItem(
          codprd: produto.codprd,
          codcli: widget.cliente!.codcli,
          quantidade: quantidade,
          desconto: desconto,
          finalizado: 0, // Usando 0 em vez de false (não finalizado)
          dataCriacao: DateTime.now(),
        );

        await carrinhoDao.salvarItem(item);
      }
    } catch (e) {
      print('Erro ao salvar carrinho: $e');
      // Aqui você poderia mostrar uma mensagem de erro para o usuário
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
