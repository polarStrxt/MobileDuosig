import 'package:flutter_docig_venda/services/apiDuplicata.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/widgets/dao_generico.dart';

class DuplicataDao extends BaseDao<Duplicata> {
  DuplicataDao() : super('duplicata');

  final api = DuplicataApi(); // Instância da API

  @override
  Future<List<Duplicata>> getAll(Function fromJson) async {
    return super.getAll((json) => Duplicata.fromJson(json));
  }

  // Novo método: Sincroniza duplicatas usando o método da classe base
  Future<int> syncDuplicatas() async {
    return await syncWithApi(
      fetchFromApi: () async {
        // Usa o método existente da API para buscar duplicatas
        return await DuplicataApi.buscarDuplicatas();
      },
      toDbJson: (item) {
        // Converte o objeto Duplicata para formato JSON do banco
        return (item as Duplicata).toJson();
      },
      idColumn: 'numdoc',
    );
  }

  // Método anterior: Agora usa o novo método de sincronização
  Future<void> carregarDuplicatas() async {
    await syncDuplicatas();
  }

  // Buscar duplicatas no banco local após carregamento da API
  Future<List<Duplicata>> getAllDuplicatas() async {
    return getAll((json) => Duplicata.fromJson(json));
  }

  // Buscar duplicata pelo número do documento no banco local
  Future<Duplicata?> getDuplicataByNumero(String numdoc) async {
    return getById('numdoc', numdoc, (json) => Duplicata.fromJson(json));
  }

  // Buscar duplicatas por cliente no banco local
  Future<List<Duplicata>> getDuplicatasByCliente(int codcli) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      tableName,
      where: 'codcli = ?',
      whereArgs: [codcli],
    );
    return results.map((json) => Duplicata.fromJson(json)).toList();
  }

  // Salvar uma duplicata no banco local
  Future<int> save(Duplicata duplicata) async {
    return insertOrUpdate(duplicata.toJson(), 'numdoc');
  }

  // Excluir todos os registros no banco local
  Future<int> deleteAll() async {
    return await clearTable();
  }
}
