// lib/widgets/carrinho.dart
import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';

class Carrinho extends ChangeNotifier {
  final Map<ProdutoModel, int> _itens = {};
  final Map<ProdutoModel, double> _descontos = {}; // Percentual

  // Construtor para permitir inicialização (útil para o service)
  Carrinho({Map<ProdutoModel, int>? itens, Map<ProdutoModel, double>? descontos}) {
    if (itens != null) {
      _itens.addAll(itens);
    }
    if (descontos != null) {
      _descontos.addAll(descontos);
    }
  }

  Map<ProdutoModel, int> get itens => Map.unmodifiable(_itens);
  Map<ProdutoModel, double> get descontos => Map.unmodifiable(_descontos);

  int get quantidadeTotal =>
      _itens.values.fold(0, (total, quantidade) => total + quantidade);
      
  bool get isEmpty => _itens.isEmpty;

  double calcularSubtotal(int clienteTabela) {
    double total = 0.0;
    _itens.forEach((produto, quantidade) {
      double preco = produto.getPrecoParaTabela(clienteTabela);
      total += preco * quantidade;
    });
    return total;
  }

  double calcularTotalDescontosValor(int clienteTabela) {
    double totalDescontos = 0.0;
    _itens.forEach((produto, quantidade) {
      double preco = produto.getPrecoParaTabela(clienteTabela);
      double descontoPercentual = _descontos[produto] ?? 0.0;
      double valorDescontoLinha = preco * (descontoPercentual / 100) * quantidade;
      totalDescontos += valorDescontoLinha;
    });
    return totalDescontos;
  }

  double calcularValorTotal(int clienteTabela) {
    return calcularSubtotal(clienteTabela) - calcularTotalDescontosValor(clienteTabela);
  }

  void adicionarItem(ProdutoModel produto, int quantidade, [double descontoPercentual = 0.0]) {
    if (produto.codprd == null) return; // Não adicionar produtos sem ID

    int quantidadeAtual = _itens[produto] ?? 0;
    int novaQuantidade = quantidadeAtual + quantidade;

    if (novaQuantidade <= 0) {
      removerItem(produto); // Chama notifyListeners internamente
      return;
    }
    
    _itens[produto] = novaQuantidade;

    if (descontoPercentual >= 0) { // Permite aplicar 0 para remover desconto existente
      if (produto.perdscmxm > 0 && descontoPercentual > produto.perdscmxm) {
        _descontos[produto] = produto.perdscmxm;
      } else {
        _descontos[produto] = descontoPercentual;
      }
      if (descontoPercentual == 0) { // Se o desconto for explicitamente 0, remove do mapa
          _descontos.remove(produto);
      }
    }
    notifyListeners();
  }

  void removerItem(ProdutoModel produto) {
    if (produto.codprd == null) return;
    _itens.remove(produto);
    _descontos.remove(produto);
    notifyListeners();
  }

  void atualizarQuantidade(ProdutoModel produto, int novaQuantidade) {
    if (produto.codprd == null) return;
    if (novaQuantidade <= 0) {
      removerItem(produto);
    } else {
      _itens[produto] = novaQuantidade;
      if (!_itens.containsKey(produto)) { // Se foi removido por quantidade 0 e depois re-adicionado por outro fluxo
        _descontos.remove(produto);
      }
      notifyListeners();
    }
  }

  void atualizarDesconto(ProdutoModel produto, double novoDescontoPercentual) {
    if (produto.codprd == null || !_itens.containsKey(produto)) {
      return;
    }

    if (novoDescontoPercentual <= 0) {
      _descontos.remove(produto);
    } else {
      if (produto.perdscmxm > 0 && novoDescontoPercentual > produto.perdscmxm) {
        _descontos[produto] = produto.perdscmxm;
      } else {
        _descontos[produto] = novoDescontoPercentual;
      }
    }
    notifyListeners();
  }

  double precoUnitarioComDesconto(ProdutoModel produto, int clienteTabela) {
    if (produto.codprd == null) return 0.0;
    double precoBase = produto.getPrecoParaTabela(clienteTabela);
    double percentualDesconto = _descontos[produto] ?? 0.0;
    return precoBase * (1 - (percentualDesconto / 100));
  }

  // Retorna o VALOR do desconto para uma UNIDADE do produto
  double getValorDescontoUnidade(ProdutoModel produto, int clienteTabela) {
    if (produto.codprd == null || !_itens.containsKey(produto)) return 0.0;
    double precoBase = produto.getPrecoParaTabela(clienteTabela);
    double descontoPercentual = _descontos[produto] ?? 0.0;
    return precoBase * (descontoPercentual / 100);
  }

  void limpar() {
    _itens.clear();
    _descontos.clear();
    notifyListeners();
  }

  void substituir(Carrinho outroCarrinho) {
  _itens.clear();
  _descontos.clear();
  
  for (var entry in outroCarrinho.itens.entries) {
    _itens[entry.key] = entry.value;
  }
  
  for (var entry in outroCarrinho.descontos.entries) {
    _descontos[entry.key] = entry.value;
  }
  
  notifyListeners(); // Se Carrinho estender ChangeNotifier
  }
}