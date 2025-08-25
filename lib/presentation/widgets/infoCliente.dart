import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/services/dao/carrinho_dao.dart';
import 'package:flutter_docig_venda/presentation/widgets/botao.dart';
import 'package:flutter_docig_venda/presentation/screens/produtoScreen.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/presentation/screens/dupricata.dart';
import 'package:flutter_docig_venda/presentation/screens/codigoScreen.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class Infocliente extends StatefulWidget {
  final Cliente cliente;

  const Infocliente({super.key, required this.cliente});

  @override
  State<Infocliente> createState() => _InfoclienteState();
}

class _InfoclienteState extends State<Infocliente> {
  final CarrinhosDao carrinhoDao = CarrinhosDao();
  final Color primaryColor = const Color(0xFF5D5CDE);
  final Color secondaryColor = const Color(0xFF7472E0);
  
  bool _isLoadingDuplicatas = false;
  List<Duplicata>? _duplicatasCache;

  @override
  void initState() {
    super.initState();
    // Pré-carregar duplicatas para uso posterior
    _precarregarDuplicatas();
  }

  Future<void> _precarregarDuplicatas() async {
    if (mounted) {
      setState(() {
        _isLoadingDuplicatas = true;
      });
    }
    
    try {
      _duplicatasCache = await _buscarDuplicatasDoCliente(widget.cliente.codcli);
    } catch (e) {
      developer.log("❌ Erro ao pré-carregar duplicatas: $e", name: 'Infocliente');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDuplicatas = false;
        });
      }
    }
  }

  // Método para buscar duplicatas do cliente da API
  Future<List<Duplicata>> _buscarDuplicatasDoCliente(int codcli) async {
    // Retorna o cache se disponível
    if (_duplicatasCache != null) {
      return _duplicatasCache!;
    }
    
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

  // Manipuladores de eventos
  Future<void> _handleTelefonePress(String telefone) async {
    if (telefone.isEmpty) return;
    
    final Uri telUri = Uri(scheme: 'tel', path: telefone);
    
    try {
      if (await url_launcher.canLaunchUrl(telUri)) {
        await url_launcher.launchUrl(telUri);
      } else {
        if (mounted) {
          _mostrarSnackBar('Não foi possível realizar a chamada telefônica.');
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Erro ao tentar ligar: $e');
      }
    }
  }
  
  Future<void> _handleEmailPress(String email) async {
    if (email.isEmpty) return;
    
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    
    try {
      if (await url_launcher.canLaunchUrl(emailUri)) {
        await url_launcher.launchUrl(emailUri);
      } else {
        if (mounted) {
          _mostrarSnackBar('Não foi possível abrir o aplicativo de e-mail.');
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Erro ao tentar enviar e-mail: $e');
      }
    }
  }
  
  Future<void> _handleMapPress() async {
    final endereco = "${widget.cliente.endcli}, ${widget.cliente.baicli}, ${widget.cliente.muncli}, ${widget.cliente.ufdcli}";
    final Uri mapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(endereco)}");
    
    try {
      if (await url_launcher.canLaunchUrl(mapsUri)) {
        await url_launcher.launchUrl(mapsUri, mode: url_launcher.LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _mostrarSnackBar('Não foi possível abrir o mapa.');
        }
      }
    } catch (e) {
      if (mounted) {
        _mostrarSnackBar('Erro ao tentar abrir o mapa: $e');
      }
    }
  }

  void _handleDuplicatasButtonPress(BuildContext context) async {
    // Utilizar o cache se disponível, caso contrário, buscar novamente
    if (_isLoadingDuplicatas) {
      _mostrarSnackBar('Carregando duplicatas, aguarde um momento...');
      return;
    }

    // Mostrar indicador de carregamento apenas se não tivermos cache
    if (_duplicatasCache == null) {
      setState(() {
        _isLoadingDuplicatas = true;
      });
      
      // Mostrar overlay de carregamento
      _mostrarCarregamento(context);
    }

    try {
      // Buscar duplicatas da API se necessário
      final duplicatas = _duplicatasCache ?? await _buscarDuplicatasDoCliente(widget.cliente.codcli);
      _duplicatasCache = duplicatas; // Atualizar o cache

      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;
      
      // Fechar o indicador de carregamento se estiver aberto
      if (_duplicatasCache == null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Criar duplicata para navegação
      final Duplicata duplicataToUse = duplicatas.isNotEmpty
          ? duplicatas[0]
          : Duplicata(
              numdoc: "NOVA",
              codcli: widget.cliente.codcli,
              dtavct: DateTime.now().toString(),
              vlrdpl: 0,
            );

      // Navegar para a tela de duplicatas
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DuplicataScreen(
            duplicata: duplicataToUse,
            cliente: widget.cliente,
          ),
        ),
      );
    } catch (e) {
      // Verificar se o contexto ainda é válido
      if (!context.mounted) return;
      
      // Fechar o indicador de carregamento se estiver aberto
      if (_duplicatasCache == null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Mostrar erro
      _mostrarSnackBar("Erro ao buscar duplicatas: $e");

      // Criar duplicata temporária
      final duplicataTemp = Duplicata(
        numdoc: "NOVA",
        codcli: widget.cliente.codcli,
        dtavct: DateTime.now().toString(),
        vlrdpl: 0,
      );

      // Navegar para a tela de duplicatas
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DuplicataScreen(
            duplicata: duplicataTemp,
            cliente: widget.cliente,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDuplicatas = false;
        });
      }
    }
  }

  void _handleProdutosButtonPress(BuildContext context) async {
    try {
      await carrinhoDao.getCarrinhoAberto(widget.cliente.codcli);

      if (!context.mounted) return;
      
      // Limpar o carrinho ANTES de navegar
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.limpar();
      
      // Log para debugging
      developer.log("CarrinhoProvider limpo ANTES de navegar para ProdutoScreen do cliente ${widget.cliente.codcli}",
        name: 'Infocliente');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProdutoScreen(cliente: widget.cliente),
        ),
      );
    } catch (e) {
      _mostrarSnackBar("Erro ao preparar produtos: $e");
    }
  }

  void _handleAdicionarProdutoPress(BuildContext context) {
    try {
      // Limpar o carrinho ANTES de qualquer navegação que lide com produtos
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.limpar();
      
      developer.log("CarrinhoProvider limpo ANTES de adicionar produto individual para cliente ${widget.cliente.codcli}",
        name: 'Infocliente');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdicionarProdutoScreen(cliente: widget.cliente),
        ),
      );
    } catch (e) {
      _mostrarSnackBar("Erro ao navegar para adição de produto: $e");
    }
  }

  void _mostrarSnackBar(String mensagem) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  void _mostrarCarregamento(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Carregando dados...",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Detalhes do Cliente",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
        actions: [
          // Botão para compartilhar informações do cliente
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Compartilhar dados do cliente',
            onPressed: () {
              // Implementação futura
              _mostrarSnackBar('Compartilhar dados do cliente');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Recarregar duplicatas ao fazer pull-to-refresh
          _duplicatasCache = null;
          await _precarregarDuplicatas();
          if (mounted) {
            _mostrarSnackBar('Dados atualizados');
          }
        },
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Cabeçalho com informações principais
            SliverPersistentHeader(
              pinned: true, // Mantém o cabeçalho visível ao rolar
              delegate: _ClienteHeaderDelegate(
                cliente: widget.cliente,
                primaryColor: primaryColor,
                formatarValor: formatarValor,
                expandedHeight: 180.0,
              ),
            ),
            
            SliverToBoxAdapter(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      // Botão de ação flutuante para iniciar um novo pedido
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleProdutosButtonPress(context),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.shopping_cart_checkout),
        label: const Text("Novo Pedido"),
        elevation: 4,
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartões informativos
          _buildInformationCards(),
          
          // Informações do cliente
          const SizedBox(height: 8),
          _buildSectionTitle("Informações de Contato"),
          _buildContactInfo(),
          
          const SizedBox(height: 16),
          _buildSectionTitle("Endereço"),
          _buildAddressInfo(),

          const SizedBox(height: 16),
          _buildSectionTitle("Informações Financeiras"),
          _buildFinancialInfo(),
          
          const SizedBox(height: 24),
          _buildActionButtons(),
          
          // Espaço adicional no final para não cobrir o conteúdo com o FAB
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInformationCards() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          // Status do cliente
          Expanded(
            child: _buildInfoCard(
              icon: Icons.person_outlined,
              title: "Status",
              content: _getStatusText(widget.cliente.staati),
              color: _getStatusColor(widget.cliente.staati),
            ),
          ),
          const SizedBox(width: 8),
          // Limite de crédito
          Expanded(
            child: _buildInfoCard(
              icon: Icons.credit_card_outlined,
              title: "Limite de Crédito",
              content: formatarValor(widget.cliente.vlrlimcrd),
              color: Colors.green[700]!,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case "A": return "Ativo";
      case "I": return "Inativo";
      case "B": return "Bloqueado";
      default: return status.isEmpty ? "Sem Status" : status;
    }
  }
  
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case "A": return Colors.green[700]!;
      case "I": return Colors.red[700]!;
      case "B": return Colors.orange[700]!;
      default: return Colors.grey[700]!;
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Telefone principal
            _buildContactItem(
              icon: Icons.phone,
              label: "Telefone",
              value: widget.cliente.numtel001,
              onTap: () => _handleTelefonePress(widget.cliente.numtel001),
            ),
            if (widget.cliente.numtel002?.isNotEmpty == true) ...[
              const Divider(height: 16),
              _buildContactItem(
                icon: Icons.phone_android,
                label: "Telefone Adicional",
                value: widget.cliente.numtel002!,
                onTap: () => _handleTelefonePress(widget.cliente.numtel002!),
              ),
            ],
            const Divider(height: 16),
            _buildContactItem(
              icon: Icons.email,
              label: "E-mail",
              value: widget.cliente.emailcli,
              onTap: () => _handleEmailPress(widget.cliente.emailcli),
            ),
            const Divider(height: 16),
            _buildContactItem(
              icon: Icons.article,
              label: "CNPJ/CPF",
              value: formatarDocumento(widget.cliente.cgccpfcli),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    final displayValue = value.isNotEmpty ? value : "Não informado";
    final isValueAvailable = value.isNotEmpty;
    
    return InkWell(
      onTap: isValueAvailable ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isValueAvailable ? primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isValueAvailable ? Colors.grey[800] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isValueAvailable && onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfo() {
    final hasAddress = widget.cliente.endcli.isNotEmpty;
    
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressField("Logradouro", widget.cliente.endcli),
                      const SizedBox(height: 12),
                      _buildAddressField("Bairro", widget.cliente.baicli),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAddressField("Cidade", widget.cliente.muncli),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: _buildAddressField("UF", widget.cliente.ufdcli),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasAddress) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _handleMapPress,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text("Ver no Mapa"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressField(String label, String value) {
    final displayValue = value.isNotEmpty ? value : "Não informado";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayValue,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: value.isNotEmpty ? Colors.grey[800] : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialInfo() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Primeira linha
            Row(
              children: [
                Expanded(
                  child: _buildFinancialItem(
                    "Limite de Crédito",
                    formatarValor(widget.cliente.vlrlimcrd),
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialItem(
                    "Saldo Disponível",
                    formatarValor(widget.cliente.vlrsldlimcrd),
                    Icons.payments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Segunda linha
            Row(
              children: [
                Expanded(
                  child: _buildFinancialItem(
                    "Duplicatas em Aberto",
                    formatarValor(widget.cliente.vlrdplabe),
                    Icons.assignment,
                    color: widget.cliente.vlrdplabe > 0 ? Colors.orange[700] : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialItem(
                    "Duplicatas Atrasadas",
                    formatarValor(widget.cliente.vlrdplats),
                    Icons.assignment_late,
                    color: widget.cliente.vlrdplats > 0 ? Colors.red[700] : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Terceira linha
            Row(
              children: [
                Expanded(
                  child: _buildFinancialItem(
                    "Condição de Pagamento",
                    "Código: ${widget.cliente.codcndpgt}",
                    Icons.payment,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFinancialItem(
                    "Tabela de Preço",
                    "Código: ${widget.cliente.codtab}",
                    Icons.list_alt,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialItem(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                icon, 
                size: 18, 
                color: color ?? primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                text: "Duplicatas",
                icon: Icons.receipt_long,
                isPrimary: true,
                isLoading: _isLoadingDuplicatas,
                onPressed: () => _handleDuplicatasButtonPress(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                text: "Produtos",
                icon: Icons.shopping_cart,
                isPrimary: true,
                onPressed: () => _handleProdutosButtonPress(context),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        _buildActionButton(
          text: "Adicionar Produto Individual",
          icon: Icons.add_shopping_cart,
          isPrimary: false,
          onPressed: () => _handleAdicionarProdutoPress(context),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading 
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPrimary ? Colors.white : primaryColor,
                ),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? primaryColor : Colors.white,
        foregroundColor: isPrimary ? Colors.white : primaryColor,
        elevation: isPrimary ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary 
              ? BorderSide.none 
              : BorderSide(color: primaryColor),
        ),
      ),
    );
  }
}

// Classe para o cabeçalho persistente com efeito de colapso
class _ClienteHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Cliente cliente;
  final Color primaryColor;
  final double expandedHeight;
  final Function(double) formatarValor;

  _ClienteHeaderDelegate({
    required this.cliente,
    required this.primaryColor,
    required this.formatarValor,
    required this.expandedHeight,
  });

  @override
  double get minExtent => 120.0;
  
  @override
  double get maxExtent => expandedHeight;

  @override
  bool shouldRebuild(covariant _ClienteHeaderDelegate oldDelegate) {
    return oldDelegate.cliente != cliente || 
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.expandedHeight != expandedHeight;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double progress = shrinkOffset / (maxExtent - minExtent);
    final bool isCollapsed = progress > 0.5;
    
    return Material(
      color: primaryColor,
      elevation: 4.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradiente de fundo
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor,
                  Color.lerp(primaryColor, Colors.black, 0.2)!,
                ],
              ),
            ),
          ),
          
          // Conteúdo que aparece quando expandido
          Opacity(
            opacity: 1.0 - progress,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      cliente.nomcli,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Código: ${cliente.codcli}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (cliente.staati.isNotEmpty)
                          _buildStatusChip(cliente.staati),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Limite: ${formatarValor(cliente.vlrlimcrd)}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Conteúdo que aparece quando colapsado
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: progress,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                titleSpacing: 0,
                title: Opacity(
                  opacity: isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    cliente.nomcli,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
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
        backgroundColor = Colors.green[700]!;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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