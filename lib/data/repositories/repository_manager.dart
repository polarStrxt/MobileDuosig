import 'package:sqflite/sqflite.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';


class RepositoryManager {
  final DatabaseHelper dbHelper;

  late final ProdutoRepository produtoRepository;
  late final ClienteProdutoRepository clienteProdutoRepository;

  RepositoryManager(this.dbHelper) {
    produtoRepository = ProdutoRepository(dbHelper);
    clienteProdutoRepository = ClienteProdutoRepository(dbHelper);
  }
}
