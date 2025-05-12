import 'package:flutter_docig_venda/widgets/dao_generico.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';

class ProdutoDao extends BaseDao<ProdutoModel> {
  ProdutoDao() : super('produtos');

  @override
  Future<List<ProdutoModel>> getAll(Function fromJson) async {
    try {
      return await super.getAll((json) => ProdutoModel.fromJson(json));
    } catch (e) {
      print("❌ Erro ao buscar todos os produtos: $e");
      return [];
    }
  }

  // Buscar todos os produtos
  Future<List<ProdutoModel>> getAllProdutos() async {
    return await getAll((json) => ProdutoModel.fromJson(json));
  }

  // Buscar um produto pelo código
  Future<ProdutoModel?> getProdutoByCodigo(int codigo) async {
    try {
      return await getById('codprd', codigo, (json) => ProdutoModel.fromJson(json));
    } catch (e) {
      print("❌ Erro ao buscar produto pelo código ($codigo): $e");
      return null;
    }
  }

  // Salvar ou atualizar um produto
  Future<int> save(ProdutoModel produto) async {
    try {
      return await insertOrUpdate(produto.toJson(), 'codprd');
    } catch (e) {
      print("❌ Erro ao salvar o produto: $e");
      return -1; // Retorna -1 para indicar falha
    }
  }

  // Contar número de produtos
  Future<int> count() async {
    try {
      final db = await database;
      List<Map<String, dynamic>> result =
          await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      return (result.first['count'] ?? 0) as int;
    } catch (e) {
      print("❌ Erro ao contar produtos: $e");
      return 0;
    }
  }

  // Excluir todos os produtos
  Future<int> deleteAll() async {
    try {
      return await clearTable();
    } catch (e) {
      print("❌ Erro ao excluir todos os produtos: $e");
      return 0;
    }
  }
}
