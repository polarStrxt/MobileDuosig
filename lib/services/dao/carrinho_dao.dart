// lib/services/dao/carrinhos_dao.dart

import 'package:sqflite/sqflite.dart';
import 'package:logger/logger.dart'; // Para logging
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart'; // Ajuste o caminho
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';   // Ajuste o caminho
// import 'package:flutter_docig_venda/widgets/dao_generico.dart'; // Se você tem um BaseDao

// Assumindo que BaseDao fornece 'Future<Database> get database'
// class CarrinhosDao extends BaseDao {
//   CarrinhosDao() : super(DatabaseHelper.tableCarrinhos);

// Se você não tem BaseDao ou ele não é necessário aqui:
class CarrinhosDao {
  final Logger _logger = Logger();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Se BaseDao não exige createTable, remova este método.
  // O DatabaseHelper já cuida da criação da tabela.
  // @override
  // Future<void> createTable(Database db) async {
  //   // SQL DEVE SER IDÊNTICO AO DatabaseHelper._createCarrinhosTable
  //   // É melhor centralizar a criação no DatabaseHelper.
  // }

  Future<Database> get _database async => await _dbHelper.database;


  // Criar um novo carrinho ou obter um carrinho aberto existente para um cliente
  Future<CarrinhoModel?> getOuCriarCarrinhoAberto(int codcli) async {
    final db = await _database;
    CarrinhoModel? carrinho;

    List<Map<String, dynamic>> existentes = await db.query(
      DatabaseHelper.tableCarrinhos,
      where: 'codcli = ? AND status = ?',
      whereArgs: [codcli, 'aberto'],
      limit: 1,
    );

    if (existentes.isNotEmpty) {
      carrinho = CarrinhoModel.fromJson(existentes.first);
      _logger.i("Carrinho aberto encontrado para cliente $codcli: id ${carrinho.id}");
    } else {
      DateTime agora = DateTime.now();
      CarrinhoModel novoCarrinho = CarrinhoModel(
        codcli: codcli,
        dataCriacao: agora,
        dataUltimaModificacao: agora,
        status: 'aberto',
      );
      try {
        int idNovoCarrinho = await db.insert(DatabaseHelper.tableCarrinhos, novoCarrinho.toJson());
        if (idNovoCarrinho > 0) {
          // Busca o carrinho recém-criado para retornar o objeto completo com ID
          List<Map<String, dynamic>> results = await db.query(
            DatabaseHelper.tableCarrinhos,
            where: 'id = ?',
            whereArgs: [idNovoCarrinho],
          );
          if (results.isNotEmpty) {
            carrinho = CarrinhoModel.fromJson(results.first);
            _logger.d("Novo carrinho criado para cliente $codcli: id ${carrinho?.id}");
          }
        }
      } catch (e, s) {
        _logger.e("Erro ao criar novo carrinho para cliente $codcli", error: e, stackTrace: s);
      }
    }
    return carrinho;
  }

  Future<CarrinhoModel?> getCarrinhoPorId(int idCarrinho) async {
    final db = await _database;
    List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.tableCarrinhos,
      where: 'id = ?',
      whereArgs: [idCarrinho],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CarrinhoModel.fromJson(maps.first);
    }
    _logger.w("Nenhum carrinho encontrado com ID: $idCarrinho");
    return null;
  }

  Future<bool> atualizarStatusCarrinho(int idCarrinho, String novoStatus) async {
    final db = await _database;
    try {
      int count = await db.update(
        DatabaseHelper.tableCarrinhos,
        {
          'status': novoStatus,
          'data_ultima_modificacao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
      if (count > 0) {
        _logger.i("Status do carrinho $idCarrinho atualizado para '$novoStatus'.");
        return true;
      }
      _logger.w("Nenhum carrinho atualizado. ID: $idCarrinho, Novo Status: $novoStatus");
      return false;
    } catch (e, s) {
      _logger.e("Erro ao atualizar status do carrinho $idCarrinho", error: e, stackTrace: s);
      return false;
    }
  }

  Future<bool> atualizarObservacoesCarrinho(int idCarrinho, String observacoes) async {
    final db = await _database;
     try {
      int count = await db.update(
        DatabaseHelper.tableCarrinhos,
        {
          'observacoes': observacoes,
          'data_ultima_modificacao': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
       if (count > 0) {
        _logger.i("Observações do carrinho $idCarrinho atualizadas.");
        return true;
      }
      _logger.w("Nenhuma observação de carrinho atualizada. ID: $idCarrinho");
      return false;
    } catch (e, s) {
      _logger.e("Erro ao atualizar observações do carrinho $idCarrinho", error: e, stackTrace: s);
      return false;
    }
  }
  
  // Método para atualizar os totais no carrinho (se você decidir armazená-los)
  Future<bool> atualizarTotaisCarrinho(int idCarrinho, {double? bruto, double? descontos, double? liquido}) async {
    final db = await _database;
    Map<String, dynamic> dataToUpdate = {
        'data_ultima_modificacao': DateTime.now().toIso8601String(),
    };
    if (bruto != null) dataToUpdate['valor_total_bruto'] = bruto;
    if (descontos != null) dataToUpdate['valor_total_descontos'] = descontos;
    if (liquido != null) dataToUpdate['valor_total_liquido'] = liquido;

    if (dataToUpdate.length == 1) { // Apenas data_ultima_modificacao
        _logger.i("Nenhum total para atualizar no carrinho $idCarrinho, apenas data de modificação.");
        // Você pode optar por não fazer o update se apenas a data for mudar, ou fazer mesmo assim.
    }

    try {
        int count = await db.update(
            DatabaseHelper.tableCarrinhos,
            dataToUpdate,
            where: 'id = ?',
            whereArgs: [idCarrinho],
        );
        if (count > 0) {
            _logger.i("Totais do carrinho $idCarrinho atualizados.");
            return true;
        }
        _logger.w("Nenhum total de carrinho atualizado. ID: $idCarrinho");
        return false;
    } catch (e, s) {
        _logger.e("Erro ao atualizar totais do carrinho $idCarrinho", error: e, stackTrace: s);
        return false;
    }
  }


  // Deleta um carrinho e seus itens (devido ao ON DELETE CASCADE)
  Future<bool> deletarCarrinho(int idCarrinho) async {
    final db = await _database;
    try {
      int count = await db.delete(
        DatabaseHelper.tableCarrinhos,
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
      if (count > 0) {
        _logger.i("Carrinho $idCarrinho deletado (e seus itens via cascade).");
        return true;
      }
      _logger.w("Nenhum carrinho deletado. ID: $idCarrinho");
      return false;
    } catch (e, s) {
      _logger.e("Erro ao deletar carrinho $idCarrinho", error: e, stackTrace: s);
      return false;
    }
  }

  // Cole estes dois métodos DENTRO da sua classe CarrinhosDao

  /// Busca um carrinho aberto para um cliente, sem criar um novo.
  /// Retorna o CarrinhoModel se encontrado e aberto, ou null caso contrário.
  Future<CarrinhoModel?> getCarrinhoAberto(int codcli) async {
    // Garante acesso ao banco de dados (adapte se seu BaseDao for diferente)
    final db = await DatabaseHelper.instance.database; 
    // Usa instância do Logger (adicione 'final Logger _logger = Logger();' no seu DAO)
    final Logger _logger = Logger(); 

    List<Map<String, dynamic>> existentes = await db.query(
      DatabaseHelper.tableCarrinhos, // Use a constante de nome de tabela
      where: 'codcli = ? AND status = ?',
      whereArgs: [codcli, 'aberto'], // Busca apenas os abertos
      limit: 1,
    );

    if (existentes.isNotEmpty) {
      _logger.i("Carrinho aberto encontrado para cliente $codcli via getCarrinhoAberto.");
      return CarrinhoModel.fromJson(existentes.first);
    }
    _logger.i("Nenhum carrinho aberto encontrado para cliente $codcli via getCarrinhoAberto.");
    return null; // Retorna null explicitamente se não achar
  }

  /// Atualiza apenas a data de modificação de um carrinho existente.
  Future<bool> atualizarDataModificacao(int idCarrinho) async {
    // Garante acesso ao banco de dados
    final db = await DatabaseHelper.instance.database; 
    // Usa instância do Logger
    final Logger _logger = Logger(); 

    try {
      int count = await db.update(
        DatabaseHelper.tableCarrinhos, // Use a constante de nome de tabela
        {'data_ultima_modificacao': DateTime.now().toIso8601String()}, // Apenas atualiza a data/hora
        where: 'id = ?',
        whereArgs: [idCarrinho],
      );
      if (count > 0) {
        _logger.i("Data de modificação do carrinho $idCarrinho atualizada.");
        return true;
      }
      _logger.w("Nenhuma data de modificação de carrinho atualizada (update retornou 0). ID: $idCarrinho");
      return false; // Retorna false se nenhum registro foi atualizado
    } catch (e, s) {
      _logger.e("Erro ao atualizar data_ultima_modificacao do carrinho $idCarrinho", error: e, stackTrace: s);
      return false; // Retorna false em caso de erro
    }
  }


// Não se esqueça de importar o Logger e o DatabaseHelper no arquivo do CarrinhosDao
// import 'package:logger/logger.dart';
// import 'package:flutter_docig_venda/helpers/database_helper.dart';
// import 'package:flutter_docig_venda/models/carrinho_model.dart';

// DENTRO DA CLASSE CarrinhosDao
// (lib/services/dao/carrinhos_dao.dart)

Future<List<int>> getCodigosClientesComCarrinhoAberto() async {
  final db = await DatabaseHelper.instance.database;
  final Logger logger = Logger(); // Adicione uma instância do logger se não tiver
  
  final List<Map<String, dynamic>> maps = await db.query(
    DatabaseHelper.tableCarrinhos,
    distinct: true,
    columns: ['codcli'],
    where: 'status = ?',
    whereArgs: ['aberto'],
  );
  
  List<int> codigos = maps.map((map) => map['codcli'] as int).toList();
  logger.d("Códigos de clientes com carrinho aberto (DAO): $codigos");
  return codigos;
}



}