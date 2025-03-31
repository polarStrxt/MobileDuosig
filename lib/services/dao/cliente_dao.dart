import 'package:flutter_docig_venda/widgets/dao_generico.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';

class ClienteDao extends BaseDao<Cliente> {
  ClienteDao() : super('clientes');

  @override
  Future<List<Cliente>> getAll(Function fromJson) async {
    return super.getAll((json) => Cliente.fromJson(json));
  }
}
