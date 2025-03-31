import 'package:sqflite/sqflite.dart';
import 'package:flutter_docig_venda/services/database_helper.dart';

abstract class BaseDao<T> {
  final String tableName;

  BaseDao(this.tableName);

  Future<Database> get database async => await DatabaseHelper.instance.database;

  /// 🔹 Insere ou atualiza um item no banco
  Future<int> insertOrUpdate(Map<String, dynamic> data, String idColumn) async {
    final db = await database;
    return await db.insert(
      tableName,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔹 Busca todos os registros
  Future<List<T>> getAll(Function fromJson) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(tableName);
    return result.map((json) => fromJson(json) as T).toList();
  }

  /// 🔹 Busca um item pelo ID
  Future<T?> getById(String idColumn, dynamic id, Function fromJson) async {
    final db = await database;
    final List<Map<String, dynamic>> result =
        await db.query(tableName, where: "$idColumn = ?", whereArgs: [id]);
    if (result.isNotEmpty) {
      return fromJson(result.first) as T;
    }
    return null;
  }

  /// 🔹 Remove um item pelo ID
  Future<int> delete(String idColumn, dynamic id) async {
    final db = await database;
    return await db.delete(tableName, where: "$idColumn = ?", whereArgs: [id]);
  }

  /// 🔹 Limpa toda a tabela
  Future<int> clearTable() async {
    final db = await database;
    return await db.delete(tableName);
  }

  /// 🔹 Sincroniza a tabela com dados da API
  /// [fetchFromApi] é uma função que busca os dados da API
  /// [toDbJson] é uma função que converte o objeto da API para o formato do banco
  /// [idColumn] é o nome da coluna que identifica unicamente o registro
  Future<int> syncWithApi({
    required Future<List<dynamic>> Function() fetchFromApi,
    required Map<String, dynamic> Function(dynamic item) toDbJson,
    required String idColumn,
  }) async {
    try {
      // Busca dados da API
      final List<dynamic> apiData = await fetchFromApi();

      // Inicia uma transação para melhor performance em múltiplas operações
      final db = await database;
      return await db.transaction((txn) async {
        int count = 0;

        // Insere ou atualiza cada item retornado pela API
        for (final item in apiData) {
          final dbJson = toDbJson(item);

          await txn.insert(
            tableName,
            dbJson,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          count++;
        }

        return count;
      });
    } catch (e) {
      print('Erro ao sincronizar $tableName: $e');
      rethrow; // Relança a exceção para ser tratada pela camada superior
    }
  }

  /// 🔹 Verifica se a tabela está vazia
  Future<bool> isEmpty() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count == 0;
  }

  /// 🔹 Conta o número de registros na tabela
  Future<int> count() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
