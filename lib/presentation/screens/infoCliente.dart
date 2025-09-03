import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
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
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';

class Infocliente extends StatefulWidget {
  final Cliente cliente;

  const Infocliente({super.key, required this.cliente});

  @override
  State<Infocliente> createState() => _InfoclienteState();
}

class _InfoclienteState extends State<Infocliente> {
  // Repository em vez de DAO
  CarrinhoRepository? _carrinhoRepository;
  
  final Color primaryColor = const Color(0xFF5D5CDE);
  final Color secondaryColor = const Color(0xFF7472E0);
  
  bool _isLoadingDuplicatas = false;
  List<Duplicata>? _duplicatasCache;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _initializeRepository();
        _precarregarDuplicatas();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _initializeRepository() {
    if (_isDisposed) return;
    
    // Sempre usa instância local para garantir funcionamento
    try {
      _carrinhoRepository = CarrinhoRepository(DatabaseHelper.instance);
      _isInitialized = true;
      developer.log("Repository inicializado localmente com sucesso", name: 'Infocliente');
    } catch (e) {
      developer.log("Erro ao criar repository local: $e", name: 'Infocliente');
      _isInitialized = false;
    }
  }

  Future<void> _precarregarDuplicatas() async {
    if (_isDisposed) return;
    
    if (mounted) {
      setState(() {
        _isLoadingDuplicatas = true;
      });
    }
    
    try {
      _duplicatasCache = await _buscarDuplicatasDoCliente(widget.cliente.codcli);
    } catch (e) {
      developer.log("Erro ao pré-carregar duplicatas: $e", name: 'Infocliente');
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingDuplicatas = false;
        });
      }
    }
  }

  Future<List<Duplicata>> _buscarDuplicatasDoCliente(int codcli) async {
    if (_duplicatasCache != null) {
      return _duplicatasCache!;
    }
    
    try {
      final baseUrl = "http://duotecsuprilev.ddns.com.br:8082";
      final url = Uri.parse("$baseUrl/v1/duplicatas/$codcli");

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);
        return jsonResponse.map((item) => Duplicata.fromJson(item)).toList();
      } else {
        developer.log(
          "Erro ${response.statusCode} ao buscar duplicatas: ${response.body}",
          name: 'Infocliente'
        );
        return [];
      }
    } catch (e) {
      developer.log("Erro na requisição: $e", name: 'Infocliente');
      return [];
    }
  }

  String formatarValor(double valor) {
    return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  String formatarDocumento(String documento) {
    if (documento.isEmpty) return "Não informado";

    documento = documento.replaceAll(RegExp(r'[^0-9]'), '');

    if (documento.length == 14) {
      return "${documento.substring(0, 2)}.${documento.substring(2, 5)}.${documento.substring(5, 8)}/${documento.substring(8, 12)}-${documento.substring(12)}";
    } else if (documento.length == 11) {
      return "${documento.substring(0, 3)}.${documento.substring(3, 6)}.${documento.substring(6, 9)}-${documento.substring(9)}";
    }

    return documento;
  }

  Future<void> _handleTelefonePress(String telefone) async {
    if (telefone.isEmpty) return;
    
    final Uri telUri = Uri(scheme: 'tel', path: telefone);
    
    try {
      if (await url_launcher.canLaunchUrl(telUri)) {
        await url_launcher.launchUrl(telUri);
      } else {
        if (mounted && !_isDisposed) {
          _mostrarSnackBar('Não foi possível realizar a chamada telefônica.');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
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
        if (mounted && !_isDisposed) {
          _mostrarSnackBar('Não foi possível abrir o aplicativo de e-mail.');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
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
        if (mounted && !_isDisposed) {
          _mostrarSnackBar('Não foi possível abrir o mapa.');
        }
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        _mostrarSnackBar('Erro ao tentar abrir o mapa: $e');
      }
    }
  }

  void _handleDuplicatasButtonPress(BuildContext context) async {
    if (_isDisposed) return;
    
    if (_isLoadingDuplicatas) {
      _mostrarSnackBar('Carregando duplicatas, aguarde um momento...');
      return;
    }

    if (_duplicatasCache == null) {
      setState(() {
        _isLoadingDuplicatas = true;
      });
      
      _mostrarCarregamento(context);
    }

    try {
      final duplicatas = _duplicatasCache ?? await _buscarDuplicatasDoCliente(widget.cliente.codcli);
      _duplicatasCache = duplicatas;

      if (!context.mounted || _isDisposed) return;
      
      if (_duplicatasCache == null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      final Duplicata duplicataToUse = duplicatas.isNotEmpty
          ? duplicatas[0]
          : Duplicata(
              numdoc: "NOVA",
              codcli: widget.cliente.codcli,
              dtavct: DateTime.now().toString(),
              vlrdpl: 0,
            );

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
      if (!context.mounted || _isDisposed) return;
      
      if (_duplicatasCache == null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _mostrarSnackBar("Erro ao buscar duplicatas: $e");

      final duplicataTemp = Duplicata(
        numdoc: "NOVA",
        codcli: widget.cliente.codcli,
        dtavct: DateTime.now().toString(),
        vlrdpl: 0,
      );

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
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoadingDuplicatas = false;
        });
      }
    }
  }

  void _handleProdutosButtonPress(BuildContext context) {
    if (_isDisposed) return;
    
    try {
      // Verificar se o context ainda é válido
      if (!mounted) return;
      
      // Adicionar log para debug
      developer.log("Navegando para produtos - Cliente: ${widget.cliente.codcli}", name: 'Infocliente');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProdutoScreenWrapper(cliente: widget.cliente),
        ),
      ).catchError((error) {
        developer.log("Erro na navegação push: $error", name: 'Infocliente');
        if (mounted && !_isDisposed) {
          _mostrarSnackBar("Erro ao abrir tela de produtos: $error");
        }
        return null;
      });
    } catch (e) {
      _mostrarSnackBar("Erro ao navegar para produtos: $e");
      developer.log("Erro na navegação para produtos: $e", name: 'Infocliente');
    }
  }

  void _handleAdicionarProdutoPress(BuildContext context) {
    if (_isDisposed) return;
    
    if (!mounted) return;
    
    // Use o wrapper se você quiser limpar o carrinho
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdicionarProdutoScreenWrapper(cliente: widget.cliente),
      ),
    );
  }

  void _mostrarSnackBar(String mensagem) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.grey[800],
          duration: const Duration(seconds: 3),
        ),
      );
  }
  
  void _mostrarCarregamento(BuildContext context) {
    if (_isDisposed) return;
    
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
                ),
                const SizedBox(height: 16),
                const Text("Carregando dados..."),
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Compartilhar',
            onPressed: () => _mostrarSnackBar('Compartilhar dados do cliente'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_isDisposed) return;
          _duplicatasCache = null;
          await _precarregarDuplicatas();
          if (mounted && !_isDisposed) {
            _mostrarSnackBar('Dados atualizados');
          }
        },
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
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
          _buildInformationCards(),
          
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
          Expanded(
            child: _buildInfoCard(
              icon: Icons.person_outlined,
              title: "Status",
              content: _getStatusText(widget.cliente.staati),
              color: _getStatusColor(widget.cliente.staati),
            ),
          ),
          const SizedBox(width: 8),
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
        side: BorderSide(color: Colors.grey[200]!),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
              Icon(icon, size: 18, color: color ?? primaryColor),
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

// Wrappers seguros para navegação
// PARTE MODIFICADA: Apenas os wrappers que estão causando o problema

// WRAPPER CORRIGIDO - SEM LOOP INFINITO
class ProdutoScreenWrapper extends StatefulWidget {
  final Cliente cliente;

  const ProdutoScreenWrapper({super.key, required this.cliente});

  @override
  State<ProdutoScreenWrapper> createState() => _ProdutoScreenWrapperState();
}

class _ProdutoScreenWrapperState extends State<ProdutoScreenWrapper> {
  bool _isDisposed = false;
  bool _carrinhoLimpo = false; // CRÍTICO: Flag para controlar limpeza única

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    developer.log("ProdutoScreenWrapper iniciado para cliente ${widget.cliente.codcli}", 
        name: 'ProdutoScreenWrapper');
    
    try {
      // Verificar se Provider está disponível
      final carrinho = Provider.of<Carrinho>(context, listen: false);
      developer.log("Provider<Carrinho> encontrado", name: 'ProdutoScreenWrapper');
      
      // CRÍTICO: Limpa carrinho apenas UMA VEZ
      if (!_carrinhoLimpo && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted && !_carrinhoLimpo) {
            try {
              developer.log("Limpando carrinho uma única vez...", name: 'ProdutoScreenWrapper');
              carrinho.limpar();
              _carrinhoLimpo = true; // MARCA COMO LIMPO
              developer.log("Carrinho limpo com sucesso", name: 'ProdutoScreenWrapper');
            } catch (e) {
              developer.log("Erro ao limpar carrinho: $e", name: 'ProdutoScreenWrapper');
            }
          }
        });
      }
      
    } catch (e) {
      developer.log("ERRO: Provider<Carrinho> não encontrado: $e", name: 'ProdutoScreenWrapper');
      return _buildErrorScreen("Provider<Carrinho> não encontrado", "$e");
    }
    
    // CRÍTICO: Retorna diretamente sem Consumer
    try {
      developer.log("Criando ProdutoScreen diretamente...", name: 'ProdutoScreenWrapper');
      return ProdutoScreen(cliente: widget.cliente);
    } catch (e) {
      developer.log("ERRO ao criar ProdutoScreen: $e", name: 'ProdutoScreenWrapper');
      return _buildErrorScreen("Erro ao carregar tela de produtos", "$e");
    }
  }

  Widget _buildErrorScreen(String title, String message) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Erro - $title"),
        backgroundColor: const Color(0xFF5D5CDE),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(title),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Voltar"),
            ),
          ],
        ),
      ),
    );
  }
}

// WRAPPER ADICIONAL TAMBÉM CORRIGIDO
class AdicionarProdutoScreenWrapper extends StatefulWidget {
  final Cliente cliente;

  const AdicionarProdutoScreenWrapper({super.key, required this.cliente});

  @override
  State<AdicionarProdutoScreenWrapper> createState() => _AdicionarProdutoScreenWrapperState();
}

class _AdicionarProdutoScreenWrapperState extends State<AdicionarProdutoScreenWrapper> {
  bool _isDisposed = false;
  bool _carrinhoLimpo = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      final carrinho = Provider.of<Carrinho>(context, listen: false);
      
      // Limpa carrinho apenas uma vez
      if (!_carrinhoLimpo && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDisposed && mounted && !_carrinhoLimpo) {
            try {
              carrinho.limpar();
              _carrinhoLimpo = true;
              developer.log("Carrinho limpo para adicionar produto individual", 
                  name: 'AdicionarProdutoScreenWrapper');
            } catch (e) {
              developer.log("Erro ao limpar carrinho: $e", name: 'AdicionarProdutoScreenWrapper');
            }
          }
        });
      }
      
      return AdicionarProdutoScreen(cliente: widget.cliente);
      
    } catch (e) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Erro"),
          backgroundColor: const Color(0xFF5D5CDE),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text("Erro ao acessar carrinho"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Voltar"),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Classe _ClienteHeaderDelegate - DEVE estar fora da classe _InfoclienteState
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
      elevation: isCollapsed ? 4 : 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Título do cliente com animação
                AnimatedOpacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    cliente.nomcli,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Código do cliente sempre visível
                const SizedBox(height: 4),
                Text(
                  "Cliente #${cliente.codcli}",
                  style: TextStyle(
                    fontSize: isCollapsed ? 16 : 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: isCollapsed ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                
                // Informações resumidas que aparecem quando expandido
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: isCollapsed ? 0 : 40,
                  child: AnimatedOpacity(
                    opacity: isCollapsed ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "${cliente.muncli} - ${cliente.ufdcli}",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatarValor(cliente.vlrlimcrd),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}