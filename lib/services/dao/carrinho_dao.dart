import 'package:flutter_docig_venda/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/widgets/dao_generico.dart';
import 'package:sqflite/sqflite.dart';

class CarrinhoDao extends BaseDao {
  CarrinhoDao() : super('carrinho_itens');

  @override
  String get tableName => 'carrinho_itens';

  @override
  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codprd INTEGER NOT NULL,
        codcli INTEGER NOT NULL,
        quantidade INTEGER NOT NULL CHECK (quantidade > 0),
        desconto REAL NOT NULL CHECK (desconto >= 0),
        finalizado INTEGER NOT NULL DEFAULT 0,
        data_criacao TEXT NOT NULL
      )
    ''');
  }

  Future<int> salvarItem(CarrinhoItem item) async {
    final db = await database;
    return await db.transaction((txn) async {
      try {
        List<Map<String, dynamic>> existentes = await txn.query(
          tableName,
          where: 'codprd = ? AND codcli = ? AND finalizado = 0',
          whereArgs: [item.codprd, item.codcli],
        );

        if (existentes.isNotEmpty) {
          item.id = existentes.first['id'];
          int novaQuantidade = existentes.first['quantidade'] +
              item.quantidade; // Somar quantidade
          await txn.update(
            tableName,
            {
              'quantidade': novaQuantidade,
              'desconto': item.desconto,
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
          return item.id!;
        } else {
          return await txn.insert(tableName, item.toJson());
        }
      } catch (e) {
        print("\u274c Erro ao salvar item no carrinho: $e");
        throw Exception("Erro ao salvar item no carrinho: $e");
      }
    });
  }

  Future<List<CarrinhoItem>> getItensCliente(int codcli,
      {bool apenasNaoFinalizados = true}) async {
    final db = await database;
    try {
      String whereClause =
          apenasNaoFinalizados ? 'codcli = ? AND finalizado = 0' : 'codcli = ?';

      List<Map<String, dynamic>> resultado = await db.query(
        tableName,
        where: whereClause,
        whereArgs: [codcli],
        orderBy: 'data_criacao DESC',
      );

      print("\u2705 Itens carregados do banco: $resultado"); // Log para debug
      return resultado.map((map) => CarrinhoItem.fromJson(map)).toList();
    } catch (e) {
      print("\u274c Erro ao buscar itens do carrinho: $e");
      return [];
    }
  }

  Future<void> finalizarCarrinho(int codcli) async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.update(
          tableName,
          {'finalizado': 1},
          where: 'codcli = ? AND finalizado = 0',
          whereArgs: [codcli],
        );
      });
    } catch (e) {
      print("\u274c Erro ao finalizar carrinho: $e");
    }
  }

  Future<bool> removerItem(int codprd, int codcli) async {
    final db = await database;
    try {
      int resultado = await db.delete(
        tableName,
        where: 'codprd = ? AND codcli = ? AND finalizado = 0',
        whereArgs: [codprd, codcli],
      );
      return resultado > 0;
    } catch (e) {
      print("\u274c Erro ao remover item do carrinho: $e");
      return false;
    }
  }

  Future<bool> limparCarrinho(int codcli) async {
    final db = await database;
    try {
      int resultado = await db.transaction((txn) async {
        return await txn.delete(
          tableName,
          where: 'codcli = ? AND finalizado = 0',
          whereArgs: [codcli],
        );
      });
      return resultado > 0;
    } catch (e) {
      print("\u274c Erro ao limpar carrinho: $e");
      return false;
    }
  }

  Future<void> printCarrinho() async {
    final db = await database;
    final List<Map<String, dynamic>> items = await db.query('carrinho_itens');
    print('\u2705 Itens no carrinho: $items');
  }
}
