import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_docig_venda/models/cliente_model.dart';

class ClienteService {
  static const String baseUrl =
      "http://duotecsuprilev.ddns.com.br:8082/v1/cliente/001/31.01.1980";

  /// 🔹 Busca um único cliente por ID e data de nascimento
  static Future<Cliente?> buscarCliente(
      String id, String dataNascimento) async {
    try {
      final url = Uri.parse("$baseUrl/$id/$dataNascimento");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        return Cliente.fromJson(jsonResponse);
      } else {
        print("❌ Erro: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      return null;
    }
  }

  /// 🔹 Busca todos os clientes da API
  static Future<List<Cliente>> buscarClientes() async {
    try {
      final url = Uri.parse(baseUrl); // 🔹 Pega todos os clientes
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((data) => Cliente.fromJson(data)).toList();
      } else {
        print("❌ Erro: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      return [];
    }
  }
}
