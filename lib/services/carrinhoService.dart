import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';

class CarrinhoService {
  final CarrinhoDao _carrinhoDao = CarrinhoDao();
  final ProdutoDao _produtoDao = ProdutoDao();

  // Salvar o carrinho atual no banco de dados
  Future<void> salvarCarrinho(Carrinho carrinho, Cliente? cliente) async {
    if (cliente == null) {
      print("⚠️ Não é possível salvar o carrinho sem um cliente associado");
      return;
    }

    if (carrinho.itens.isEmpty) {
      print("🛒 Carrinho vazio. Nada para salvar.");
      return;
    }

    for (var entry in carrinho.itens.entries) {
      Produto produto = entry.key;
      int quantidade = entry.value;
      double desconto = carrinho.descontos[produto] ?? 0.0;

      CarrinhoItem item = CarrinhoItem(
        codprd: produto.codprd,
        codcli: cliente.codcli,
        quantidade: quantidade,
        desconto: desconto,
      );

      await _carrinhoDao.salvarItem(item);
    }
  }

  // Recuperar um carrinho do banco de dados
  Future<Map<String, dynamic>> recuperarCarrinho(Cliente cliente) async {
    try {
      print("🔍 Recuperando carrinho do cliente ${cliente.codcli}...");
      List<CarrinhoItem> itens =
          await _carrinhoDao.getItensCliente(cliente.codcli);

      Map<Produto, int> carrinhoItens = {};
      Map<Produto, double> descontos = {};

      for (var item in itens) {
        Produto? produto = await _produtoDao.getProdutoByCodigo(item.codprd);

        if (produto != null) {
          carrinhoItens[produto] = item.quantidade;
          descontos[produto] = item.desconto;
        }
      }

      return {'itens': carrinhoItens, 'descontos': descontos};
    } catch (e) {
      print("❌ Erro ao recuperar carrinho: $e");
      return {'itens': <Produto, int>{}, 'descontos': <Produto, double>{}};
    }
  }

  // Finalizar um carrinho
  Future<void> finalizarCarrinho(Cliente cliente) async {
    await _carrinhoDao.finalizarCarrinho(cliente.codcli);
  }

  // Limpar o carrinho de um cliente
  Future<void> limparCarrinho(Cliente cliente) async {
    await _carrinhoDao.limparCarrinho(cliente.codcli);
  }

  // Verificar se um cliente tem um carrinho não finalizado
  Future<bool> clienteTemCarrinho(Cliente cliente) async {
    List<CarrinhoItem> itens = await _carrinhoDao
        .getItensCliente(cliente.codcli, apenasNaoFinalizados: true);
    return itens.isNotEmpty;
  }
}
