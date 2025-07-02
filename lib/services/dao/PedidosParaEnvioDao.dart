import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart'; // Para logging
import 'package:flutter_docig_venda/services/database_helper.dart'; // Ajuste o caminho
import 'package:flutter_docig_venda/models/registrar_pedido_local.dart';


class PedidosParaEnvioDao {
  final DatabaseHelper _dbHelper;
  final Logger _logger; // Pode receber ou criar uma instância

  // O DAO recebe a instância do DatabaseHelper
  PedidosParaEnvioDao(this._dbHelper, this._logger);

  /// Insere um novo pedido para envio no banco de dados.
  Future<int> inserir(RegistroPedidoLocal pedido) async {
    final db = await _dbHelper.database; // Usa o getter do DatabaseHelper
    try {
      // O toMap() da sua classe RegistroPedidoLocal já deve remover o id se for nulo
      Map<String, dynamic> row = pedido.toMap();
      if (pedido.idPedidoLocal == null) {
        row.remove('id_pedido_local');
      }

      final id = await db.insert(DatabaseHelper.tablePedidosParaEnvio, row);
      _logger.i("DAO: Pedido para envio salvo com ID local: $id, código app: ${pedido.codigoPedidoApp}");
      return id;
    } catch (e, s) {
      _logger.e("DAO: Erro ao salvar pedido para envio: $e", error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Retorna a contagem de pedidos pendentes para envio.
  Future<int> getPendentesCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tablePedidosParaEnvio} WHERE status_envio = ?',
      ['PENDENTE'],
    );
    final count = Sqflite.firstIntValue(result);
    _logger.i("DAO: Pedidos pendentes para envio: ${count ?? 0}");
    return count ?? 0;
  }

  /// Busca todos os pedidos pendentes para envio.
  Future<List<RegistroPedidoLocal>> getPendentesParaEnvio() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tablePedidosParaEnvio,
      where: 'status_envio = ?',
      whereArgs: ['PENDENTE'],
      orderBy: 'data_criacao ASC',
    );
    if (maps.isEmpty) {
      return [];
    }
    _logger.d("DAO: ${maps.length} pedidos pendentes encontrados.");
    return List.generate(maps.length, (i) {
      return RegistroPedidoLocal.fromMap(maps[i]);
    });
  }

  /// Deleta um pedido do banco local pelo seu ID local.
  Future<int> delete(int idPedidoLocal) async {
    final db = await _dbHelper.database;
    final count = await db.delete(
      DatabaseHelper.tablePedidosParaEnvio,
      where: 'id_pedido_local = ?',
      whereArgs: [idPedidoLocal],
    );
    if (count > 0) {
      _logger.i("DAO: Pedido local ID $idPedidoLocal deletado com sucesso.");
    } else {
      _logger.w("DAO: Nenhum pedido local encontrado para deletar com ID $idPedidoLocal.");
    }
    return count;
  }

  /// Atualiza o status de um pedido local.
  Future<int> atualizarStatus(int idPedidoLocal, String novoStatus) async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> row = {
      'status_envio': novoStatus,
      // Adicionar data de modificação se tiver essa coluna
      // 'data_ultima_modificacao_local': DateTime.now().toIso8601String(),
    };
    final count = await db.update(
      DatabaseHelper.tablePedidosParaEnvio,
      row,
      where: 'id_pedido_local = ?',
      whereArgs: [idPedidoLocal],
    );
    _logger.i("DAO: Status do pedido local ID $idPedidoLocal atualizado para $novoStatus. Linhas afetadas: $count");
    return count;
  }

  // Você pode adicionar outros métodos específicos aqui, como:
  // Future<RegistroPedidoLocal?> getPedidoPorCodigoApp(String codigoApp) async { ... }
}