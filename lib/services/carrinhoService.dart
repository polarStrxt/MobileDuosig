import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Para usar ApiResult

/// Serviço responsável por gerenciar operações de carrinho de compras
class CarrinhoService {
  final CarrinhoDao _carrinhoDao;
  final ProdutoDao _produtoDao;

  /// Construtor que permite injeção de dependências para testes
  CarrinhoService({
    CarrinhoDao? carrinhoDao,
    ProdutoDao? produtoDao,
  })  : _carrinhoDao = carrinhoDao ?? CarrinhoDao(),
        _produtoDao = produtoDao ?? ProdutoDao();

  /// Salva o carrinho atual no banco de dados
  ///
  /// [carrinho] O carrinho a ser salvo
  /// [cliente] O cliente associado ao carrinho
  /// Retorna um [ApiResult] indicando sucesso ou erro na operação
  Future<ApiResult<bool>> salvarCarrinho(Carrinho carrinho, Cliente? cliente) async {
    try {
      if (cliente == null) {
        return ApiResult.error("Não é possível salvar o carrinho sem um cliente associado");
      }

      if (carrinho.itens.isEmpty) {
        return ApiResult.success(true); // Sucesso, mas nada para salvar
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

      return ApiResult.success(true);
    } catch (e) {
      return ApiResult.error("Erro ao salvar carrinho: $e");
    }
  }

  /// Recupera um carrinho do banco de dados
  ///
  /// [cliente] O cliente cujo carrinho será recuperado
  /// Retorna um [ApiResult] contendo os itens e descontos do carrinho
  Future<ApiResult<Map<String, dynamic>>> recuperarCarrinho(Cliente cliente) async {
    try {
      print("🔍 Recuperando carrinho do cliente ${cliente.codcli}...");
      List<CarrinhoItem> itens = await _carrinhoDao.getItensCliente(cliente.codcli);

      Map<Produto, int> carrinhoItens = {};
      Map<Produto, double> descontos = {};

      for (var item in itens) {
        Produto? produto = await _produtoDao.getProdutoByCodigo(item.codprd);

        if (produto != null) {
          carrinhoItens[produto] = item.quantidade;
          descontos[produto] = item.desconto;
        }
      }

      return ApiResult.success({
        'itens': carrinhoItens,
        'descontos': descontos
      });
    } catch (e) {
      print("❌ Erro ao recuperar carrinho: $e");
      return ApiResult.error("Erro ao recuperar carrinho: $e");
    }
  }

  /// Finaliza um carrinho
  ///
  /// [cliente] O cliente cujo carrinho será finalizado
  /// Retorna um [ApiResult] indicando sucesso ou erro na operação
  Future<ApiResult<bool>> finalizarCarrinho(Cliente cliente) async {
    try {
      await _carrinhoDao.finalizarCarrinho(cliente.codcli);
      return ApiResult.success(true);
    } catch (e) {
      return ApiResult.error("Erro ao finalizar carrinho: $e");
    }
  }

  /// Limpa o carrinho de um cliente
  ///
  /// [cliente] O cliente cujo carrinho será limpo
  /// Retorna um [ApiResult] indicando sucesso ou erro na operação
  Future<ApiResult<bool>> limparCarrinho(Cliente cliente) async {
    try {
      await _carrinhoDao.limparCarrinho(cliente.codcli);
      return ApiResult.success(true);
    } catch (e) {
      return ApiResult.error("Erro ao limpar carrinho: $e");
    }
  }

  /// Verifica se um cliente tem um carrinho não finalizado
  ///
  /// [cliente] O cliente a ser verificado
  /// Retorna um [ApiResult] indicando se o cliente tem um carrinho ativo
  Future<ApiResult<bool>> clienteTemCarrinho(Cliente cliente) async {
    try {
      List<CarrinhoItem> itens = await _carrinhoDao
          .getItensCliente(cliente.codcli, apenasNaoFinalizados: true);
      return ApiResult.success(itens.isNotEmpty);
    } catch (e) {
      return ApiResult.error("Erro ao verificar carrinho: $e");
    }
  }
}