import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_docig_venda/models/produto_model.dart';

class ProdutoService {
  // Base URL do servidor http://duotecsuprilev.ddns.com.br:8082/v1/produto/001/31.01.1980
  static const String baseUrl = "http://duotecsuprilev.ddns.com.br:8082";

  // Método principal para buscar produtos (conforme chamado no ProdutoScreen)
  static Future<List<Produto>> buscarProdutos() async {
    return await buscarTodosProdutos(); // Redirecionando para o método solicitado
  }

  // Método específico para buscar todos os produtos
  static Future<List<Produto>> buscarTodosProdutos() async {
    try {
      // Endpoint completo conforme a estrutura original
      final url = Uri.parse("$baseUrl/v1/produto/001/31.01.1980");

      print("🔍 Tentando buscar produtos da URL: $url");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          // Se precisar de autenticação, adicione aqui
          // "Authorization": "Bearer SEU_TOKEN_AQUI",
        },
      );

      if (response.statusCode == 200) {
        print("✅ Produtos carregados com sucesso");
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => Produto.fromJson(item)).toList();
      } else {
        print(
            "❌ Erro ${response.statusCode} ao buscar produtos: ${response.body}");
        print("❌ URL tentada: $url");
        throw Exception(
            "Falha ao carregar produtos. Código: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      throw Exception("Erro ao conectar com o servidor: $e");
    }
  }

  // Busca produto por código
  static Future<Produto?> buscarProdutoPorCodigo(String codigo) async {
    try {
      final url = Uri.parse("$baseUrl/v1/produto/001/31.01.1980/$codigo");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        return Produto.fromJson(jsonResponse);
      } else {
        print("❌ Erro ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      return null;
    }
  }

  // Busca produtos por descrição
  static Future<List<Produto>> buscarProdutosPorDescricao(String termo) async {
    try {
      final termoCodificado = Uri.encodeComponent(termo);
      final url = Uri.parse(
          "$baseUrl/v1/produto/001/31.01.1980/busca/$termoCodificado");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => Produto.fromJson(item)).toList();
      } else {
        print("❌ Erro ${response.statusCode}: ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      return [];
    }
  }
}
