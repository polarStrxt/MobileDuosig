// ===============================================
// TODOS OS REPOSITORIES EM UM ARQUIVO
// lib/data/repositories/all_repositories.dart
// ===============================================

import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/models/condicao_pagamento_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/data/models/config_dao.dart';
import 'package:flutter_docig_venda/data/models/registrar_pedido_local.dart';
import 'package:flutter_docig_venda/data/models/cliente_produto_model.dart';
import 'base_repository.dart';

// ===============================================
// 1. PRODUTO REPOSITORY
// ===============================================
class ProdutoRepository extends BaseRepository<ProdutoModel> {
  ProdutoRepository(super.dbHelper);

  @override
  String get tableName => DatabaseHelper.tableProdutos;

  @override
  Map<String, dynamic> toMap(ProdutoModel model) => model.toJson();

  @override
  ProdutoModel fromMap(Map<String, dynamic> map) => ProdutoModel.fromJson(map);

  // Métodos específicos do ProdutoDAO mantidos e aprimorados
  Future<ProdutoModel?> getProdutoByCodigo(int codigo) async {
    try {
      final results = await getWhere(
        where: 'codprd = ?',
        whereArgs: [codigo],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar produto por código $codigo", error: e);
      return null;
    }
  }

  Future<List<ProdutoModel>> searchByDescricao(String termo) async {
    if (termo.trim().isEmpty) return [];
    
    try {
      return await getWhere(
        where: 'dcrprd LIKE ? OR nommrc LIKE ?',
        whereArgs: ['%$termo%', '%$termo%'],
        orderBy: 'dcrprd ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar produtos por descrição", error: e);
      return [];
    }
  }

  Future<List<ProdutoModel>> getProdutosAtivos() async {
    try {
      return await getWhere(
        where: 'staati = ?',
        whereArgs: ['S'],
        orderBy: 'dcrprd ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar produtos ativos", error: e);
      return [];
    }
  }

  Future<List<ProdutoModel>> getProdutosPorTabela(int tabela) async {
    try {
      String whereClause = 'staati = ?';
      List<dynamic> whereArgs = ['S'];
      
      if (tabela == 1) {
        whereClause += ' AND vlrtab1 > 0';
      } else if (tabela == 2) {
        whereClause += ' AND vlrtab2 > 0';
      }
      
      return await getWhere(
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'dcrprd ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar produtos por tabela $tabela", error: e);
      return [];
    }
  }

  Future<List<ProdutoModel>> getProdutosComEstoque() async {
    try {
      return await getWhere(
        where: 'staati = ? AND qtdetq > 0',
        whereArgs: ['S'],
        orderBy: 'dcrprd ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar produtos com estoque", error: e);
      return [];
    }
  }

  Future<int> getCountProdutosAtivos() async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE staati = ?',
        ['S'],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      logger.e("Erro ao contar produtos ativos", error: e);
      return 0;
    }
  }

  /// Inserir produtos da API em lote - com tratamento robusto
  Future<int> inserirProdutosDaAPI(List<Map<String, dynamic>> produtos) async {
    if (produtos.isEmpty) return 0;
    
    final db = await dbHelper.database;
    int inseridos = 0;
    
    try {
      await db.transaction((txn) async {
        // Limpa tabela existente
        await txn.delete(tableName);
        
        for (final produtoData in produtos) {
          try {
            // Usa fromJson para parsing robusto, depois converte para json
            final produto = ProdutoModel.fromJson(produtoData);
            await txn.insert(tableName, produto.toJson());
            inseridos++;
          } catch (e) {
            logger.w("Erro ao inserir produto ${produtoData['codprd']}: $e");
          }
        }
      });
      
      logger.i("Produtos da API inseridos: $inseridos de ${produtos.length}");
      return inseridos;
    } catch (e) {
      logger.e("Erro ao inserir produtos da API", error: e);
      return 0;
    }
  }
}

// ===============================================
// 2. CLIENTE REPOSITORY
// ===============================================
class ClienteRepository extends BaseRepository<Cliente> {
  ClienteRepository(super.dbHelper);

  @override
  String get tableName => DatabaseHelper.tableClientes;

  @override
  Map<String, dynamic> toMap(Cliente model) => model.toJson();

  @override
  Cliente fromMap(Map<String, dynamic> map) => Cliente.fromJson(map);

  Future<Cliente?> getClienteByCodigo(int codigo) async {
    try {
      final results = await getWhere(
        where: 'codcli = ?',
        whereArgs: [codigo],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar cliente por código $codigo", error: e);
      return null;
    }
  }

  Future<Cliente?> getClienteByCpfCnpj(String cpfCnpj) async {
    if (cpfCnpj.trim().isEmpty) return null;
    
    try {
      final results = await getWhere(
        where: 'cgccpfcli = ?',
        whereArgs: [cpfCnpj.trim()],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar cliente por CPF/CNPJ", error: e);
      return null;
    }
  }

  Future<List<Cliente>> searchByNome(String nome) async {
    if (nome.trim().isEmpty) return [];
    
    try {
      return await getWhere(
        where: 'nomcli LIKE ?',
        whereArgs: ['%${nome.trim()}%'],
        orderBy: 'nomcli ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar clientes por nome", error: e);
      return [];
    }
  }

  Future<List<Cliente>> getClientesAtivos() async {
    try {
      return await getWhere(
        where: 'staati = ?',
        whereArgs: ['A'],
        orderBy: 'nomcli ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar clientes ativos", error: e);
      return [];
    }
  }

  /// Inserir clientes da API em lote
  Future<int> inserirClientesDaAPI(List<Map<String, dynamic>> clientes) async {
    if (clientes.isEmpty) return 0;
    
    final db = await dbHelper.database;
    int inseridos = 0;
    
    try {
      await db.transaction((txn) async {
        await txn.delete(tableName);
        
        for (final clienteData in clientes) {
          try {
            await txn.insert(tableName, clienteData);
            inseridos++;
          } catch (e) {
            logger.w("Erro ao inserir cliente ${clienteData['codcli']}: $e");
          }
        }
      });
      
      logger.i("Clientes da API inseridos: $inseridos de ${clientes.length}");
      return inseridos;
    } catch (e) {
      logger.e("Erro ao inserir clientes da API", error: e);
      return 0;
    }
  }
}

// ===============================================
// 3. DUPLICATA REPOSITORY
// ===============================================
class DuplicataRepository extends BaseRepository<Duplicata> {
  DuplicataRepository(super.dbHelper);

  @override
  String get tableName => DatabaseHelper.tableDuplicata;

  @override
  Map<String, dynamic> toMap(Duplicata model) => model.toJson();

  @override
  Duplicata fromMap(Map<String, dynamic> map) => Duplicata.fromJson(map);

  Future<Duplicata?> getDuplicataByNumero(String numdoc) async {
    if (numdoc.trim().isEmpty) return null;
    
    try {
      final results = await getWhere(
        where: 'numdoc = ?',
        whereArgs: [numdoc.trim()],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar duplicata por número", error: e);
      return null;
    }
  }

  Future<List<Duplicata>> getDuplicatasByCliente(int codcli) async {
    try {
      return await getWhere(
        where: 'codcli = ?',
        whereArgs: [codcli],
        orderBy: 'dtavct ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar duplicatas do cliente $codcli", error: e);
      return [];
    }
  }

  Future<List<Duplicata>> getDuplicatasVencidas() async {
    try {
      final hoje = DateTime.now().toIso8601String().split('T')[0];
      return await getWhere(
        where: 'dtavct < ?',
        whereArgs: [hoje],
        orderBy: 'dtavct ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar duplicatas vencidas", error: e);
      return [];
    }
  }

  Future<List<Duplicata>> getDuplicatasPorVencer(int dias) async {
    try {
      final dataLimite = DateTime.now().add(Duration(days: dias));
      final hoje = DateTime.now().toIso8601String().split('T')[0];
      final limite = dataLimite.toIso8601String().split('T')[0];
      
      return await getWhere(
        where: 'dtavct >= ? AND dtavct <= ?',
        whereArgs: [hoje, limite],
        orderBy: 'dtavct ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar duplicatas por vencer", error: e);
      return [];
    }
  }

  /// Inserir duplicatas da API em lote
  Future<int> inserirDuplicatasDaAPI(List<Map<String, dynamic>> duplicatas) async {
    if (duplicatas.isEmpty) return 0;
    
    final db = await dbHelper.database;
    int inseridos = 0;
    
    try {
      await db.transaction((txn) async {
        await txn.delete(tableName);
        
        for (final duplicataData in duplicatas) {
          try {
            await txn.insert(tableName, duplicataData);
            inseridos++;
          } catch (e) {
            logger.w("Erro ao inserir duplicata ${duplicataData['numdoc']}: $e");
          }
        }
      });
      
      logger.i("Duplicatas da API inseridas: $inseridos de ${duplicatas.length}");
      return inseridos;
    } catch (e) {
      logger.e("Erro ao inserir duplicatas da API", error: e);
      return 0;
    }
  }
}

// ===============================================
// 4. CARRINHO REPOSITORY
// ===============================================
class CarrinhoRepository extends BaseRepository<CarrinhoModel> {
  CarrinhoRepository(super.dbHelper);
  final Logger _logger = Logger();

  @override
  String get tableName => DatabaseHelper.tableCarrinhos;

  @override
  Map<String, dynamic> toMap(CarrinhoModel model) => model.toJson();

  @override
  CarrinhoModel fromMap(Map<String, dynamic> map) => CarrinhoModel.fromJson(map);

  Future<CarrinhoModel?> getOuCriarCarrinhoAberto(int codcli) async {
    try {
      // Primeiro tenta buscar carrinho aberto existente
      CarrinhoModel? carrinho = await getCarrinhoAberto(codcli);
      
      if (carrinho != null) {
        _logger.i("Carrinho aberto encontrado para cliente $codcli: id ${carrinho.id}");
        return carrinho;
      }
      
      // Se não existe, cria um novo
      DateTime agora = DateTime.now();
      CarrinhoModel novoCarrinho = CarrinhoModel(
        codcli: codcli,
        dataCriacao: agora,
        dataUltimaModificacao: agora,
        status: 'aberto',
      );
      
      final db = await dbHelper.database;
      int idNovoCarrinho = await db.insert(tableName, novoCarrinho.toJson());
      
      if (idNovoCarrinho > 0) {
        // Busca o carrinho recém-criado
        final results = await getWhere(
          where: 'id = ?',
          whereArgs: [idNovoCarrinho],
          limit: 1,
        );
        
        if (results.isNotEmpty) {
          carrinho = results.first;
          _logger.d("Novo carrinho criado para cliente $codcli: id ${carrinho.id}");
          return carrinho;
        }
      }
      
      return null;
    } catch (e, s) {
      _logger.e("Erro ao obter/criar carrinho para cliente $codcli", error: e, stackTrace: s);
      return null;
    }
  }

  Future<CarrinhoModel?> getCarrinhoAberto(int codcli) async {
    try {
      final results = await getWhere(
        where: 'codcli = ? AND status = ?',
        whereArgs: [codcli, 'aberto'],
        limit: 1,
        orderBy: 'data_ultima_modificacao DESC',
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e("Erro ao buscar carrinho aberto do cliente $codcli", error: e);
      return null;
    }
  }

  Future<bool> atualizarStatusCarrinho(int idCarrinho, String novoStatus) async {
    try {
      final db = await dbHelper.database;
      int count = await db.update(
        tableName,
        {
          'status': novoStatus,
          'data_ultima_modificacao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
      
      if (count > 0) {
        _logger.i("Status do carrinho $idCarrinho atualizado para '$novoStatus'.");
        return true;
      }
      return false;
    } catch (e, s) {
      _logger.e("Erro ao atualizar status do carrinho $idCarrinho", error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> atualizarTotaisCarrinho(
    int idCarrinho, {
    double? bruto,
    double? descontos,
    double? liquido,
  }) async {
    try {
      final db = await dbHelper.database;
      Map<String, dynamic> dataToUpdate = {
        'data_ultima_modificacao': DateTime.now().toIso8601String(),
      };
      
      if (bruto != null) dataToUpdate['valor_total_bruto'] = bruto;
      if (descontos != null) dataToUpdate['valor_total_descontos'] = descontos;
      if (liquido != null) dataToUpdate['valor_total_liquido'] = liquido;

      int count = await db.update(
        tableName,
        dataToUpdate,
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
      return count > 0;
    } catch (e, s) {
      _logger.e("Erro ao atualizar totais do carrinho $idCarrinho", error: e, stackTrace: s);
      return false;
    }
  }

  Future<List<int>> getCodigosClientesComCarrinhoAberto() async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        distinct: true,
        columns: ['codcli'],
        where: 'status = ?',
        whereArgs: ['aberto'],
      );
      
      List<int> codigos = maps.map((map) => map['codcli'] as int).toList();
      _logger.d("Códigos de clientes com carrinho aberto: $codigos");
      return codigos;
    } catch (e) {
      _logger.e("Erro ao buscar clientes com carrinho aberto", error: e);
      return [];
    }
  }
}

// ===============================================
// 5. CARRINHO ITEM REPOSITORY
// ===============================================
class CarrinhoItemRepository extends BaseRepository<CarrinhoItemModel> {
  CarrinhoItemRepository(super.dbHelper);
  final Logger _logger = Logger();

  @override
  String get tableName => DatabaseHelper.tableCarrinhoItens;

  @override
  Map<String, dynamic> toMap(CarrinhoItemModel model) => model.toJson();

  @override
  CarrinhoItemModel fromMap(Map<String, dynamic> map) => CarrinhoItemModel.fromJson(map);

  Future<int?> salvarOuAtualizarItem(CarrinhoItemModel item) async {
    try {
      final db = await dbHelper.database;
      int? itemId;

      await db.transaction((txn) async {
        List<Map<String, dynamic>> existentes = await txn.query(
          tableName,
          columns: ['id', 'quantidade'],
          where: 'id_carrinho = ? AND codprd = ?',
          whereArgs: [item.idCarrinho, item.codprd],
        );

        if (existentes.isNotEmpty) {
          itemId = existentes.first['id'] as int;
          int novaQuantidade = (existentes.first['quantidade'] as int) + item.quantidade;
          
          await txn.update(
            tableName,
            {
              'quantidade': novaQuantidade,
              'desconto_item': item.descontoItem,
              'preco_unitario_registrado': item.precoUnitarioRegistrado,
              'data_adicao': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
          _logger.d("Item atualizado: id $itemId, nova quantidade: $novaQuantidade");
        } else {
          Map<String, dynamic> itemJson = item.toJson();
          itemJson.remove('id');
          itemJson['data_adicao'] = DateTime.now().toIso8601String();

          itemId = await txn.insert(tableName, itemJson);
          _logger.d("Item inserido: id $itemId");
        }
      });
      return itemId;
    } catch (e, s) {
      _logger.e("Erro ao salvar/atualizar item", error: e, stackTrace: s);
      return null;
    }
  }

  Future<List<CarrinhoItemModel>> getItensPorIdCarrinho(int idCarrinho) async {
    try {
      return await getWhere(
        where: 'id_carrinho = ?',
        whereArgs: [idCarrinho],
        orderBy: 'data_adicao DESC',
      );
    } catch (e) {
      _logger.e("Erro ao buscar itens do carrinho $idCarrinho", error: e);
      return [];
    }
  }

  Future<bool> removerItemPorId(int itemId) async {
    try {
      final db = await dbHelper.database;
      int resultado = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      
      _logger.d("Item $itemId removido: ${resultado > 0 ? 'sucesso' : 'falhou'}");
      return resultado > 0;
    } catch (e, s) {
      _logger.e("Erro ao remover item $itemId", error: e, stackTrace: s);
      return false;
    }
  }

  Future<int> limparItensDoCarrinho(int idCarrinho) async {
    try {
      final db = await dbHelper.database;
      final count = await db.delete(
        tableName,
        where: 'id_carrinho = ?',
        whereArgs: [idCarrinho],
      );
      
      _logger.d("$count itens removidos do carrinho $idCarrinho");
      return count;
    } catch (e) {
      _logger.e("Erro ao limpar itens do carrinho $idCarrinho", error: e);
      return 0;
    }
  }
}

// ===============================================
// 6. CONFIG REPOSITORY
// ===============================================
class ConfigRepository extends BaseRepository<Config> {
  ConfigRepository(super.dbHelper);

  @override
  String get tableName => DatabaseHelper.tableConfig;

  @override
  Map<String, dynamic> toMap(Config model) => model.toMap();

  @override
  Config fromMap(Map<String, dynamic> map) => Config.fromMap(map);

  Future<Config?> getConfig() async {
    try {
      final results = await getAll();
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar configuração", error: e);
      return null;
    }
  }

  Future<bool> saveConfig(Config config) async {
    try {
      // Remove todas as configs antigas
      await deleteAll();
      // Insere a nova
      final id = await upsert(config);
      return id > 0;
    } catch (e) {
      logger.e("Erro ao salvar configuração", error: e);
      return false;
    }
  }
}

// ===============================================
// 7. CONDIÇÃO PAGAMENTO REPOSITORY
// ===============================================
class CondicaoPagamentoRepository extends BaseRepository<CondicaoPagamentoModel> {
  CondicaoPagamentoRepository(super.dbHelper);

  @override
  String get tableName => DatabaseHelper.tableCondicaoPagamento;

  @override
  Map<String, dynamic> toMap(CondicaoPagamentoModel model) {
    return {
      'codcndpgt': model.codcndpgt,
      'dcrcndpgt': model.dcrcndpgt,
      'perdsccel': model.perdsccel,
      'staati': model.staati,
    };
  }

  @override
  CondicaoPagamentoModel fromMap(Map<String, dynamic> map) => 
      CondicaoPagamentoModel.fromJson(map);

  Future<CondicaoPagamentoModel?> getCondicaoById(int codcndpgt) async {
    try {
      final results = await getWhere(
        where: 'codcndpgt = ?',
        whereArgs: [codcndpgt],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      logger.e("Erro ao buscar condição de pagamento $codcndpgt", error: e);
      return null;
    }
  }

  Future<List<CondicaoPagamentoModel>> getCondicoesAtivas() async {
    try {
      return await getWhere(
        where: 'staati = ?',
        whereArgs: ['A'],
        orderBy: 'dcrcndpgt ASC',
      );
    } catch (e) {
      logger.e("Erro ao buscar condições de pagamento ativas", error: e);
      return [];
    }
  }
}

// ===============================================
// 8. CLIENTE-PRODUTO REPOSITORY
// ===============================================
class ClienteProdutoRepository extends BaseRepository<ClienteProdutoModel> {
  ClienteProdutoRepository(super.dbHelper);
  final Logger _logger = Logger();

  @override
  String get tableName => DatabaseHelper.tableClienteProduto;

  @override
  Map<String, dynamic> toMap(ClienteProdutoModel model) => model.toJson();

  @override
  ClienteProdutoModel fromMap(Map<String, dynamic> map) => ClienteProdutoModel.fromJson(map);

  /// Obtém todos os produtos específicos de um cliente
  Future<List<ProdutoModel>> getProdutosPorCliente(int codcli) async {
    try {
      final db = await dbHelper.database;
      
      // Query com JOIN para buscar produtos relacionados ao cliente
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT p.* 
        FROM ${DatabaseHelper.tableProdutos} p
        INNER JOIN $tableName cp ON p.codprd = cp.codprd
        WHERE cp.codcli = ? AND p.staati = 'A'
        ORDER BY p.dcrprd ASC
      ''', [codcli]);

      final produtos = maps.map((map) => ProdutoModel.fromJson(map)).toList();
      
      _logger.i("Cliente $codcli possui ${produtos.length} produtos específicos");
      return produtos;
    } catch (e, s) {
      _logger.e("Erro ao buscar produtos do cliente $codcli", error: e, stackTrace: s);
      return [];
    }
  }

  /// Verifica se um cliente tem produtos específicos cadastrados
  Future<bool> clienteTemProdutosEspecificos(int codcli) async {
    try {
      final db = await dbHelper.database;
      
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM $tableName WHERE codcli = ?
      ''', [codcli]);
      
      final count = Sqflite.firstIntValue(result) ?? 0;
      final temProdutos = count > 0;
      
      _logger.d("Cliente $codcli ${temProdutos ? 'tem' : 'não tem'} produtos específicos ($count)");
      return temProdutos;
    } catch (e) {
      _logger.e("Erro ao verificar produtos específicos do cliente $codcli", error: e);
      return false;
    }
  }

  /// Obtém todas as relações cliente-produto de um cliente
  Future<List<ClienteProdutoModel>> getRelacoesPorCliente(int codcli) async {
    try {
      return await getWhere(
        where: 'codcli = ?',
        whereArgs: [codcli],
      );
    } catch (e) {
      _logger.e("Erro ao buscar relações do cliente $codcli", error: e);
      return [];
    }
  }

  /// Obtém todos os clientes que podem comprar um produto específico
  Future<List<int>> getClientesPorProduto(int codprd) async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        tableName,
        columns: ['codcli'],
        where: 'codprd = ?',
        whereArgs: [codprd],
        distinct: true,
      );
      
      return maps.map((map) => map['codcli'] as int).toList();
    } catch (e) {
      _logger.e("Erro ao buscar clientes do produto $codprd", error: e);
      return [];
    }
  }

  /// Adiciona uma relação cliente-produto
  Future<bool> adicionarRelacao(int codcli, int codprd) async {
    try {
      final relacao = ClienteProdutoModel(
        codcli: codcli,
        codprd: codprd,
      );
      
      final db = await dbHelper.database;
      await db.insert(tableName, relacao.toJson());
      _logger.i("Relação cliente-produto adicionada: Cliente $codcli, Produto $codprd");
      return true;
    } catch (e, s) {
      _logger.e("Erro ao adicionar relação", error: e, stackTrace: s);
      return false;
    }
  }

  /// Remove uma relação cliente-produto específica
  Future<bool> removerRelacao(int codcli, int codprd) async {
    try {
      final db = await dbHelper.database;
      
      final count = await db.delete(
        tableName,
        where: 'codcli = ? AND codprd = ?',
        whereArgs: [codcli, codprd],
      );
      
      _logger.i("Relação removida: Cliente $codcli, Produto $codprd");
      return count > 0;
    } catch (e) {
      _logger.e("Erro ao remover relação cliente-produto", error: e);
      return false;
    }
  }

  /// Remove todas as relações de um cliente
  Future<int> removerTodasRelacoesCliente(int codcli) async {
    try {
      final db = await dbHelper.database;
      
      final count = await db.delete(
        tableName,
        where: 'codcli = ?',
        whereArgs: [codcli],
      );
      
      _logger.i("$count relações removidas para cliente $codcli");
      return count;
    } catch (e) {
      _logger.e("Erro ao remover relações do cliente $codcli", error: e);
      return 0;
    }
  }

  /// Sincroniza produtos específicos de um cliente (substitui todas as relações)
  Future<bool> sincronizarProdutosCliente(int codcli, List<int> codigosProdutos) async {
    try {
      final db = await dbHelper.database;
      
      await db.transaction((txn) async {
        // Remove todas as relações existentes do cliente
        await txn.delete(tableName, where: 'codcli = ?', whereArgs: [codcli]);
        
        // Insere as novas relações
        for (final codprd in codigosProdutos) {
          await txn.insert(tableName, {
            'codcli': codcli,
            'codprd': codprd,
          });
        }
      });
      
      _logger.i("${codigosProdutos.length} produtos sincronizados para cliente $codcli");
      return true;
    } catch (e, s) {
      _logger.e("Erro ao sincronizar produtos do cliente $codcli", error: e, stackTrace: s);
      return false;
    }
  }
}

// ===============================================
// 9. PEDIDOS PARA ENVIO REPOSITORY
// ===============================================
class PedidosParaEnvioRepository extends BaseRepository<RegistroPedidoLocal> {
  PedidosParaEnvioRepository(super.dbHelper);
  final Logger _logger = Logger();

  @override
  String get tableName => DatabaseHelper.tablePedidosParaEnvio;

  @override
  Map<String, dynamic> toMap(RegistroPedidoLocal model) {
    Map<String, dynamic> map = model.toMap();
    if (model.idPedidoLocal == null) {
      map.remove('id_pedido_local');
    }
    return map;
  }

  @override
  RegistroPedidoLocal fromMap(Map<String, dynamic> map) => 
      RegistroPedidoLocal.fromMap(map);

  Future<List<RegistroPedidoLocal>> getPendentesParaEnvio() async {
    try {
      return await getWhere(
        where: 'status_envio = ?',
        whereArgs: ['PENDENTE'],
        orderBy: 'data_criacao ASC',
      );
    } catch (e) {
      _logger.e("Erro ao buscar pedidos pendentes", error: e);
      return [];
    }
  }

  Future<int> getPendentesCount() async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE status_envio = ?',
        ['PENDENTE'],
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      _logger.d("Pedidos pendentes para envio: $count");
      return count;
    } catch (e) {
      _logger.e("Erro ao contar pedidos pendentes", error: e);
      return 0;
    }
  }

  Future<bool> atualizarStatus(int idPedidoLocal, String novoStatus) async {
    try {
      final db = await dbHelper.database;
      final count = await db.update(
        tableName,
        {
          'status_envio': novoStatus,
          'data_ultima_tentativa': DateTime.now().toIso8601String(),
        },
        where: 'id_pedido_local = ?',
        whereArgs: [idPedidoLocal],
      );
      
      _logger.i("Status do pedido local ID $idPedidoLocal atualizado para $novoStatus");
      return count > 0;
    } catch (e) {
      _logger.e("Erro ao atualizar status do pedido $idPedidoLocal", error: e);
      return false;
    }
  }

  Future<RegistroPedidoLocal?> getPedidoPorCodigoApp(String codigoApp) async {
    try {
      final results = await getWhere(
        where: 'codigo_pedido_app = ?',
        whereArgs: [codigoApp],
        limit: 1,
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      _logger.e("Erro ao buscar pedido por código $codigoApp", error: e);
      return null;
    }
  }

  Future<int> deletePedidoPorId(int idPedidoLocal) async {
    try {
      final db = await dbHelper.database;
      final count = await db.delete(
        tableName,
        where: 'id_pedido_local = ?',
        whereArgs: [idPedidoLocal],
      );
      
      _logger.i("Pedido local ID $idPedidoLocal deletado");
      return count;
    } catch (e) {
      _logger.e("Erro ao deletar pedido $idPedidoLocal", error: e);
      return 0;
    }
  }

  Future<int> deletePedidosComStatus(String status) async {
    try {
      final db = await dbHelper.database;
      final count = await db.delete(
        tableName,
        where: 'status_envio = ?',
        whereArgs: [status],
      );
      
      _logger.i("$count pedidos com status '$status' deletados");
      return count;
    } catch (e) {
      _logger.e("Erro ao deletar pedidos com status $status", error: e);
      return 0;
    }
  }

  /// Incrementa tentativas de envio
  Future<bool> incrementarTentativas(int idPedidoLocal) async {
    try {
      final db = await dbHelper.database;
      final count = await db.rawUpdate('''
        UPDATE $tableName 
        SET tentativas = tentativas + 1,
            data_ultima_tentativa = ?
        WHERE id_pedido_local = ?
      ''', [DateTime.now().toIso8601String(), idPedidoLocal]);
      
      return count > 0;
    } catch (e) {
      _logger.e("Erro ao incrementar tentativas do pedido $idPedidoLocal", error: e);
      return false;
    }
  }

  /// Atualiza erro de envio
  Future<bool> atualizarErro(int idPedidoLocal, String mensagemErro) async {
    try {
      final db = await dbHelper.database;
      final count = await db.update(
        tableName,
        {
          'erro_mensagem': mensagemErro,
          'status_envio': 'ERRO',
          'data_ultima_tentativa': DateTime.now().toIso8601String(),
        },
        where: 'id_pedido_local = ?',
        whereArgs: [idPedidoLocal],
      );
      
      return count > 0;
    } catch (e) {
      _logger.e("Erro ao atualizar erro do pedido $idPedidoLocal", error: e);
      return false;
    }
  }
}

// ===============================================
// 10. REPOSITORY MANAGER (GERENCIADOR CENTRAL)
// ===============================================
class RepositoryManager {
  final DatabaseHelper dbHelper;
  final Logger _logger = Logger();
  
  late final ProdutoRepository produtos;
  late final ClienteRepository clientes;
  late final DuplicataRepository duplicatas;
  late final CarrinhoRepository carrinhos;
  late final CarrinhoItemRepository carrinhoItens;
  late final ConfigRepository config;
  late final CondicaoPagamentoRepository condicoesPagamento;
  late final PedidosParaEnvioRepository pedidosParaEnvio;
  late final ClienteProdutoRepository clienteProduto;

  RepositoryManager(this.dbHelper) {
    _initializeRepositories();
  }

  void _initializeRepositories() {
    try {
      produtos = ProdutoRepository(dbHelper);
      clientes = ClienteRepository(dbHelper);
      duplicatas = DuplicataRepository(dbHelper);
      carrinhos = CarrinhoRepository(dbHelper);
      carrinhoItens = CarrinhoItemRepository(dbHelper);
      config = ConfigRepository(dbHelper);
      condicoesPagamento = CondicaoPagamentoRepository(dbHelper);
      pedidosParaEnvio = PedidosParaEnvioRepository(dbHelper);
      clienteProduto = ClienteProdutoRepository(dbHelper);
      
      _logger.i("RepositoryManager inicializado com todos os repositórios");
    } catch (e, s) {
      _logger.e("Erro ao inicializar RepositoryManager", error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Método para sincronização completa de dados da API
  Future<Map<String, int>> sincronizarDadosAPI({
    List<Map<String, dynamic>>? produtos,
    List<Map<String, dynamic>>? clientes,
    List<Map<String, dynamic>>? duplicatas,
  }) async {
    final Map<String, int> resultados = {
      'produtos': 0,
      'clientes': 0,
      'duplicatas': 0,
    };

    try {
      if (produtos != null && produtos.isNotEmpty) {
        resultados['produtos'] = await this.produtos.inserirProdutosDaAPI(produtos);
      }

      if (clientes != null && clientes.isNotEmpty) {
        resultados['clientes'] = await this.clientes.inserirClientesDaAPI(clientes);
      }

      if (duplicatas != null && duplicatas.isNotEmpty) {
        resultados['duplicatas'] = await this.duplicatas.inserirDuplicatasDaAPI(duplicatas);
      }

      _logger.i("Sincronização concluída: $resultados");
    } catch (e, s) {
      _logger.e("Erro na sincronização de dados da API", error: e, stackTrace: s);
    }

    return resultados;
  }

  /// Status geral do banco de dados
  Future<Map<String, dynamic>> getStatusBanco() async {
    try {
      final db = await dbHelper.database;
      
      final produtos = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableProdutos}');
      final clientes = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableClientes}');
      final duplicatas = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableDuplicata}');
      final carrinhos = await db.rawQuery('SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCarrinhos}');
      final pedidosPendentes = await pedidosParaEnvio.getPendentesCount();

      return {
        'produtos': Sqflite.firstIntValue(produtos) ?? 0,
        'clientes': Sqflite.firstIntValue(clientes) ?? 0,
        'duplicatas': Sqflite.firstIntValue(duplicatas) ?? 0,
        'carrinhos_abertos': (await this.carrinhos.getCodigosClientesComCarrinhoAberto()).length,
        'pedidos_pendentes': pedidosPendentes,
        'database_name': "docig_venda.db",
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logger.e("Erro ao obter status do banco", error: e);
      return {};
    }
  }

  /// Limpa todos os dados (exceto configurações)
  Future<bool> limparTodosDados() async {
    try {
      final db = await dbHelper.database;
      
      await db.transaction((txn) async {
        await txn.delete(DatabaseHelper.tableProdutos);
        await txn.delete(DatabaseHelper.tableClientes);
        await txn.delete(DatabaseHelper.tableDuplicata);
        await txn.delete(DatabaseHelper.tableCarrinhos);
        await txn.delete(DatabaseHelper.tableCarrinhoItens);
        await txn.delete(DatabaseHelper.tablePedidosParaEnvio);
        await txn.delete(DatabaseHelper.tableClienteProduto);
        // Não limpa a tabela de configurações
      });
      
      _logger.i("Todos os dados limpos (exceto configurações)");
      return true;
    } catch (e, s) {
      _logger.e("Erro ao limpar dados", error: e, stackTrace: s);
      return false;
    }
  }

  /// Dispose de recursos se necessário
  void dispose() {
    _logger.d("RepositoryManager disposed");
  }
}