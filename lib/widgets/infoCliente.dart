import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Adicionar esta importação
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/widgets/botao.dart';
import 'package:flutter_docig_venda/screens/produtoScreen.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/screens/dupricata.dart';
import 'package:flutter_docig_venda/screens/codigoScreen.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart'; // Adicionar esta importação
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class Infocliente extends StatelessWidget {
  final Cliente cliente;
  final CarrinhosDao carrinhoDao = CarrinhosDao();
  final Color primaryColor = const Color(0xFF5D5CDE);

  Infocliente({super.key, required this.cliente});

  // Método para buscar duplicatas do cliente da API
  Future<List<Duplicata>> _buscarDuplicatasDoCliente(int codcli) async {
    try {
      final baseUrl = "http://duotecsuprilev.ddns.com.br:8082";
      final url = Uri.parse("$baseUrl/v1/duplicatas/$codcli");

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => Duplicata.fromJson(item)).toList();
      } else {
        developer.log(
            "❌ Erro ${response.statusCode} ao buscar duplicatas: ${response.body}",
            name: 'Infocliente');
        return [];
      }
    } catch (e) {
      developer.log("❌ Erro na requisição: $e", name: 'Infocliente');
      return [];
    }
  }

  // Formatar valores monetários
  String formatarValor(double valor) {
    return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  // Formatar CNPJ/CPF
  String formatarDocumento(String documento) {
    if (documento.isEmpty) return "Não informado";

    if (documento.length == 14) {
      // CNPJ
      return "${documento.substring(0, 2)}.${documento.substring(2, 5)}.${documento.substring(5, 8)}/${documento.substring(8, 12)}-${documento.substring(12)}";
    } else if (documento.length == 11) {
      // CPF
      return "${documento.substring(0, 3)}.${documento.substring(3, 6)}.${documento.substring(6, 9)}-${documento.substring(9)}";
    }

    return documento;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Detalhes do Cliente",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho simplificado com informações principais
            _buildHeader(),

            // Conteúdo principal
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informações de Contato
                  _buildSectionTitle("Informações de Contato"),
                  _buildInfoRow("Telefone", cliente.numtel001, Icons.phone),
                  if (cliente.numtel002?.isNotEmpty == true)
                    _buildInfoRow("Telefone Adicional", cliente.numtel002!,
                        Icons.phone_android),
                  _buildInfoRow("E-mail", cliente.emailcli, Icons.email),
                  _buildInfoRow("CNPJ/CPF",
                      formatarDocumento(cliente.cgccpfcli), Icons.article),

                  const SizedBox(height: 16),

                  // Endereço
                  _buildSectionTitle("Endereço"),
                  _buildInfoRow(
                      "Logradouro", cliente.endcli, Icons.location_on),
                  _buildInfoRow("Bairro", cliente.baicli, Icons.location_city),
                  _buildInfoRow("Cidade", cliente.muncli, Icons.location_city),
                  _buildInfoRow("Estado", cliente.ufdcli, Icons.flag),

                  const SizedBox(height: 16),

                  // Informações Financeiras
                  _buildSectionTitle("Informações Financeiras"),
                  _buildFinancialInfoGrid(),

                  const SizedBox(height: 24),

                  // Botões de ação
                  _buildActionButtons(context),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: primaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome e código
          Text(
            cliente.nomcli,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Código: ${cliente.codcli}",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(229), // Using withAlpha instead of withOpacity
            ),
          ),
          const SizedBox(height: 12),

          // Status e limite de crédito
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(cliente.staati),
              Text(
                formatarValor(cliente.vlrlimcrd),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            color: primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    final displayValue = value.isNotEmpty ? value : "Não informado";

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }

  Widget _buildFinancialInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFinancialItem(
                  "Limite de Crédito",
                  formatarValor(cliente.vlrlimcrd),
                  Icons.account_balance_wallet),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFinancialItem("Saldo Disponível",
                  formatarValor(cliente.vlrsldlimcrd), Icons.payments),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinancialItem("Duplicatas em Aberto",
                  formatarValor(cliente.vlrdplabe), Icons.assignment),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFinancialItem("Duplicatas Atrasadas",
                  formatarValor(cliente.vlrdplats), Icons.assignment_late),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinancialItem("Condição de Pagamento",
                  "Código: ${cliente.codcndpgt}", Icons.payment),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildFinancialItem("Tabela de Preço",
                  "Código: ${cliente.codtab}", Icons.list_alt),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: "Duplicatas",
                icon: Icons.receipt_long,
                onPressed: () => _handleDuplicatasButtonPress(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: "Produtos",
                icon: Icons.shopping_cart,
                onPressed: () => _handleProdutosButtonPress(context),
              ),
            ),
          ],
        ),
        
        // Adicionado um espaçamento vertical para separação dos botões
        const SizedBox(height: 12),
        
        // Novo botão para adicionar produtos individualmente
        CustomButton(
          text: "Adicionar Produto Individual",
          icon: Icons.add_shopping_cart,
          onPressed: () => _handleAdicionarProdutoPress(context),
        ),
      ],
    );
  }

  void _handleDuplicatasButtonPress(BuildContext context) async {
    // Mostrar indicador de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          strokeWidth: 2,
        ),
      ),
    );

    try {
      // Buscar duplicatas da API
      final duplicatas = await _buscarDuplicatasDoCliente(cliente.codcli);

      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;
      
      // Fechar o indicador de carregamento
      Navigator.pop(context);

      // Criar duplicata para navegação
      final Duplicata duplicataToUse = duplicatas.isNotEmpty
          ? duplicatas[0]
          : Duplicata(
              numdoc: "NOVA",
              codcli: cliente.codcli,
              dtavct: DateTime.now().toString(),
              vlrdpl: 0,
            );

      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DuplicataScreen(
            duplicata: duplicataToUse,
            cliente: cliente,
          ),
        ),
      );
    } catch (e) {
      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;
      
      // Fechar o indicador de carregamento
      Navigator.pop(context);

      // Mostrar erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao buscar duplicatas: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Criar duplicata temporária
      final duplicataTemp = Duplicata(
        numdoc: "NOVA",
        codcli: cliente.codcli,
        dtavct: DateTime.now().toString(),
        vlrdpl: 0,
      );

      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;

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
  }

  // AQUI ESTÁ A SOLUÇÃO: Modificação do método _handleProdutosButtonPress
  void _handleProdutosButtonPress(BuildContext context) async {
    await carrinhoDao.getCarrinhoAberto(cliente.codcli);

    if (!context.mounted) return;
    
    // SOLUÇÃO: Limpar o carrinho ANTES de navegar para ProdutoScreen
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.limpar(); // <-- ESTA É A LINHA CRUCIAL!
    
    // Log para debugging (opcional)
    developer.log("CarrinhoProvider limpo ANTES de navegar para ProdutoScreen do cliente ${cliente.codcli}",
      name: 'Infocliente');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProdutoScreen(cliente: cliente),
      ),
    );
  }

  // Também devemos aplicar a mesma solução no método de adicionar produto individual
  void _handleAdicionarProdutoPress(BuildContext context) {
    // SOLUÇÃO: Limpar o carrinho ANTES de qualquer navegação que lide com produtos
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.limpar();
    
    developer.log("CarrinhoProvider limpo ANTES de adicionar produto individual para cliente ${cliente.codcli}",
      name: 'Infocliente');
    
    // Since we don't have access to the full codebase, we'll just show a placeholder message
    // Normally we would navigate to the CodigoScreen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Navegando para a tela de código para adicionar produto"),
        duration: Duration(seconds: 2),
      ),
    );
    
    // In your real implementation you would do something like:
     Navigator.push(
       context,
      MaterialPageRoute(
        builder: (context) => AdicionarProdutoScreen(cliente: cliente),
       ),
     );
  }

  // Widget para exibir status do cliente
  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    String statusText;

    // Define cores e texto com base no status
    switch (status.toUpperCase()) {
      case "A":
        backgroundColor = Colors.green;
        statusText = "Ativo";
        break;
      case "I":
        backgroundColor = Colors.red[700]!;
        statusText = "Inativo";
        break;
      case "B":
        backgroundColor = Colors.orange[700]!;
        statusText = "Bloqueado";
        break;
      default:
        backgroundColor = Colors.grey[700]!;
        statusText = status.isEmpty ? "Sem Status" : status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}