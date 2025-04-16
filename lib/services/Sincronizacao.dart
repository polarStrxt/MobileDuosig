import 'dart:io';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/dao/duplicata_dao.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/services/apicliente.dart';
import 'package:flutter_docig_venda/services/apiproduto.dart';
import 'package:flutter_docig_venda/services/apiduplicata.dart';
import 'package:flutter_docig_venda/services/api_client.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Resultado da sincronização com contagem de registros processados
class SyncResult {
  final Map<String, int> counts;
  final bool isSuccess;
  final String? errorMessage;
  
  const SyncResult({
    required this.counts,
    required this.isSuccess,
    this.errorMessage,
  });
  
  SyncResult.success(this.counts)
      : isSuccess = true,
        errorMessage = null;
        
  SyncResult.error(this.errorMessage)
      : isSuccess = false,
        counts = const {};
        
  int get totalCount => counts.values.fold(0, (prev, count) => prev + count);
  
  @override
  String toString() {
    if (!isSuccess) return 'SyncResult(error: $errorMessage)';
    return 'SyncResult(counts: $counts, total: $totalCount)';
  }
}

/// Serviço responsável pela sincronização de dados entre API e banco de dados local
class SyncService {
  final ClienteDao _clienteDao;
  final ProdutoDao _produtoDao;
  final DuplicataDao _duplicataDao;
  final ClienteService _clienteService;
  final ProdutoService _produtoService;
  final DuplicataService _duplicataService;
  
  /// Construtor com injeção de dependência para facilitar testes
  SyncService({
    ClienteDao? clienteDao,
    ProdutoDao? produtoDao,
    DuplicataDao? duplicataDao,
    ClienteService? clienteService,
    ProdutoService? produtoService,
    DuplicataService? duplicataService,
  }) : _clienteDao = clienteDao ?? ClienteDao(),
       _produtoDao = produtoDao ?? ProdutoDao(),
       _duplicataDao = duplicataDao ?? DuplicataDao(),
       _clienteService = clienteService ?? ClienteService(),
       _produtoService = produtoService ?? ProdutoService(),
       _duplicataService = duplicataService ?? DuplicataService();
       
  /// Método auxiliar para logs
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  /// Verifica se o dispositivo tem conexão com a internet
  ///
  /// Retorna true se a conexão estiver disponível
  Future<ApiResult<bool>> verificarConexaoInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (hasInternet) {
        _log("✅ Conexão com internet disponível");
        return ApiResult.success(true);
      } else {
        _log("⚠️ Sem conexão com a internet");
        return ApiResult.success(false);
      }
    } catch (e) {
      _log("❌ Erro ao verificar conexão: $e");
      return ApiResult.error("Falha ao verificar conexão: $e");
    }
  }

  /// Sincroniza todos os dados (clientes, produtos e duplicatas)
  ///
  /// Retorna um [SyncResult] com a contagem de registros processados para cada entidade
  Future<SyncResult> sincronizarTodosDados() async {
    final internetResult = await verificarConexaoInternet();
    
    if (!internetResult.isSuccess) {
      return SyncResult.error(internetResult.errorMessage);
    }
    
    if (!internetResult.data!) {
      return SyncResult.error(
        "Sem conexão com a internet. Verifique sua conexão e tente novamente."
      );
    }
    
    try {
      final results = <String, int>{
        'Clientes': 0,
        'Produtos': 0,
        'Duplicatas': 0,
      };
      
      // Executa todas as sincronizações e aguarda os resultados
      final clientesResult = await sincronizarClientes();
      final produtosResult = await sincronizarProdutos();
      final duplicatasResult = await sincronizarDuplicatas();
      
      // Verifica se todas as sincronizações foram bem-sucedidas
      if (!clientesResult.isSuccess) {
        return SyncResult.error("Erro ao sincronizar clientes: ${clientesResult.errorMessage}");
      }
      
      if (!produtosResult.isSuccess) {
        return SyncResult.error("Erro ao sincronizar produtos: ${produtosResult.errorMessage}");
      }
      
      if (!duplicatasResult.isSuccess) {
        return SyncResult.error("Erro ao sincronizar duplicatas: ${duplicatasResult.errorMessage}");
      }
      
      // Totaliza os resultados
      results['Clientes'] = clientesResult.data!;
      results['Produtos'] = produtosResult.data!;
      results['Duplicatas'] = duplicatasResult.data!;
      
      _log("✅ Sincronização concluída com sucesso!");
      _log("   Clientes: ${results['Clientes']} registros");
      _log("   Produtos: ${results['Produtos']} registros");
      _log("   Duplicatas: ${results['Duplicatas']} registros");
      
      return SyncResult.success(results);
    } catch (e) {
      _log("❌ Erro durante a sincronização: $e");
      return SyncResult.error("Falha na sincronização: $e");
    }
  }

  /// Sincroniza a lista de clientes
  ///
  /// Retorna um [ApiResult] com a contagem de registros processados
  Future<ApiResult<int>> sincronizarClientes() async {
    try {
      int count = 0;
      final clientesResult = await _clienteService.buscarClientes();
      
      if (!clientesResult.isSuccess) {
        return ApiResult.error(
          "Falha ao buscar clientes da API: ${clientesResult.errorMessage}"
        );
      }
      
      final clientes = clientesResult.data!;
      
      for (var cliente in clientes) {
        await _clienteDao.insertOrUpdate(cliente.toJson(), 'codcli');
        count++;
      }
      
      _log("✅ Clientes sincronizados: $count registros");
      return ApiResult.success(count);
    } catch (e) {
      _log("❌ Erro ao sincronizar clientes: $e");
      return ApiResult.error("Falha ao sincronizar clientes: $e");
    }
  }

  /// Sincroniza a lista de produtos
  ///
  /// Retorna um [ApiResult] com a contagem de registros processados
  Future<ApiResult<int>> sincronizarProdutos() async {
    try {
      int count = 0;
      final produtosResult = await _produtoService.buscarProdutos();
      
      if (!produtosResult.isSuccess) {
        return ApiResult.error(
          "Falha ao buscar produtos da API: ${produtosResult.errorMessage}"
        );
      }
      
      final produtos = produtosResult.data!;
      
      for (var produto in produtos) {
        await _produtoDao.insertOrUpdate(produto.toJson(), 'codprd');
        count++;
      }
      
      _log("✅ Produtos sincronizados: $count registros");
      return ApiResult.success(count);
    } catch (e) {
      _log("❌ Erro ao sincronizar produtos: $e");
      return ApiResult.error("Falha ao sincronizar produtos: $e");
    }
  }

  /// Sincroniza a lista de duplicatas
  ///
  /// Retorna um [ApiResult] com a contagem de registros processados
  Future<ApiResult<int>> sincronizarDuplicatas() async {
    try {
      int count = 0;
      final duplicatasResult = await _duplicataService.buscarDuplicatas();
      
      if (!duplicatasResult.isSuccess) {
        return ApiResult.error(
          "Falha ao buscar duplicatas da API: ${duplicatasResult.errorMessage}"
        );
      }
      
      final duplicatas = duplicatasResult.data!;
      
      for (var duplicata in duplicatas) {
        await _duplicataDao.insertOrUpdate(duplicata.toJson(), 'numdoc');
        count++;
      }
      
      _log("✅ Duplicatas sincronizadas: $count registros");
      return ApiResult.success(count);
    } catch (e) {
      _log("❌ Erro ao sincronizar duplicatas: $e");
      return ApiResult.error("Falha ao sincronizar duplicatas: $e");
    }
  }

  /// Limpa todas as tabelas do banco de dados local
  ///
  /// Retorna um [ApiResult] indicando sucesso ou falha na operação
  Future<ApiResult<bool>> limparTodasTabelas() async {
    try {
      await _clienteDao.clearTable();
      await _produtoDao.clearTable();
      await _duplicataDao.clearTable();
      
      _log("🗑️ Todas as tabelas foram limpas");
      return ApiResult.success(true);
    } catch (e) {
      _log("❌ Erro ao limpar tabelas: $e");
      return ApiResult.error("Falha ao limpar tabelas: $e");
    }
  }

  /// Obtém a contagem de registros em cada tabela
  ///
  /// Retorna um [ApiResult] contendo um mapa com a contagem de cada entidade
  Future<ApiResult<Map<String, int>>> obterContagemRegistros() async {
    try {
      final Map<String, int> counts = {};
      
      counts['Clientes'] = await _clienteDao.count();
      counts['Produtos'] = await _produtoDao.count();
      counts['Duplicatas'] = await _duplicataDao.count();
      
      return ApiResult.success(counts);
    } catch (e) {
      _log("❌ Erro ao obter contagem de registros: $e");
      return ApiResult.error("Falha ao obter contagem de registros: $e");
    }
  }
}