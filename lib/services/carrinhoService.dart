// lib/services/carrinho_service.dart (Renomeie o arquivo no seu projeto)
import 'package:flutter_docig_venda/models/carrinho_model.dart';
import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart'; // Nome de arquivo corrigido
import 'package:flutter_docig_venda/services/dao/itemcarrinhoDao.dart'; // Nome de arquivo corrigido
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart'; // Corrija o caminho para sua classe Carrinho (ChangeNotifier)
import 'package:flutter_docig_venda/services/api_client.dart'; // Corrija o caminho para ApiResult
import 'package:logger/logger.dart';
// Removido: import 'package:flutter_docig_venda/services/database_helper.dart'; (não usado diretamente)
// Adicione se o ClienteRepository estiver em um arquivo separado:
import 'package:flutter_docig_venda/services/cliente_repository.dart';


class CarrinhoService {
  final CarrinhosDao _carrinhosDao;
  final CarrinhoItemDao _carrinhoItemDao;
  final ProdutoDao _produtoDao;
  final ClienteRepository _clienteRepository; // Adicionado para getClientesComCarrinhosAbertos
  final Logger _logger = Logger();

  CarrinhoService({
    CarrinhosDao? carrinhosDao,
    CarrinhoItemDao? carrinhoItemDao,
    ProdutoDao? produtoDao,
    ClienteRepository? clienteRepository, // Adicionar ao construtor
  })  : _carrinhosDao = carrinhosDao ?? CarrinhosDao(),
        _carrinhoItemDao = carrinhoItemDao ?? CarrinhoItemDao(),
        _produtoDao = produtoDao ?? ProdutoDao(),
        _clienteRepository = clienteRepository ?? ClienteRepository(); // Inicializar

  Future<ApiResult<bool>> salvarAlteracoesCarrinho(
      Carrinho carrinhoEmMemoria, Cliente cliente) async {
    try {
      if (cliente.codcli == null) {
        _logger.e("Salvar alterações: Cliente sem código (codcli).");
        return ApiResult.error("Cliente inválido.");
      }
      // Assumindo que 'codtab' em ClienteModel é 'int' (não-nulável).1
      // Se for 'int?', adicione: if (cliente.codtab == null) { return ApiResult.error("Tabela de preço não definida."); }

      CarrinhoModel? carrinhoDb =
          await _carrinhosDao.getOuCriarCarrinhoAberto(cliente.codcli!); // Usa '!'

      if (carrinhoDb == null || carrinhoDb.id == null) {
        _logger.e("Salvar alterações: Não foi possível obter/criar carrinho DB para cliente ${cliente.codcli}");
        return ApiResult.error("Falha ao acessar o carrinho no banco de dados.");
      }

      if (carrinhoEmMemoria.isEmpty) {
        await _carrinhoItemDao.limparItensDoCarrinho(carrinhoDb.id!); // Usa '!'
        _logger.i("Salvar alterações: Carrinho em memória vazio. Itens do carrinho DB ${carrinhoDb.id} limpos.");
        await _carrinhosDao.atualizarDataModificacao(carrinhoDb.id!); // Usa '!'
        return ApiResult.success(true);
      }

      bool algumaAlteracaoFeita = false;
      List<CarrinhoItemModel> itensNoBanco = await _carrinhoItemDao.getItensPorIdCarrinho(carrinhoDb.id!); // Usa '!'
      Map<int, CarrinhoItemModel> itensNoBancoMap = {
        for (var item in itensNoBanco)
          if (item.codprd != null) // Verifica se codprd do item do banco não é nulo
             item.codprd! : item  // Usa '!'
      };

      for (var entry in carrinhoEmMemoria.itens.entries) {
        ProdutoModel produto = entry.key;
        int quantidadeEmMemoria = entry.value;
        double descontoPercentualEmMemoria = carrinhoEmMemoria.descontos[produto] ?? 0.0;

        if (produto.codprd == null) {
          _logger.w("Salvar alterações: Produto ${produto.dcrprd} sem codprd.");
          continue;
        }

        double precoUnitarioRegistrado = produto.getPrecoParaTabela(cliente.codtab); // Assumindo codtab não nulo
        double valorDescontoItem = precoUnitarioRegistrado * (descontoPercentualEmMemoria / 100);

        CarrinhoItemModel itemParaSalvar = CarrinhoItemModel(
          idCarrinho: carrinhoDb.id!,
          codprd: produto.codprd!,
          quantidade: quantidadeEmMemoria,
          precoUnitarioRegistrado: precoUnitarioRegistrado,
          descontoItem: valorDescontoItem,
          dataAdicao: DateTime.now(),
        );

        CarrinhoItemModel? itemExistenteNoBanco = itensNoBancoMap[produto.codprd!];

        if (itemExistenteNoBanco != null) {
          if (itemExistenteNoBanco.quantidade != quantidadeEmMemoria ||
              ((itemExistenteNoBanco.descontoItem - valorDescontoItem).abs() > 0.001) ||
              ((itemExistenteNoBanco.precoUnitarioRegistrado - precoUnitarioRegistrado).abs() > 0.001) ) {
            itemParaSalvar.id = itemExistenteNoBanco.id;
            await _carrinhoItemDao.atualizarItem(itemParaSalvar);
            algumaAlteracaoFeita = true;
          }
        } else {
          await _carrinhoItemDao.salvarOuAtualizarItem(itemParaSalvar);
          algumaAlteracaoFeita = true;
        }
        itensNoBancoMap.remove(produto.codprd!);
      }

      for(var itemNoBancoParaRemover in itensNoBancoMap.values){
          if(itemNoBancoParaRemover.id != null){
              await _carrinhoItemDao.removerItemPorId(itemNoBancoParaRemover.id!);
              algumaAlteracaoFeita = true;
          }
      }

      if (algumaAlteracaoFeita) {
        await _carrinhosDao.atualizarDataModificacao(carrinhoDb.id!);
      }

      _logger.i("Salvar alterações: Carrinho salvo para cliente ${cliente.codcli} no carrinho DB ${carrinhoDb.id}.");
      return ApiResult.success(true);
    } catch (e, s) {
      _logger.e("Erro em salvarAlteracoesCarrinho", error: e, stackTrace: s);
      return ApiResult.error("Erro ao salvar carrinho: $e");
    }
  }

  Future<ApiResult<Carrinho>> recuperarCarrinho(Cliente cliente) async {
    try {
      if (cliente.codcli == null) {
         _logger.e("Recuperar carrinho: Cliente sem código (codcli).");
         return ApiResult.error("Cliente inválido.");
       }
      // Assumindo codtab não-nulável.

      _logger.i("Recuperando carrinho do cliente ${cliente.codcli}...");
      CarrinhoModel? carrinhoDb = await _carrinhosDao.getCarrinhoAberto(cliente.codcli!);

      if (carrinhoDb == null || carrinhoDb.id == null) {
        _logger.i("Recuperar carrinho: Nenhum carrinho aberto para cliente ${cliente.codcli}.");
        return ApiResult.success(Carrinho());
      }

      List<CarrinhoItemModel> itensDb = await _carrinhoItemDao.getItensPorIdCarrinho(carrinhoDb.id!);

      Map<ProdutoModel, int> carrinhoItensMemoria = {};
      Map<ProdutoModel, double> descontosPercentuaisMemoria = {};

      for (var itemDb in itensDb) {
         if (itemDb.codprd == null) {
             _logger.w("Recuperar carrinho: Item de carrinho ${itemDb.id} sem codprd.");
             continue;
         }
         ProdutoModel? produto = await _produtoDao.getProdutoByCodigo(itemDb.codprd!);

        if (produto != null) {
          carrinhoItensMemoria[produto] = itemDb.quantidade;
          if (itemDb.precoUnitarioRegistrado > 0) {
            double descontoPercentual = (itemDb.descontoItem / itemDb.precoUnitarioRegistrado) * 100;
            descontoPercentual = double.parse(descontoPercentual.toStringAsFixed(2));

            if (produto.perdscmxm > 0 && descontoPercentual > produto.perdscmxm) {
                descontosPercentuaisMemoria[produto] = produto.perdscmxm;
            } else if (descontoPercentual > 0){
                descontosPercentuaisMemoria[produto] = descontoPercentual;
            }
          } else if (itemDb.descontoItem != 0){
             _logger.w("Recuperar carrinho: Não foi possível calcular desconto para item ${itemDb.id}");
          }
        } else {
          _logger.w("Recuperar carrinho: Produto com codprd ${itemDb.codprd} não encontrado.");
        }
      }
      _logger.i("Recuperar carrinho: Carrinho recuperado para cliente ${cliente.codcli} com ${carrinhoItensMemoria.length} tipos.");
      return ApiResult.success(Carrinho(itens: carrinhoItensMemoria, descontos: descontosPercentuaisMemoria));
    } catch (e, s) {
      _logger.e("Erro em recuperarCarrinho", error: e, stackTrace: s);
      return ApiResult.error("Erro ao recuperar carrinho: $e");
    }
  }

  Future<ApiResult<bool>> finalizarCarrinho(Cliente cliente) async {
    try {
      if (cliente.codcli == null) {
         _logger.e("Finalizar carrinho: Cliente sem código (codcli).");
         return ApiResult.error("Cliente inválido.");
       }

      CarrinhoModel? carrinhoDb = await _carrinhosDao.getCarrinhoAberto(cliente.codcli!);

      if (carrinhoDb == null || carrinhoDb.id == null) {
        _logger.w("Finalizar carrinho: Nenhum carrinho aberto para cliente ${cliente.codcli}.");
        return ApiResult.error("Nenhum carrinho aberto para finalizar.");
      }

      List<CarrinhoItemModel> itens = await _carrinhoItemDao.getItensPorIdCarrinho(carrinhoDb.id!);
      if (itens.isEmpty) {
          _logger.i("Finalizar carrinho: Carrinho ${carrinhoDb.id} está vazio. Marcando como 'abandonado'.");
          await _carrinhosDao.atualizarStatusCarrinho(carrinhoDb.id!, 'abandonado');
          return ApiResult.success(true);
      }

      bool sucesso = await _carrinhosDao.atualizarStatusCarrinho(carrinhoDb.id!, 'finalizado');

      if (sucesso) {
        _logger.i("Finalizar carrinho: Carrinho ${carrinhoDb.id} finalizado para cliente ${cliente.codcli}.");
        return ApiResult.success(true);
      } else {
        _logger.e("Finalizar carrinho: Falha ao atualizar status do carrinho ${carrinhoDb.id}.");
        return ApiResult.error("Falha ao finalizar o carrinho no banco de dados.");
      }
    } catch (e, s) {
      _logger.e("Erro em finalizarCarrinho", error: e, stackTrace: s);
      return ApiResult.error("Erro ao finalizar carrinho: $e");
    }
  }

  Future<ApiResult<bool>> limparCarrinho(Cliente cliente) async {
    try {
      if (cliente.codcli == null) {
         _logger.e("Limpar carrinho: Cliente sem código (codcli).");
         return ApiResult.error("Cliente inválido.");
       }

      CarrinhoModel? carrinhoDb =
          await _carrinhosDao.getCarrinhoAberto(cliente.codcli!);

      if (carrinhoDb != null && carrinhoDb.id != null) {
        await _carrinhoItemDao.limparItensDoCarrinho(carrinhoDb.id!);
        await _carrinhosDao.atualizarDataModificacao(carrinhoDb.id!);
        _logger.i("Limpar carrinho: Itens do carrinho ${carrinhoDb.id} limpos para cliente ${cliente.codcli}.");
        return ApiResult.success(true);
      }
      _logger.i("Limpar carrinho: Nenhum carrinho ativo para cliente ${cliente.codcli}.");
      return ApiResult.success(true);
    } catch (e, s) {
      _logger.e("Erro em limparCarrinho", error: e, stackTrace: s);
      return ApiResult.error("Erro ao limpar carrinho: $e");
    }
  }

  Future<ApiResult<bool>> clienteTemCarrinhoPendente(Cliente cliente) async {
    try {
      if (cliente.codcli == null) {
         _logger.w("Verificar pendente: Cliente sem código (codcli).");
         return ApiResult.success(false); 
       }

      CarrinhoModel? carrinhoDb =
          await _carrinhosDao.getCarrinhoAberto(cliente.codcli!);

      if (carrinhoDb != null && carrinhoDb.id != null) {
        List<CarrinhoItemModel> itens = await _carrinhoItemDao.getItensPorIdCarrinho(carrinhoDb.id!);
        bool temItens = itens.isNotEmpty;
        _logger.i("Verificar pendente: Cliente ${cliente.codcli} tem carrinho (ID: ${carrinhoDb.id}): ${temItens ? 'Sim' : 'Não'}.");
        return ApiResult.success(temItens);
      }
      _logger.i("Verificar pendente: Cliente ${cliente.codcli} não tem carrinho.");
      return ApiResult.success(false);
    } catch (e, s) {
      _logger.e("Erro em clienteTemCarrinhoPendente", error: e, stackTrace: s);
      return ApiResult.error("Erro ao verificar carrinho: $e");
    }
  }

  Future<ApiResult<List<Cliente>>> getClientesComCarrinhosAbertos() async {
    try {
      final List<int> codigosClientesComCarrinho =
          await _carrinhosDao.getCodigosClientesComCarrinhoAberto();

      if (codigosClientesComCarrinho.isEmpty) {
        _logger.i("Nenhum cliente com carrinho aberto.");
        return ApiResult.success([]); // Usa construtor correto
      }

      // Assumindo que _clienteRepository está injetado e tem o método
      final List<Cliente> clientesFiltrados =
          await _clienteRepository.getClientesPorCodigos(codigosClientesComCarrinho);
      
      _logger.i("Retornando ${clientesFiltrados.length} clientes com carrinhos abertos.");
      return ApiResult.success(clientesFiltrados); // Usa construtor correto

    } catch (e, s) {
      _logger.e("Erro em getClientesComCarrinhosAbertos", error: e, stackTrace: s);
      return ApiResult.error("Falha ao carregar clientes com carrinho: $e");
    }
  }
}