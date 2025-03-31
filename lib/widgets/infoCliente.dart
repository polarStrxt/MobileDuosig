import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/botao.dart';
import 'package:flutter_docig_venda/screens/produtoScreen.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/screens/dupricata.dart'; // Corrigido: Alterado de dupricata.dart para duplicata_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class Infocliente extends StatelessWidget {
  final Cliente cliente;

  const Infocliente({Key? key, required this.cliente}) : super(key: key);

  // Método para buscar duplicatas do cliente da API
  Future<List<Duplicata>> _buscarDuplicatasDoCliente(int codcli) async {
    try {
      final baseUrl = "http://duotecsuprilev.ddns.com.br:8082";
      final url = Uri.parse("$baseUrl/v1/duplicatas/$codcli");

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => Duplicata.fromJson(item)).toList();
      } else {
        print(
            "❌ Erro ${response.statusCode} ao buscar duplicatas: ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ Erro na requisição: $e");
      return [];
    }
  }

  Widget customContainer(String label, String? valor, IconData icone) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label do campo
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          // Valor do campo
          Row(
            children: [
              Icon(icone, color: Color(0xFF5D5CDE), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  valor?.isNotEmpty == true ? valor! : "Não informado",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para exibir seções de informações
  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Color(0xFF5D5CDE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5D5CDE),
            ),
          ),
        ],
      ),
    );
  }

  // Formata CNPJ/CPF
  String formatarDocumento(String documento) {
    if (documento.isEmpty) return "Não informado";

    // Verifica se é CNPJ ou CPF
    if (documento.length == 14) {
      // CNPJ
      return "${documento.substring(0, 2)}.${documento.substring(2, 5)}.${documento.substring(5, 8)}/${documento.substring(8, 12)}-${documento.substring(12)}";
    } else if (documento.length == 11) {
      // CPF
      return "${documento.substring(0, 3)}.${documento.substring(3, 6)}.${documento.substring(6, 9)}-${documento.substring(9)}";
    }

    return documento;
  }

  // Formata valores monetários
  String formatarValor(double valor) {
    return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Informações do Cliente"),
        backgroundColor: Color(0xFF5D5CDE),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com informações principais
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF5D5CDE),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Avatar com iniciais
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _obterIniciais(cliente.nomcli),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Nome e código
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.nomcli,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Código: ${cliente.codcli}",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Status e limites
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusChip(cliente.staati),
                      Text(
                        formatarValor(cliente.vlrlimcrd),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Informações de Contato
            sectionTitle("Informações de Contato"),
            customContainer(
                "Telefone Principal", cliente.numtel001, Icons.phone),
            customContainer(
                "Telefone Secundário", cliente.numtel002, Icons.phone_android),
            customContainer("E-mail", cliente.emailcli, Icons.email),
            customContainer("CNPJ/CPF", formatarDocumento(cliente.cgccpfcli),
                Icons.article),

            // Informações de Endereço
            sectionTitle("Endereço"),
            customContainer("Logradouro", cliente.endcli, Icons.location_on),
            Row(
              children: [
                Expanded(
                  child: customContainer(
                      "Bairro", cliente.baicli, Icons.location_city),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: customContainer(
                      "Cidade", cliente.muncli, Icons.location_city),
                ),
              ],
            ),
            customContainer("Estado", cliente.ufdcli, Icons.flag),

            // Informações Financeiras
            sectionTitle("Informações Financeiras"),
            Row(
              children: [
                Expanded(
                  child: customContainer(
                    "Limite de Crédito",
                    formatarValor(cliente.vlrlimcrd),
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: customContainer(
                    "Saldo Disponível",
                    formatarValor(cliente.vlrsldlimcrd),
                    Icons.account_balance_wallet,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: customContainer(
                    "Duplicatas em Aberto",
                    formatarValor(cliente.vlrdplabe),
                    Icons.assignment_late,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: customContainer(
                    "Duplicatas Atrasadas",
                    formatarValor(cliente.vlrdplats),
                    Icons.assignment_late,
                  ),
                ),
              ],
            ),
            customContainer(
              "Condição de Pagamento",
              "Código: ${cliente.codcndpgt}",
              Icons.payment,
            ),
            customContainer(
              "Tabela de Preço",
              "Código: ${cliente.codtab}",
              Icons.list_alt,
            ),

            const SizedBox(height: 24),
            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: "Duplicatas",
                    icon: Icons.receipt_long,
                    onPressed: () async {
                      // Mostrar indicador de carregamento
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF5D5CDE)),
                          ),
                        ),
                      );

                      try {
                        // Buscar duplicatas da API
                        final duplicatas =
                            await _buscarDuplicatasDoCliente(cliente.codcli);

                        // Fechar o indicador de carregamento
                        Navigator.pop(context);

                        if (duplicatas.isNotEmpty) {
                          // Usa a primeira duplicata encontrada para este cliente
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DuplicataScreen(
                                duplicata: duplicatas[0],
                                cliente: cliente, // Passa o cliente completo
                              ),
                            ),
                          );
                        } else {
                          // Caso não tenha duplicatas, cria uma duplicata temporária com os dados do cliente
                          final duplicataTemp = Duplicata(
                            numdoc: "NOVA",
                            codcli: cliente.codcli,
                            dtavct: DateTime.now().toString(),
                            vlrdpl: 0,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DuplicataScreen(
                                duplicata: duplicataTemp,
                                cliente: cliente,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        // Fechar o indicador de carregamento
                        Navigator.pop(context);

                        // Mostrar erro
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Erro ao buscar duplicatas: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );

                        // Ainda assim, criar uma duplicata temporária
                        final duplicataTemp = Duplicata(
                          numdoc: "NOVA",
                          codcli: cliente.codcli,
                          dtavct: DateTime.now().toString(),
                          vlrdpl: 0,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DuplicataScreen(
                              duplicata: duplicataTemp,
                              cliente: cliente,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: "Produtos",
                    icon: Icons.shopping_cart,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Passe o cliente como parâmetro para a tela de produtos
                          builder: (context) => ProdutoScreen(cliente: cliente),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Widget para exibir status do cliente
  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = Colors.white;
    String statusText;

    // Define cores e texto com base no status
    switch (status.toUpperCase()) {
      case "A":
        backgroundColor = Colors.green;
        statusText = "Ativo";
        break;
      case "I":
        backgroundColor = Colors.red;
        statusText = "Inativo";
        break;
      case "B":
        backgroundColor = Colors.orange;
        statusText = "Bloqueado";
        break;
      default:
        backgroundColor = Colors.grey;
        statusText = status.isEmpty ? "Sem Status" : status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // Método para obter as iniciais do nome
  String _obterIniciais(String nome) {
    if (nome.isEmpty) return "?";

    List<String> partes = nome.split(' ');
    if (partes.length == 1) {
      return partes[0].substring(0, 1).toUpperCase();
    }

    return partes[0].substring(0, 1).toUpperCase() +
        partes[partes.length - 1].substring(0, 1).toUpperCase();
  }
}
