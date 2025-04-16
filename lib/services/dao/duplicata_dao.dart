import 'package:flutter_docig_venda/services/apiduplicata.dart'; // Versão padronizada
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/widgets/dao_generico.dart';
import 'package:flutter_docig_venda/services/api_client.dart'; // Para usar ApiResult
import 'package:flutter/foundation.dart' show kDebugMode;

/// DAO responsável pelo acesso a dados de Duplicatas no banco local
class DuplicataDao extends BaseDao<Duplicata> {
  final DuplicataService? _duplicataService;

  /// Construtor que permite injeção de dependência para testes
  DuplicataDao({DuplicataService? duplicataService})
      : _duplicataService = duplicataService,
        super('duplicata');

  /// Método auxiliar para logs
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  /// Implementa o método getAll da classe BaseDao
  @override
  Future<List<Duplicata>> getAll(Function fromJson) async {
    return super.getAll((json) => Duplicata.fromJson(json));
  }

  /// Sincroniza duplicatas da API com o banco de dados local
  ///
  /// Retorna o número de registros sincronizados ou um erro
  Future<ApiResult<int>> sincronizarDuplicatas() async {
    try {
      // Cria instância do serviço se não foi injetada no construtor
      final service = _duplicataService ?? DuplicataService();
      
      // Busca duplicatas da API
      final apiResult = await service.buscarDuplicatas();
      
      if (!apiResult.isSuccess) {
        return ApiResult.error(
          "Falha ao buscar duplicatas da API: ${apiResult.errorMessage}"
        );
      }
      
      final duplicatas = apiResult.data!;
      int count = 0;
      
      // Salva cada duplicata no banco local
      for (var duplicata in duplicatas) {
        await insertOrUpdate(duplicata.toJson(), 'numdoc');
        count++;
      }
      
      _log("✅ Duplicatas sincronizadas: $count registros");
      return ApiResult.success(count);
    } catch (e) {
      _log("❌ Erro ao sincronizar duplicatas: $e");
      return ApiResult.error("Falha ao sincronizar duplicatas: $e");
    }
  }

  /// Método legado para manter compatibilidade com o código existente
  ///
  /// Retorna void, mas internamente usa o novo método de sincronização
  Future<void> carregarDuplicatas() async {
    await sincronizarDuplicatas();
  }

  /// Busca todas as duplicatas no banco de dados local
  ///
  /// Retorna uma lista de todas as [Duplicata] ou um erro
  Future<ApiResult<List<Duplicata>>> obterTodasDuplicatas() async {
    try {
      final list = await getAll((json) => Duplicata.fromJson(json));
      return ApiResult.success(list);
    } catch (e) {
      _log("❌ Erro ao obter duplicatas: $e");
      return ApiResult.error("Falha ao obter duplicatas: $e");
    }
  }

  /// Busca uma duplicata específica pelo número do documento
  ///
  /// [numdoc] O número único do documento
  /// Retorna a [Duplicata] correspondente, null se não encontrada, ou um erro
  Future<ApiResult<Duplicata?>> obterDuplicataPorNumero(String numdoc) async {
    try {
      final duplicata = await getById('numdoc', numdoc, (json) => Duplicata.fromJson(json));
      return ApiResult.success(duplicata);
    } catch (e) {
      _log("❌ Erro ao obter duplicata $numdoc: $e");
      return ApiResult.error("Falha ao obter duplicata: $e");
    }
  }

  /// Busca duplicatas de um cliente específico
  ///
  /// [codcli] O código do cliente
  /// Retorna uma lista de [Duplicata] do cliente ou um erro
  Future<ApiResult<List<Duplicata>>> obterDuplicatasPorCliente(int codcli) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'codcli = ?',
        whereArgs: [codcli],
      );
      
      final list = results.map((json) => Duplicata.fromJson(json)).toList();
      return ApiResult.success(list);
    } catch (e) {
      _log("❌ Erro ao obter duplicatas do cliente $codcli: $e");
      return ApiResult.error("Falha ao obter duplicatas do cliente: $e");
    }
  }

  /// Salva uma duplicata no banco de dados local
  ///
  /// [duplicata] A duplicata a ser salva
  /// Retorna o ID do registro inserido/atualizado ou um erro
  Future<ApiResult<int>> salvarDuplicata(Duplicata duplicata) async {
    try {
      final id = await insertOrUpdate(duplicata.toJson(), 'numdoc');
      return ApiResult.success(id);
    } catch (e) {
      _log("❌ Erro ao salvar duplicata ${duplicata.numdoc}: $e");
      return ApiResult.error("Falha ao salvar duplicata: $e");
    }
  }

  /// Remove todas as duplicatas do banco de dados local
  ///
  /// Retorna o número de registros excluídos ou um erro
  Future<ApiResult<int>> excluirTodasDuplicatas() async {
    try {
      final count = await clearTable();
      return ApiResult.success(count);
    } catch (e) {
      _log("❌ Erro ao excluir duplicatas: $e");
      return ApiResult.error("Falha ao excluir duplicatas: $e");
    }
  }

  /// Busca duplicatas com filtros personalizados
  ///
  /// [filtros] Mapa de colunas e valores para filtrar
  /// Retorna uma lista de [Duplicata] que correspondem aos filtros ou um erro
  Future<ApiResult<List<Duplicata>>> obterDuplicatasComFiltro(Map<String, dynamic> filtros) async {
    try {
      final db = await database;
      
      // Constrói a cláusula WHERE dinamicamente
      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];
      
      filtros.forEach((key, value) {
        whereConditions.add('$key = ?');
        whereArgs.add(value);
      });
      
      // Executa a consulta
      final List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      );
      
      final list = results.map((json) => Duplicata.fromJson(json)).toList();
      return ApiResult.success(list);
    } catch (e) {
      _log("❌ Erro ao filtrar duplicatas: $e");
      return ApiResult.error("Falha ao filtrar duplicatas: $e");
    }
  }
}