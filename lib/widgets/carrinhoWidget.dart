import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';

/// Classe que representa o carrinho de compras com seus itens, cliente e descontos
class CarrinhoWidget {
  final Map<Produto, int> itens;
  final Cliente? cliente;
  final Map<Produto, double> descontos;

  /// Construtor do CarrinhoWidget
  ///
  /// [itens]: Mapa de produtos e suas quantidades
  /// [cliente]: Cliente associado ao pedido (opcional).
  /// [descontos]: Mapa de produtos e seus percentuais de desconto (opcional)
  CarrinhoWidget({
    required this.itens,
    this.cliente,
    Map<Produto, double>? descontos,
  }) : this.descontos = descontos ?? {};

  /// Obtém o desconto aplicado a um produto específico
  /// Retorna 0.0 se não houver desconto
  double getDescontoProduto(Produto produto) {
    return descontos[produto] ?? 0.0;
  }

  /// Calcula o preço unitário de um produto com desconto aplicado
  double precoUnitarioComDesconto(Produto produto) {
    final int tabelaPreco = cliente?.codtab ?? 1;
    double precoBase = tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
    double desconto = getDescontoProduto(produto);
    return precoBase * (1 - desconto / 100);
  }

  /// Calcula o subtotal de um produto (preço com desconto * quantidade)
  double subtotalProduto(Produto produto) {
    int quantidade = itens[produto] ?? 0;
    return precoUnitarioComDesconto(produto) * quantidade;
  }

  /// Calcula o subtotal do carrinho (sem aplicar descontos)
  double calcularSubtotal() {
    double subtotal = 0.0;
    final int tabelaPreco = cliente?.codtab ?? 1;

    itens.forEach((produto, quantidade) {
      double preco = tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
      subtotal += preco * quantidade;
    });

    return subtotal;
  }

  /// Calcula o valor total dos descontos aplicados
  double calcularTotalDescontos() {
    double totalSemDesconto = calcularSubtotal();
    double totalComDesconto = calcularValorTotal();
    return totalSemDesconto - totalComDesconto;
  }

  /// Calcula o valor total do carrinho com descontos aplicados
  double calcularValorTotal() {
    double total = 0.0;
    final int tabelaPreco = cliente?.codtab ?? 1;

    itens.forEach((produto, quantidade) {
      double preco = tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;

      // Aplicar desconto se existir
      if (descontos.containsKey(produto)) {
        double desconto = descontos[produto] ?? 0.0;
        preco = preco * (1 - desconto / 100);
      }

      total += preco * quantidade;
    });

    return total;
  }

  /// Quantidade total de itens no carrinho
  int get quantidadeTotal =>
      itens.values.fold(0, (total, quantidade) => total + quantidade);

  /// Número total de produtos diferentes no carrinho
  int get totalProdutosDiferentes => itens.length;

  /// Verifica se o carrinho está vazio
  bool get isEmpty => itens.isEmpty;

  /// Verifica se há algum desconto aplicado no carrinho
  bool get temDescontos => descontos.values.any((desconto) => desconto > 0);
}
