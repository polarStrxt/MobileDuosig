import 'dart:io';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/dao/duplicata_dao.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/services/apiCliente.dart';
import 'package:flutter_docig_venda/services/apiProduto.dart';
import 'package:flutter_docig_venda/services/apiDuplicata.dart';

class SyncService {
  final ClienteDao clienteDao = ClienteDao();
  final ProdutoDao produtoDao = ProdutoDao();
  final DuplicataDao duplicataDao = DuplicataDao(); // Renomeado para clareza

  /// 🔹 Verifica se há internet
  Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 🔹 Sincroniza todos os dados
  Future<Map<String, int>> syncAllData() async {
    final results = <String, int>{
      'Clientes': 0,
      'Produtos': 0,
      'Duplicatas': 0,
    };

    if (await hasInternetConnection()) {
      results['Clientes'] = await syncClientes();
      results['Produtos'] = await syncProdutos();
      results['Duplicatas'] = await syncDuplicatas();

      print("✅ Sincronização concluída!");
      print("   Clientes: ${results['Clientes']} registros");
      print("   Produtos: ${results['Produtos']} registros");
      print("   Duplicatas: ${results['Duplicatas']} registros");

      return results;
    } else {
      throw Exception(
          "⚠️ Sem conexão com a internet. Verifique sua conexão e tente novamente.");
    }
  }

  /// 🔹 Sincroniza clientes
  Future<int> syncClientes() async {
    int count = 0;
    List<Cliente> clientes = await ClienteService.buscarClientes();

    for (var cliente in clientes) {
      await clienteDao.insertOrUpdate(cliente.toJson(), 'codcli');
      count++;
    }

    print("✅ Clientes sincronizados: $count registros");
    return count;
  }

  /// 🔹 Sincroniza produtos
  Future<int> syncProdutos() async {
    int count = 0;
    List<Produto> produtos = await ProdutoService.buscarProdutos();

    for (var produto in produtos) {
      await produtoDao.insertOrUpdate(produto.toJson(), 'codprod');
      count++;
    }

    print("✅ Produtos sincronizados: $count registros");
    return count;
  }

  /// 🔹 Sincroniza duplicatas (anteriormente pedidos)
  Future<int> syncDuplicatas() async {
    int count = 0;
    List<Duplicata> duplicatas = await DuplicataApi.buscarDuplicatas();

    for (var duplicata in duplicatas) {
      await duplicataDao.insertOrUpdate(duplicata.toJson(),
          'numdoc'); // Corrigido para usar 'numdoc' conforme DuplicataDao
      count++;
    }

    print("✅ Duplicatas sincronizadas: $count registros");
    return count;
  }

  /// 🔹 Limpa todas as tabelas
  Future<void> clearAllTables() async {
    await clienteDao.clearTable();
    await produtoDao.clearTable();
    await duplicataDao.clearTable();

    print("🗑️ Todas as tabelas foram limpas");
  }

  /// 🔹 Obtém contagem de registros em cada tabela
  Future<Map<String, int>> getTableCounts() async {
    final Map<String, int> counts = {};

    counts['Clientes'] = await clienteDao.count();
    counts['Produtos'] = await produtoDao.count();
    counts['Duplicatas'] = await duplicataDao.count();

    return counts;
  }
}
