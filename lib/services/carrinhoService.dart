// lib/services/carrinho_service.dart
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:logger/logger.dart';

class CarrinhoService {
  final RepositoryManager _repositoryManager;
  final Logger _logger;

  CarrinhoService({
    required RepositoryManager repositoryManager,
    Logger? logger,
  }) : _repositoryManager = repositoryManager,
       _logger = logger ?? Logger();

  /// Salva as alterações do carrinho em memória para o banco de dados
  Future<ApiResult<bool>> salvarAlteracoesCarrinho(
      Carrinho carrinhoEmMemoria, Cliente cliente) async {
    try {
      // Validações iniciais
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return validationResult;
      }

      final carrinhoDb = await _repositoryManager.carrinhos
          .getOuCriarCarrinhoAberto(cliente.codcli);

      if (carrinhoDb == null) {
        _logger.e("Falha ao obter/criar carrinho DB para cliente ${cliente.codcli}");
        return ApiResult.error("Falha ao acessar o carrinho no banco de dados.");
      }

      // Se carrinho em memória está vazio, limpa o banco
      if (carrinhoEmMemoria.isEmpty) {
        await _repositoryManager.carrinhoItens.limparItensDoCarrinho(carrinhoDb.id!);
        _logger.i("Carrinho em memória vazio. Itens do carrinho DB ${carrinhoDb.id} limpos.");
        return ApiResult.success(true);
      }

      return await _processarItensCarrinho(carrinhoEmMemoria, cliente, carrinhoDb);
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao salvar alterações do carrinho", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao salvar carrinho: $e");
    }
  }

  /// Recupera o carrinho do cliente do banco de dados
  Future<ApiResult<Carrinho>> recuperarCarrinho(Cliente cliente) async {
    try {
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return ApiResult.error(validationResult.errorMessage!);
      }

      _logger.i("Recuperando carrinho do cliente ${cliente.codcli}");
      
      final carrinhoDb = await _repositoryManager.carrinhos
          .getCarrinhoAberto(cliente.codcli);

      if (carrinhoDb == null) {
        _logger.i("Nenhum carrinho aberto para cliente ${cliente.codcli}");
        return ApiResult.success(Carrinho());
      }

      final itensDb = await _repositoryManager.carrinhoItens
          .getItensPorIdCarrinho(carrinhoDb.id!);

      final carrinhoRecuperado = await _construirCarrinhoFromItens(itensDb);

      _logger.i("Carrinho recuperado para cliente ${cliente.codcli} com ${carrinhoRecuperado.itens.length} tipos");
      return ApiResult.success(carrinhoRecuperado);
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao recuperar carrinho", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao recuperar carrinho: $e");
    }
  }

  /// Finaliza o carrinho do cliente
  Future<ApiResult<bool>> finalizarCarrinho(Cliente cliente) async {
    try {
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return validationResult;
      }

      final carrinhoDb = await _repositoryManager.carrinhos
          .getCarrinhoAberto(cliente.codcli);

      if (carrinhoDb == null) {
        _logger.w("Nenhum carrinho aberto para finalizar do cliente ${cliente.codcli}");
        return ApiResult.error("Nenhum carrinho aberto para finalizar.");
      }

      final itens = await _repositoryManager.carrinhoItens
          .getItensPorIdCarrinho(carrinhoDb.id!);

      final novoStatus = itens.isEmpty ? 'abandonado' : 'finalizado';
      final sucesso = await _repositoryManager.carrinhos
          .atualizarStatusCarrinho(carrinhoDb.id!, novoStatus);

      if (sucesso) {
        _logger.i("Carrinho ${carrinhoDb.id} $novoStatus para cliente ${cliente.codcli}");
        return ApiResult.success(true);
      } else {
        return ApiResult.error("Falha ao finalizar o carrinho no banco de dados.");
      }
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao finalizar carrinho", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao finalizar carrinho: $e");
    }
  }

  /// Limpa todos os itens do carrinho do cliente
  Future<ApiResult<bool>> limparCarrinho(Cliente cliente) async {
    try {
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return validationResult;
      }

      final carrinhoDb = await _repositoryManager.carrinhos
          .getCarrinhoAberto(cliente.codcli);

      if (carrinhoDb != null) {
        await _repositoryManager.carrinhoItens.limparItensDoCarrinho(carrinhoDb.id!);
        _logger.i("Itens do carrinho ${carrinhoDb.id} limpos para cliente ${cliente.codcli}");
      }
      
      return ApiResult.success(true);
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao limpar carrinho", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao limpar carrinho: $e");
    }
  }

  /// Verifica se o cliente tem carrinho com itens pendentes
  Future<ApiResult<bool>> clienteTemCarrinhoPendente(Cliente cliente) async {
    try {
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return ApiResult.success(false);
      }

      final carrinhoDb = await _repositoryManager.carrinhos
          .getCarrinhoAberto(cliente.codcli);

      if (carrinhoDb == null) {
        return ApiResult.success(false);
      }

      final itens = await _repositoryManager.carrinhoItens
          .getItensPorIdCarrinho(carrinhoDb.id!);
      
      final temItens = itens.isNotEmpty;
      _logger.d("Cliente ${cliente.codcli} tem carrinho pendente: $temItens");
      
      return ApiResult.success(temItens);
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao verificar carrinho pendente", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao verificar carrinho: $e");
    }
  }

  /// Retorna lista de clientes que possuem carrinhos abertos
  Future<ApiResult<List<Cliente>>> getClientesComCarrinhosAbertos() async {
    try {
      final codigosClientes = await _repositoryManager.carrinhos
          .getCodigosClientesComCarrinhoAberto();

      if (codigosClientes.isEmpty) {
        _logger.i("Nenhum cliente com carrinho aberto");
        return ApiResult.success(<Cliente>[]);
      }

      final clientes = <Cliente>[];
      for (final codigo in codigosClientes) {
        final cliente = await _repositoryManager.clientes.getClienteByCodigo(codigo);
        if (cliente != null) {
          clientes.add(cliente);
        }
      }

      _logger.i("Retornando ${clientes.length} clientes com carrinhos abertos");
      return ApiResult.success(clientes);
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao buscar clientes com carrinhos abertos", error: e, stackTrace: stackTrace);
      return ApiResult.error("Falha ao carregar clientes com carrinho: $e");
    }
  }

  /// Obtém estatísticas do carrinho do cliente
  Future<ApiResult<Map<String, dynamic>>> obterEstatisticasCarrinho(Cliente cliente) async {
    try {
      final validationResult = _validateCliente(cliente);
      if (!validationResult.isSuccess) {
        return ApiResult.error(validationResult.errorMessage!);
      }

      final carrinhoDb = await _repositoryManager.carrinhos
          .getCarrinhoAberto(cliente.codcli);

      if (carrinhoDb == null) {
        return ApiResult.success({
          'temCarrinho': false,
          'totalItens': 0,
          'valorTotal': 0.0,
        });
      }

      final itens = await _repositoryManager.carrinhoItens
          .getItensPorIdCarrinho(carrinhoDb.id!);

      final totalItens = itens.fold<int>(0, (sum, item) => sum + item.quantidade);
      final valorTotal = itens.fold<double>(0.0, (sum, item) => 
          sum + (item.precoUnitarioRegistrado * item.quantidade - item.descontoItem));

      return ApiResult.success({
        'temCarrinho': true,
        'totalItens': totalItens,
        'tiposItens': itens.length,
        'valorTotal': valorTotal,
        'dataCriacao': carrinhoDb.dataCriacao?.toIso8601String(),
        'dataUltimaModificacao': carrinhoDb.dataUltimaModificacao?.toIso8601String(),
      });
      
    } catch (e, stackTrace) {
      _logger.e("Erro ao obter estatísticas do carrinho", error: e, stackTrace: stackTrace);
      return ApiResult.error("Erro ao obter estatísticas: $e");
    }
  }

  // ==================== MÉTODOS PRIVADOS ====================

  /// Valida se o cliente possui dados necessários
  ApiResult<bool> _validateCliente(Cliente cliente) {
    if (cliente.codcli == null) {
      _logger.e("Cliente sem código (codcli)");
      return ApiResult.error("Cliente inválido.");
    }
    return ApiResult.success(true);
  }

  /// Processa os itens do carrinho para salvar no banco
  Future<ApiResult<bool>> _processarItensCarrinho(
      Carrinho carrinhoMemoria, Cliente cliente, CarrinhoModel carrinhoDb) async {
    
    bool algumaAlteracaoFeita = false;
    
    final itensNoBanco = await _repositoryManager.carrinhoItens
        .getItensPorIdCarrinho(carrinhoDb.id!);
    
    final itensNoBancoMap = <int, CarrinhoItemModel>{
      for (var item in itensNoBanco)
        if (item.codprd != null) item.codprd! : item
    };

    // Processa itens em memória
    for (final entry in carrinhoMemoria.itens.entries) {
      final produto = entry.key;
      final quantidadeMemoria = entry.value;
      final descontoPercentual = carrinhoMemoria.descontos[produto] ?? 0.0;

      if (produto.codprd == null) {
        _logger.w("Produto ${produto.dcrprd} sem codprd");
        continue;
      }

      final precoUnitario = produto.getPrecoParaTabela(cliente.codtab);
      final valorDesconto = precoUnitario * (descontoPercentual / 100);

      final itemParaSalvar = CarrinhoItemModel(
        id: itensNoBancoMap[produto.codprd!]?.id,
        idCarrinho: carrinhoDb.id!,
        codprd: produto.codprd!,
        quantidade: quantidadeMemoria,
        precoUnitarioRegistrado: precoUnitario,
        descontoItem: valorDesconto,
        dataAdicao: DateTime.now(),
      );

      final itemExistente = itensNoBancoMap[produto.codprd!];
      
      if (itemExistente != null) {
        if (_itemPrecisaAtualizacao(itemExistente, itemParaSalvar)) {
          // Usar upsert ao invés de update inexistente
          await _repositoryManager.carrinhoItens.upsert(itemParaSalvar);
          algumaAlteracaoFeita = true;
        }
      } else {
        await _repositoryManager.carrinhoItens.salvarOuAtualizarItem(itemParaSalvar);
        algumaAlteracaoFeita = true;
      }
      
      itensNoBancoMap.remove(produto.codprd!);
    }

    // Remove itens que não estão mais no carrinho em memória
    for (final itemRemover in itensNoBancoMap.values) {
      if (itemRemover.id != null) {
        await _repositoryManager.carrinhoItens.removerItemPorId(itemRemover.id!);
        algumaAlteracaoFeita = true;
      }
    }

    if (algumaAlteracaoFeita) {
      await _repositoryManager.carrinhos.atualizarTotaisCarrinho(carrinhoDb.id!);
    }

    _logger.i("Carrinho salvo para cliente ${cliente.codcli}");
    return ApiResult.success(true);
  }

  /// Verifica se um item precisa ser atualizado
  bool _itemPrecisaAtualizacao(CarrinhoItemModel existente, CarrinhoItemModel novo) {
    return existente.quantidade != novo.quantidade ||
           (existente.descontoItem - novo.descontoItem).abs() > 0.001 ||
           (existente.precoUnitarioRegistrado - novo.precoUnitarioRegistrado).abs() > 0.001;
  }

  /// Constrói um carrinho em memória a partir dos itens do banco
  Future<Carrinho> _construirCarrinhoFromItens(List<CarrinhoItemModel> itensDb) async {
    final carrinhoItens = <ProdutoModel, int>{};
    final descontosPercentuais = <ProdutoModel, double>{};

    for (final itemDb in itensDb) {
      if (itemDb.codprd == null) {
        _logger.w("Item ${itemDb.id} sem codprd");
        continue;
      }

      final produto = await _repositoryManager.produtos.getProdutoByCodigo(itemDb.codprd!);
      
      if (produto != null) {
        carrinhoItens[produto] = itemDb.quantidade;
        
        if (itemDb.precoUnitarioRegistrado > 0) {
          double descontoPercentual = (itemDb.descontoItem / itemDb.precoUnitarioRegistrado) * 100;
          descontoPercentual = double.parse(descontoPercentual.toStringAsFixed(2));

          // Valida desconto máximo permitido
          if (produto.perdscmxm > 0 && descontoPercentual > produto.perdscmxm) {
            descontosPercentuais[produto] = produto.perdscmxm;
          } else if (descontoPercentual > 0) {
            descontosPercentuais[produto] = descontoPercentual;
          }
        }
      } else {
        _logger.w("Produto com codprd ${itemDb.codprd} não encontrado");
      }
    }

    return Carrinho(itens: carrinhoItens, descontos: descontosPercentuais);
  }
}