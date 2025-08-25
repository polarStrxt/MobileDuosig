// lib/repositories/cliente_repository.dart
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/dao/cliente_dao.dart';
import 'package:flutter/material.dart'; // Para debugPrint

class ClienteRepository {
  final ClienteDao _clienteDao = ClienteDao();

  Future<List<Cliente>> getClientes() async { // Use ClienteModel
    try {
      // Assumindo que ClienteDao.getAll retorna List<Map<String, dynamic>>
      // e ClienteModel.fromJson espera Map<String, dynamic>
      return await _clienteDao.getAll((json) => Cliente.fromJson(json));
    } catch (e) {
      debugPrint('Erro ao buscar clientes no repositório: $e');
      return [];
    }
  }

  // Opcional: Método para buscar clientes por uma lista de códigos
  Future<List<Cliente>> getClientesPorCodigos(List<int> codigos) async {
    if (codigos.isEmpty) return [];
    try {
      // Este método precisaria ser implementado no ClienteDao
      // Ex: return await _clienteDao.getClientesWhereIn('codcli', codigos);
      // Por agora, vamos buscar todos e filtrar (menos eficiente)
      final todos = await getClientes();
      return todos.where((c) => c.codcli != null && codigos.contains(c.codcli)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar clientes por códigos: $e');
      return [];
    }
  }
}