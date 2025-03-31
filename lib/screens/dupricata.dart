import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/services/apiDuplicata.dart'; // Para sincronização
import 'package:flutter_docig_venda/services/dao/duplicata_dao.dart'; // DAO para acesso local

class DuplicataScreen extends StatefulWidget {
  final Duplicata duplicata;
  final Cliente? cliente;

  const DuplicataScreen({
    Key? key,
    required this.duplicata,
    this.cliente,
  }) : super(key: key);

  @override
  _DuplicataScreenState createState() => _DuplicataScreenState();
}

class _DuplicataScreenState extends State<DuplicataScreen> {
  bool _isLoading = false;
  bool _isSyncing = false; // Flag para controlar estado de sincronização
  String? _errorMessage;

  // Lista de todas as duplicatas
  List<Duplicata> _todasDuplicatas = [];

  // Instância do DAO
  final DuplicataDao _duplicataDao = DuplicataDao();

  @override
  void initState() {
    super.initState();
    _carregarDuplicatasLocal();
  }

  // Método para carregar duplicatas do banco de dados local
  Future<void> _carregarDuplicatasLocal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verificar se existem duplicatas no banco de dados
      final db = await _duplicataDao.database;
      List<Map<String, dynamic>> countResult = await db
          .rawQuery('SELECT COUNT(*) as count FROM ${_duplicataDao.tableName}');
      final int duplicatasCount = countResult.first['count'] as int;

      if (duplicatasCount == 0) {
        // Se não houver duplicatas, atualizar estado e mostrar mensagem
        setState(() {
          _todasDuplicatas = [];
          _isLoading = false;
          _errorMessage = null;
        });
        return;
      }

      // Buscar duplicatas do cliente específico
      List<Duplicata> duplicatasDoCliente =
          await _duplicataDao.getDuplicatasByCliente(widget.duplicata.codcli);

      setState(() {
        _todasDuplicatas = duplicatasDoCliente;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Erro ao buscar duplicatas locais: $e");
      setState(() {
        _errorMessage = "Erro ao carregar duplicatas locais: $e";
        _isLoading = false;
      });
    }
  }

  // Método para sincronizar com a API
  Future<void> _sincronizarDuplicatas() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      // Buscar duplicatas da API
      List<Duplicata> duplicatasApi =
          await DuplicataApi.buscarDuplicatasPorCliente(
              widget.duplicata.codcli);

      // Se não conseguir dados da API, manter os dados locais
      if (duplicatasApi.isEmpty) {
        setState(() {
          _isSyncing = false;
          _errorMessage = "Não foi possível recuperar duplicatas da API";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível recuperar duplicatas do servidor'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Salvar duplicatas no banco local
      for (var duplicata in duplicatasApi) {
        await _duplicataDao.insertOrUpdate(duplicata.toJson(), 'numdoc');
      }

      // Recarregar duplicatas locais
      List<Duplicata> duplicatasAtualizadas =
          await _duplicataDao.getDuplicatasByCliente(widget.duplicata.codcli);

      setState(() {
        _todasDuplicatas = duplicatasAtualizadas;
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicatas sincronizadas com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("❌ Erro na sincronização: $e");
      setState(() {
        _isSyncing = false;
        _errorMessage = "Erro ao sincronizar: $e";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar duplicatas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Calcular valores totais
  double get _valorTotal =>
      _todasDuplicatas.fold(0, (sum, d) => sum + d.vlrdpl);

  double get _valorEmAberto => _todasDuplicatas
      .where((d) => DateTime.parse(d.dtavct).isAfter(DateTime.now()))
      .fold(0, (sum, d) => sum + d.vlrdpl);

  double get _valorVencido => _todasDuplicatas
      .where((d) => DateTime.parse(d.dtavct).isBefore(DateTime.now()))
      .fold(0, (sum, d) => sum + d.vlrdpl);

  int get _quantidadeVencidas => _todasDuplicatas
      .where((d) => DateTime.parse(d.dtavct).isBefore(DateTime.now()))
      .length;

  @override
  Widget build(BuildContext context) {
    // Obter informações do cliente atual
    String nomeCliente =
        widget.cliente?.nomcli ?? "Cliente #${widget.duplicata.codcli}";
    String codigoCliente = widget.duplicata.codcli.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text("Duplicatas"),
        backgroundColor: Color(0xFF5D5CDE),
        elevation: 0,
        actions: [
          // Botão de sincronização com a API
          IconButton(
            icon: _isSyncing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.sync),
            onPressed: _isSyncing ? null : _sincronizarDuplicatas,
            tooltip: "Sincronizar com a API",
          ),
          // Botão para recarregar dados locais
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _carregarDuplicatasLocal,
            tooltip: "Atualizar duplicatas",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60), // Cabeçalho do cliente
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            width: double.infinity,
            color: Colors.white.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeCliente,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  "Código: $codigoCliente",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? _buildErrorState()
              : _todasDuplicatas.isEmpty
                  ? _buildEmptyState()
                  : _buildDuplicatasList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando duplicatas...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 70,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            "Erro ao carregar duplicatas",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage ?? "Ocorreu um erro desconhecido.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text("Tentar novamente"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF5D5CDE),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _carregarDuplicatasLocal,
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                icon: Icon(Icons.sync),
                label: Text("Sincronizar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _sincronizarDuplicatas,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 70,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            "Nenhuma duplicata encontrada",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Não foram encontradas duplicatas para este cliente no banco local.",
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.sync),
            label: Text("Sincronizar com API"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5D5CDE),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _sincronizarDuplicatas,
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicatasList() {
    return Column(
      children: [
        // Resumo das duplicatas
        _buildResumoDuplicatas(),

        // Lista de duplicatas
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregarDuplicatasLocal,
            color: Color(0xFF5D5CDE),
            child: ListView.builder(
              itemCount: _todasDuplicatas.length,
              padding: EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildDuplicataCard(_todasDuplicatas[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicataCard(Duplicata duplicata) {
    // Determina se a duplicata está vencida
    bool isVencida = DateTime.parse(duplicata.dtavct).isBefore(DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Duplicata: ${duplicata.numdoc}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVencida
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVencida
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isVencida ? "Vencida" : "Em Aberto",
                    style: TextStyle(
                      color: isVencida ? Colors.red : Colors.blue,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Vencimento",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _formatDate(duplicata.dtavct),
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Valor",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "R\$ ${duplicata.vlrdpl.toStringAsFixed(2).replaceAll('.', ',')}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              isVencida ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return dateString; // Retorna a string original se não conseguir formatar
    }
  }

  Widget _buildResumoDuplicatas() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Resumo Financeiro",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D5CDE),
                ),
              ),
              // Usando _quantidadeVencidas para resolver o warning amarelo
              if (_quantidadeVencidas > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    "${_quantidadeVencidas} ${_quantidadeVencidas == 1 ? 'vencida' : 'vencidas'}",
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              _buildResumoCaixaValor("Total", _valorTotal, Colors.blue[700]!,
                  Icons.account_balance_wallet),
              SizedBox(width: 8),
              _buildResumoCaixaValor("Em Aberto", _valorEmAberto,
                  Colors.green[700]!, Icons.pending_actions),
              SizedBox(width: 8),
              _buildResumoCaixaValor(
                  "Vencido", _valorVencido, Colors.red[700]!, Icons.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCaixaValor(
      String titulo, double valor, Color cor, IconData icone) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 14, color: cor),
                SizedBox(width: 4),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: cor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
