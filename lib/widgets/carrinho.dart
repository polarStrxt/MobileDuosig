import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';

class Carrinho extends ChangeNotifier {
  // Mapa que armazena produtos e suas quantidades
  final Map<Produto, int> _itens = {};

  // Mapa que armazena descontos por produto (em percentual)
  final Map<Produto, double> _descontos = {};

  // Getter para acessar os itens
  Map<Produto, int> get itens => _itens;

  // Getter para acessar os descontos
  Map<Produto, double> get descontos => _descontos;

  // Quantidade total de itens no carrinho
  int get quantidadeTotal =>
      _itens.values.fold(0, (total, quantidade) => total + quantidade);

  // Valor total do carrinho sem descontos
  double calcularSubtotal(int clienteTabela) {
    double total = 0.0;
    _itens.forEach((produto, quantidade) {
      double preco = clienteTabela == 1 ? produto.vlrtab1 : produto.vlrtab2;
      total += preco * quantidade;
    });
    return total;
  }

  // Valor total dos descontos
  double calcularTotalDescontos(int clienteTabela) {
    double totalDescontos = 0.0;
    _itens.forEach((produto, quantidade) {
      double preco = clienteTabela == 1 ? produto.vlrtab1 : produto.vlrtab2;
      double desconto = _descontos[produto] ?? 0.0;
      double valorDesconto = preco * (desconto / 100) * quantidade;
      totalDescontos += valorDesconto;
    });
    return totalDescontos;
  }

  // Valor total do carrinho considerando descontos
  double calcularValorTotal(int clienteTabela) {
    double subtotal = calcularSubtotal(clienteTabela);
    double totalDescontos = calcularTotalDescontos(clienteTabela);
    return subtotal - totalDescontos;
  }

  // Adicionar item ao carrinho com desconto opcional
  void adicionarItem(Produto produto, int quantidade, [double desconto = 0.0]) {
    if (_itens.containsKey(produto)) {
      // Se o produto já existe, somar à quantidade existente
      _itens[produto] = (_itens[produto] ?? 0) + quantidade;
    } else {
      // Caso contrário, adicionar novo item
      _itens[produto] = quantidade;
    }

    // Armazenar o desconto para este produto
    if (desconto > 0) {
      // Verificar se perdscmxm impõe limite de desconto
      if (produto.perdscmxm > 0) {
        // Se perdscmxm > 0, limitar o desconto a esse valor
        _descontos[produto] =
            desconto > produto.perdscmxm ? produto.perdscmxm : desconto;
      } else {
        // Se perdscmxm = 0, permitir qualquer valor de desconto
        _descontos[produto] = desconto;
      }
    }

    // Notificar os listeners sobre a mudança
    notifyListeners();
  }

  // Remover item do carrinho
  void removerItem(Produto produto) {
    _itens.remove(produto);
    _descontos.remove(produto);
    notifyListeners();
  }

  // Atualizar quantidade de um item
  void atualizarQuantidade(Produto produto, int quantidade) {
    if (quantidade <= 0) {
      removerItem(produto);
    } else {
      _itens[produto] = quantidade;
      notifyListeners();
    }
  }

  // Atualizar desconto de um item
  void atualizarDesconto(Produto produto, double desconto) {
    if (!_itens.containsKey(produto)) {
      return; // Não podemos aplicar desconto a um produto que não está no carrinho
    }

    if (desconto <= 0) {
      _descontos.remove(produto); // Remover desconto se for zero ou negativo
    } else {
      // Verificar se perdscmxm impõe limite de desconto
      if (produto.perdscmxm > 0) {
        // Se perdscmxm > 0, limitar o desconto a esse valor
        _descontos[produto] =
            desconto > produto.perdscmxm ? produto.perdscmxm : desconto;
      } else {
        // Se perdscmxm = 0, permitir qualquer valor de desconto
        _descontos[produto] = desconto;
      }
    }

    notifyListeners();
  }

  // Obter o preço unitário de um produto (considerando a tabela e o desconto)
  double precoUnitario(Produto produto, int clienteTabela) {
    double precoBase = clienteTabela == 1 ? produto.vlrtab1 : produto.vlrtab2;
    double percentualDesconto = _descontos[produto] ?? 0.0;
    return precoBase * (1 - percentualDesconto / 100);
  }

  // Limpar carrinho
  void limpar() {
    _itens.clear();
    _descontos.clear();
    notifyListeners();
  }
}
