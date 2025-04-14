import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/duplicata_model.dart';
import 'package:flutter_docig_venda/services/apiDuplicata.dart';
import 'package:flutter_docig_venda/services/dao/duplicata_dao.dart';

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
  // Constantes
  final Color primaryColor = Color(0xFF5D5CDE);

  // Estado
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _usandoDadosExemplo = false;
  List<Duplicata> _duplicatas = [];

  // DAO
  final DuplicataDao _duplicataDao = DuplicataDao();

  @override
  void initState() {
    super.initState();
    _carregarDuplicatasLocal();
  }

  // CARREGAMENTO DE DADOS

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
        setState(() {
          _duplicatas = [];
          _isLoading = false;
        });
        return;
      }

      // Buscar duplicatas do cliente específico
      List<Duplicata> duplicatasDoCliente =
          await _duplicataDao.getDuplicatasByCliente(widget.duplicata.codcli);

      setState(() {
        _duplicatas = duplicatasDoCliente;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Erro ao carregar duplicatas";
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarDuplicatas() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      // Buscar duplicatas da API
      List<Duplicata> duplicatasApi =
          await DuplicataApi.buscarDuplicatas(usarDadosExemplo: true);

      if (duplicatasApi.isEmpty) {
        setState(() {
          _isSyncing = false;
          _errorMessage = "Não foi possível recuperar duplicatas";
        });
        _mostrarMensagem('Não foi possível recuperar duplicatas',
            isError: true);
        return;
      }

      // Verificar se são dados de exemplo
      bool dadosSaoExemplo =
          duplicatasApi.any((d) => d.numdoc.startsWith("TESTE"));

      // Salvar no banco local
      for (var duplicata in duplicatasApi) {
        await _duplicataDao.insertOrUpdate(duplicata.toJson(), 'numdoc');
      }

      // Recarregar duplicatas do cliente atual
      List<Duplicata> duplicatasAtualizadas =
          await _duplicataDao.getDuplicatasByCliente(widget.duplicata.codcli);

      setState(() {
        _duplicatas = duplicatasAtualizadas;
        _isSyncing = false;
        _usandoDadosExemplo = dadosSaoExemplo;
      });

      _mostrarMensagem(
          dadosSaoExemplo
              ? 'Dados de exemplo carregados'
              : 'Duplicatas sincronizadas',
          isWarning: dadosSaoExemplo);
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _errorMessage = "Erro na sincronização";
      });
      _mostrarMensagem('Erro ao sincronizar duplicatas', isError: true);
    }
  }

  // CÁLCULOS E FORMATAÇÃO

  double get _valorTotal => _duplicatas.fold(0, (sum, d) => sum + d.vlrdpl);

  double get _valorEmAberto => _duplicatas
      .where((d) => DateTime.parse(d.dtavct).isAfter(DateTime.now()))
      .fold(0, (sum, d) => sum + d.vlrdpl);

  double get _valorVencido => _duplicatas
      .where((d) => DateTime.parse(d.dtavct).isBefore(DateTime.now()))
      .fold(0, (sum, d) => sum + d.vlrdpl);

  int get _quantidadeVencidas => _duplicatas
      .where((d) => DateTime.parse(d.dtavct).isBefore(DateTime.now()))
      .length;

  String _formatarValor(double valor) {
    return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  String _formatarData(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  // UTILIDADES DE UI

  void _mostrarMensagem(String mensagem,
      {bool isError = false, bool isWarning = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError
            ? Colors.red[700]
            : isWarning
                ? Colors.orange[700]
                : primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // CONSTRUÇÃO DA UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoadingView()
          : _errorMessage != null
              ? _buildErrorView()
              : _duplicatas.isEmpty
                  ? _buildEmptyView()
                  : _buildDuplicatasView(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String nomeCliente =
        widget.cliente?.nomcli ?? "Cliente #${widget.duplicata.codcli}";
    String codigoCliente = widget.duplicata.codcli.toString();

    return AppBar(
      title: Text("Duplicatas", style: TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: primaryColor,
      elevation: 0,
      actions: [
        // Botão de sincronização
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
          tooltip: "Sincronizar",
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(_usandoDadosExemplo ? 72 : 52),
        child: Column(
          children: [
            // Informações do cliente
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nomeCliente,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
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
            // Aviso de dados de exemplo
            if (_usandoDadosExemplo)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                color: Colors.orange[700],
                child: Text(
                  "Exibindo dados de exemplo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando duplicatas',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            "Não foi possível carregar as duplicatas",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          OutlinedButton.icon(
            icon: Icon(Icons.sync),
            label: Text("Sincronizar"),
            onPressed: _sincronizarDuplicatas,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            "Nenhuma duplicata encontrada",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            "Sincronize para carregar as duplicatas",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          OutlinedButton.icon(
            icon: Icon(Icons.sync),
            label: Text("Sincronizar"),
            onPressed: _sincronizarDuplicatas,
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicatasView() {
    return Column(
      children: [
        // Resumo das duplicatas
        _buildResumoFinanceiro(),

        // Lista de duplicatas
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregarDuplicatasLocal,
            color: primaryColor,
            child: ListView.builder(
              itemCount: _duplicatas.length,
              padding: EdgeInsets.all(16),
              itemBuilder: (context, index) {
                return _buildItemDuplicata(_duplicatas[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoFinanceiro() {
    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Resumo Financeiro",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              if (_quantidadeVencidas > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[100]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${_quantidadeVencidas} vencida${_quantidadeVencidas > 1 ? 's' : ''}",
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _buildResumoValor("Total", _valorTotal, Colors.grey[800]!),
              _buildResumoValor("Em Aberto", _valorEmAberto, Colors.blue[700]!),
              _buildResumoValor("Vencido", _valorVencido, Colors.red[700]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoValor(String titulo, double valor, Color cor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 4),
          Text(
            _formatarValor(valor),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDuplicata(Duplicata duplicata) {
    bool isVencida = DateTime.parse(duplicata.dtavct).isBefore(DateTime.now());
    bool isDadoExemplo = duplicata.numdoc.startsWith("TESTE");

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        duplicata.numdoc,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                      if (isDadoExemplo)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVencida ? Colors.red[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVencida ? "Vencida" : "Em Aberto",
                      style: TextStyle(
                        color: isVencida ? Colors.red[700] : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
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
                        SizedBox(height: 2),
                        Text(
                          _formatarData(duplicata.dtavct),
                          style: TextStyle(
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
                        SizedBox(height: 2),
                        Text(
                          _formatarValor(duplicata.vlrdpl),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color:
                                isVencida ? Colors.red[700] : Colors.grey[800],
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
      ),
    );
  }
}
