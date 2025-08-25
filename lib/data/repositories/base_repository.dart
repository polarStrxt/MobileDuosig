import 'package:sqflite/sqflite.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:logger/logger.dart';

abstract class BaseRepository<T> {
  final DatabaseHelper dbHelper;
  final Logger logger = Logger();

  BaseRepository(this.dbHelper);

  /// Nome da tabela no banco local
  String get tableName;

  /// Converte o modelo para Map para inserção no banco
  Map<String, dynamic> toMap(T model);

  /// Converte Map do banco para modelo
  T fromMap(Map<String, dynamic> map);

  /// Insere ou atualiza um registro
  Future<int> upsert(T model) async {
    final db = await dbHelper.database;
    final map = toMap(model);
    
    return await db.insert(
      tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insere múltiplos registros em batch
  Future<void> upsertBatch(List<T> models) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    
    for (final model in models) {
      batch.insert(
        tableName,
        toMap(model),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
    logger.i("${models.length} registros inseridos/atualizados em $tableName");
  }

  /// Busca todos os registros
  Future<List<T>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query(tableName);
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Busca com filtros
  Future<List<T>> getWhere({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return maps.map((map) => fromMap(map)).toList();
  }

  /// Deleta todos os registros
  Future<int> deleteAll() async {
    final db = await dbHelper.database;
    return await db.delete(tableName);
  }

  /// Conta registros
  Future<int> count({String? where, List<dynamic>? whereArgs}) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName ${where != null ? "WHERE $where" : ""}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}