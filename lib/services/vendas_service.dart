import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_produto_model.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_item_model.dart';
import 'package:flutter_docig_venda/data/models/carrinho_model.dart';
import 'package:flutter_docig_venda/data/models/condicao_pagamento.dart';
import 'package:flutter_docig_venda/data/models/registrar_pedido_local.dart';
import 'package:logger/logger.dart';



class VendasService {
  final UnifiedApiClient apiClient;
  final Logger _logger = Logger();

  VendasService({required this.apiClient});

  // ===== PRODUTOS =====
  Future<ApiResult<List<ProdutoModel>>> buscarProdutos() async {
    return await apiClient.get<List<ProdutoModel>>(
      '/v1/produto/${apiClient.empresaId}',
      fromJson: (json) => _parseList(json, ProdutoModel.fromJson),
    );
  }

  Future<ApiResult<ProdutoModel?>> buscarProdutoPorCodigo(int codigo) async {
    return await apiClient.get<ProdutoModel?>(
      '/v1/produto/${apiClient.empresaId}/$codigo',
      fromJson: (json) => json != null ? ProdutoModel.fromJson(json) : null,
    );
  }

  // ===== CLIENTES =====
  Future<ApiResult<List<Cliente>>> buscarClientes() async {
    return await apiClient.get<List<Cliente>>(
      '/v1/cliente/${apiClient.empresaId}',
      fromJson: (json) => _parseList(json, Cliente.fromJson),
    );
  }

  Future<ApiResult<Cliente?>> buscarClientePorCodigo(int codigo) async {
    return await apiClient.get<Cliente?>(
      '/v1/cliente/${apiClient.empresaId}/$codigo',
      fromJson: (json) => json != null ? Cliente.fromJson(json) : null,
    );
  }

  // ===== CLIENTE-PRODUTO =====
  Future<ApiResult<List<Cliente_Produto>>> buscarClienteProdutos(String codigoCliente) async {
    return await apiClient.get<List<Cliente_Produto>>(
      '/v1/cliente_produto/$codigoCliente',
      fromJson: (json) => _parseList(json, Cliente_Produto.fromJson),
    );
  }

  // ===== PEDIDOS =====
/*  Future<ApiResult<List<RegistroPedidoLocal>>> buscarPedidos() async {
    return await apiClient.get<List<RegistroPedidoLocal>>(
      '/v1/pedido/${apiClient.empresaId}',
      fromJson: (json) => _parseList(json, PedidoModel.fromJson),
    );
  }

  Future<ApiResult<PedidoModel>> criarPedido(PedidoModel pedido) async {
    return await apiClient.post<PedidoModel>(
      '/v1/pedido/${apiClient.empresaId}',
      body: pedido.toJson(),
      fromJson: (json) => PedidoModel.fromJson(json),
    );
  }
*/
  // ===== CONDIÇÕES DE PAGAMENTO =====
  Future<ApiResult<List<CondicaoPagamento>>> buscarCondicoesPagamento() async {
    return await apiClient.get<List<CondicaoPagamento>>(
      '/v1/condicao-pagamento/${apiClient.empresaId}',
      fromJson: (json) => _parseList(json, CondicaoPagamento.fromJson),
    );
  }

  // ===== DUPLICATAS =====
  Future<ApiResult<List<Duplicata>>> buscarDuplicatasCliente(int codcli) async {
    return await apiClient.get<List<Duplicata>>(
      '/v1/duplicata/${apiClient.empresaId}/cliente/$codcli',
      fromJson: (json) => _parseList(json, Duplicata.fromJson),
    );
  }

  // Helper para parsear listas
  List<T> _parseList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is List) {
      return json.map((item) => fromJson(item as Map<String, dynamic>)).toList();
    } else if (json is Map) {
      // Tenta diferentes chaves comuns
      final keys = ['data', 'items', 'results', 'produtos', 'clientes', 'pedidos'];
      for (final key in keys) {
        if (json.containsKey(key) && json[key] is List) {
          return (json[key] as List)
              .map((item) => fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    }
    return [];
  }
}