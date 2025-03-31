import 'package:flutter_docig_venda/widgets/dao_generico.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';

class ProdutoDao extends BaseDao<Produto> {
  ProdutoDao() : super('produtos');

  @override
  Future<List<Produto>> getAll(Function fromJson) async {
    return super.getAll((json) => Produto.fromJson(json));
  }

  // Método de conveniência
  Future<List<Produto>> getAllProdutos() async {
    return getAll((json) => Produto.fromJson(json));
  }

  // Método para buscar um produto pelo código
  Future<Produto?> getProdutoByCodigo(String codigo) async {
    return getById('codprd', codigo, (json) => Produto.fromJson(json));
  }

  // Método para salvar um produto
  Future<int> save(Produto produto) async {
    return insertOrUpdate(produto.toJson(), 'codprd');
  }

  // Método para contar registros
  Future<int> count() async {
    final db = await database;
    List<Map<String, dynamic>> result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return result.first['count'] as int;
  }

  // Método para excluir todos os registros
  Future<int> deleteAll() async {
    return await clearTable();
  }
}
