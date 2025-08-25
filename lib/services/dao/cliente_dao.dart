import 'package:flutter_docig_venda/presentation/widgets/dao_generico.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';

class ClienteDao extends BaseDao<Cliente> {
  ClienteDao() : super('clientes');

  @override
  Future<List<Cliente>> getAll(Function fromJson) async {
    return super.getAll((json) => Cliente.fromJson(json));
  }
}
