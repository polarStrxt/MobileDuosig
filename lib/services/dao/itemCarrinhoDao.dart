// lib/services/dao/carrinho_item_dao.dart

import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart'; // Para logging
import 'package:flutter_docig_venda/services/database_helper.dart'; // Ajuste o caminho
import 'package:flutter_docig_venda/models/carrinho_item_model.dart'; // Ajuste o caminho
// import 'package:flutter_docig_venda/widgets/dao_generico.dart'; // Se você tem um BaseDao

// Assumindo que BaseDao fornece 'Future<Database> get database'
// class CarrinhoItemDao extends BaseDao {
//   CarrinhoItemDao() : super(DatabaseHelper.tableCarrinhoItens);

// Se você não tem BaseDao ou ele não é necessário aqui:
class CarrinhoItemDao {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _database async => await _dbHelper.database;

  // Se BaseDao não exige createTable, remova este método.
  // O DatabaseHelper já cuida da criação da tabela.
  // @override
  // Future<void> createTable(Database db) async {
  //   // SQL DEVE SER IDÊNTICO AO DatabaseHelper._createCarrinhoItensTable
  //   // É melhor centralizar a criação no DatabaseHelper.
  // }

  Future<int?> salvarOuAtualizarItem(CarrinhoItemModel item) async {
    final db = await _database;
    int? itemId;

    try {
      await db.transaction((txn) async {
        List<Map<String, dynamic>> existentes = await txn.query(
          DatabaseHelper.tableCarrinhoItens,
          columns: ['id', 'quantidade'],
          where: 'id_carrinho = ? AND codprd = ?',
          whereArgs: [item.idCarrinho, item.codprd],
        );

        if (existentes.isNotEmpty) {
          itemId = existentes.first['id'] as int;
          int novaQuantidade = (existentes.first['quantidade'] as int) + item.quantidade;
          
          Map<String, dynamic> dadosUpdate = {
            'quantidade': novaQuantidade,
            'desconto_item': item.descontoItem, // Pode ser o novo desconto total da linha
            'preco_unitario_registrado': item.precoUnitarioRegistrado, // Garante que o preço registrado é o mais recente se o item for "re-adicionado"
            'data_adicao': DateTime.now().toIso8601String(),
          };

          await txn.update(
            DatabaseHelper.tableCarrinhoItens,
            dadosUpdate,
            where: 'id = ?',
            whereArgs: [itemId],
          );
          _logger.d("Item atualizado no carrinho_itens: id $itemId, nova quantidade: $novaQuantidade");
        } else {
          // Novo item para este carrinho
          Map<String, dynamic> itemJson = item.toJson();
          itemJson.remove('id'); // Garante que o ID seja nulo para autoincremento
          itemJson['data_adicao'] = DateTime.now().toIso8601String(); // Garante data atual

          itemId = await txn.insert(DatabaseHelper.tableCarrinhoItens, itemJson);
          _logger.d("Item inserido no carrinho_itens: id $itemId");
        }
      });
      return itemId;
    } catch (e, s) {
      _logger.e("Erro ao salvar/atualizar item no carrinho_itens", error: e, stackTrace: s);
      return null; // Ou lançar a exceção: throw Exception("Erro ao salvar/atualizar item: $e");
    }
  }

  Future<List<CarrinhoItemModel>> getItensPorIdCarrinho(int idCarrinho) async {
    final db = await _database;
    try {
      List<Map<String, dynamic>> resultado = await db.query(
        DatabaseHelper.tableCarrinhoItens,
        where: 'id_carrinho = ?',
        whereArgs: [idCarrinho],
        orderBy: 'data_adicao DESC',
      );
      _logger.i("Itens carregados de carrinho_itens para id_carrinho $idCarrinho: ${resultado.length} itens");
      return resultado.map((map) => CarrinhoItemModel.fromJson(map)).toList();
    } catch (e, s) {
      _logger.e("Erro ao buscar itens de carrinho_itens por id_carrinho $idCarrinho", error: e, stackTrace: s);
      return [];
    }
  }
  
  Future<CarrinhoItemModel?> getItemPorId(int itemId) async {
    final db = await _database;
    try {
      List<Map<String, dynamic>> resultado = await db.query(
        DatabaseHelper.tableCarrinhoItens,
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (resultado.isNotEmpty) {
        return CarrinhoItemModel.fromJson(resultado.first);
      }
      return null;
    } catch (e, s) {
      _logger.e("Erro ao buscar item $itemId de carrinho_itens", error: e, stackTrace: s);
      return null;
    }
  }

  Future<bool> atualizarItem(CarrinhoItemModel item) async {
    if (item.id == null) {
      _logger.w("Tentativa de atualizar item sem ID.");
      return false;
    }
    final db = await _database;
    try {
      int count = await db.update(
        DatabaseHelper.tableCarrinhoItens,
        item.toJson(), // O toJson deve conter a data_adicao atualizada se necessário
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (count > 0) {
        _logger.i("Item ${item.id} atualizado em carrinho_itens.");
        return true;
      }
      _logger.w("Nenhum item atualizado em carrinho_itens. ID: ${item.id}");
      return false;
    } catch (e, s) {
      _logger.e("Erro ao atualizar item ${item.id} em carrinho_itens", error: e, stackTrace: s);
      return false;
    }
  }


  Future<bool> removerItemPorId(int itemId) async {
    final db = await _database;
    try {
      int resultado = await db.delete(
        DatabaseHelper.tableCarrinhoItens,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      if (resultado > 0) {
        _logger.i("Item $itemId removido de carrinho_itens.");
        return true;
      }
      _logger.w("Nenhum item removido de carrinho_itens. ID: $itemId");
      return false;
    } catch (e, s) {
      _logger.e("Erro ao remover item $itemId de carrinho_itens", error: e, stackTrace: s);
      return false;
    }
  }

  // Limpa todos os itens de um carrinho específico (usado se o carrinho for cancelado, por exemplo)
  // Se o carrinho for DELETADO da tabela 'carrinhos', o ON DELETE CASCADE já faria isso.
  Future<int> limparItensDoCarrinho(int idCarrinho) async {
    final db = await _database;
    try {
      int count = await db.delete(
        DatabaseHelper.tableCarrinhoItens,
        where: 'id_carrinho = ?',
        whereArgs: [idCarrinho],
      );
      _logger.i("Removidos $count itens do carrinho $idCarrinho em carrinho_itens");
      return count;
    } catch (e, s) {
      _logger.e("Erro ao limpar itens do carrinho $idCarrinho em carrinho_itens", error: e, stackTrace: s);
      return 0;
    }
  }
}