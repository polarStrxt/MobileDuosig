import 'package:logger/logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/services/vendas_service.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/models/duplicata_model.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';

class DuplicataScreen extends StatefulWidget {
  final Duplicata duplicata;
  final Cliente? cliente;

  const DuplicataScreen({
    super.key,
    required this.duplicata,
    this.cliente,
  });

  @override
  DuplicataScreenState createState() => DuplicataScreenState();
}

class DuplicataScreenState extends State<DuplicataScreen> {
  // Constantes
  static const Color _primaryColor = Color(0xFF5D5CDE);

  // Repositórios - inicialização direta
  RepositoryManager? _repositoryManager;
  VendasService? _vendasService;
  final Logger _logger = Logger();

  // Estado
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<Duplicata> _duplicatas = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // CORREÇÃO CRÍTICA: Aguardar o primeiro frame para garantir que o Provider esteja disponível
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeSystemCompleto();
      }
    });
  }

  /// Método de inicialização atualizado com melhor tratamento de erros
  Future<void> _initializeSystemCompleto() async {
    if (!mounted) return;
    
    try {
      _logger.i("🚀 Iniciando inicialização do DuplicataScreen...");
      
      await _initializeRepositories();
      
      if (_isInitialized && mounted) {
        await _debugDatabase();
        await _carregarDuplicatasCompleto();
      }
    } catch (e, stackTrace) {
      _logger.e("❌ Erro na inicialização completa", error: e, stackTrace: stackTrace);
      
      if (mounted) {
        setState(() {
          _errorMessage = "Erro na inicialização: ${_simplificarErro(e)}";
          _isLoading = false;
        });
      }
    }
  }

  /// CORREÇÃO PRINCIPAL: Inicialização mais robusta dos repositórios
  Future<void> _initializeRepositories() async {
    if (!mounted) return;
    
    try {
      _logger.i("📁 Inicializando repositórios...");
      
      // PASSO 1: Inicializar RepositoryManager sempre primeiro
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.database;
      _repositoryManager = RepositoryManager(dbHelper);
      _logger.i("✅ RepositoryManager inicializado");
      
      // PASSO 2: Tentar obter VendasService do Provider
      try {
        if (mounted) {
          _vendasService = Provider.of<VendasService>(context, listen: false);
          _logger.i("✅ VendasService obtido via Provider");
        }
      } catch (providerError) {
        _logger.w("⚠️ VendasService não disponível via Provider: $providerError");
        
        // PASSO 3: Fallback - criar VendasService manualmente
        try {
          final apiClient = UnifiedApiClient(
            baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
            codigoVendedor: '001',
            timeout: const Duration(seconds: 30),
          );
          _vendasService = VendasService(apiClient: apiClient);
          _logger.i("✅ VendasService criado via fallback");
        } catch (fallbackError) {
          _logger.e("❌ Fallback do VendasService falhou: $fallbackError");
          // Continua sem VendasService - usar apenas dados locais
        }
      }
      
      // PASSO 4: Validar estado final
      if (_repositoryManager != null) {
        _isInitialized = true;
        _logger.i("🎯 Inicialização concluída com sucesso!");
        _logger.i("   - RepositoryManager: ✅");
        _logger.i("   - VendasService: ${_vendasService != null ? '✅' : '⚠️ Fallback'}");
      } else {
        throw Exception("RepositoryManager não foi inicializado");
      }
      
    } catch (e, stackTrace) {
      _logger.e("❌ Erro crítico na inicialização dos repositórios", error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Debug do banco de dados com verificações de segurança
  Future<void> _debugDatabase() async {
    if (_repositoryManager == null) {
      _logger.w("⚠️ RepositoryManager não disponível para debug");
      return;
    }
    
    try {
      _logger.i("🔍 === DEBUG DO BANCO DE DADOS ===");
      final db = await _repositoryManager!.dbHelper.database;
      
      // 1. Verificar estrutura das tabelas
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      _logger.i("📋 Tabelas disponíveis: ${tables.map((t) => t['name']).join(', ')}");
      
      // 2. Verificar tabela duplicata especificamente
      final duplicataTable = tables.where((t) => t['name'] == 'duplicata').toList();
      if (duplicataTable.isEmpty) {
        _logger.e("❌ PROBLEMA: Tabela 'duplicata' não existe!");
        _logger.i("💡 Sugestão: Execute a sincronização inicial do sistema");
        return;
      }
      
      // 3. Contar registros
      final count = await db.rawQuery("SELECT COUNT(*) as count FROM duplicata");
      final totalDuplicatas = count.first['count'] as int;
      _logger.i("📊 Total de duplicatas no banco: $totalDuplicatas");
      
      // 4. Verificar dados do cliente específico
      final clienteCount = await db.rawQuery(
        "SELECT COUNT(*) as count FROM duplicata WHERE codcli = ?",
        [widget.duplicata.codcli]
      );
      final duplicatasDoCliente = clienteCount.first['count'] as int;
      _logger.i("🎯 Duplicatas do cliente ${widget.duplicata.codcli}: $duplicatasDoCliente");
      
      // 5. Amostragem de dados se houver registros
      if (totalDuplicatas > 0) {
        final samples = await db.query("duplicata", limit: 3);
        _logger.i("📝 Amostras de duplicatas:");
        for (int i = 0; i < samples.length; i++) {
          final d = samples[i];
          _logger.i("  ${i + 1}. Cliente: ${d['codcli']} | Doc: ${d['numdoc']} | Valor: R\$ ${d['vlrdpl']}");
        }
      }
      
      _logger.i("🔍 === FIM DO DEBUG ===");
      
    } catch (e, stackTrace) {
      _logger.e("❌ Erro no debug do banco", error: e, stackTrace: stackTrace);
    }
  }

  /// Busca de duplicatas com fallbacks aprimorados
  Future<List<Duplicata>> _buscarDuplicatasCompleto(int codcli) async {
    _logger.i("🔍 Buscando duplicatas para cliente $codcli...");
    
    if (_repositoryManager == null) {
      _logger.e("❌ RepositoryManager não disponível");
      return [];
    }
    
    try {
      // MÉTODO 1: Usar repositório (preferido)
      final duplicatas = await _repositoryManager!.duplicatas.getDuplicatasByCliente(codcli);
      _logger.i("📋 Repositório encontrou: ${duplicatas.length} duplicatas");
      
      if (duplicatas.isNotEmpty) {
        return duplicatas;
      }
      
      // MÉTODO 2: Query direta como fallback
      _logger.w("⚠️ Repositório retornou vazio, tentando query direta...");
      final db = await _repositoryManager!.dbHelper.database;
      
      final result = await db.query(
        'duplicata',
        where: 'codcli = ?',
        whereArgs: [codcli],
        orderBy: 'dtavct DESC',
      );
      
      final duplicatasFallback = result.map((json) => Duplicata.fromJson(json)).toList();
      _logger.i("🔄 Query direta encontrou: ${duplicatasFallback.length} duplicatas");
      
      return duplicatasFallback;
      
    } catch (e, stackTrace) {
      _logger.e("❌ Erro ao buscar duplicatas", error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Carregamento de duplicatas com estado adequado
  Future<void> _carregarDuplicatasCompleto() async {
    if (!mounted || !_isInitialized) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.i("📥 Iniciando carregamento de duplicatas...");
      
      final duplicatas = await _buscarDuplicatasCompleto(widget.duplicata.codcli);

      if (mounted) {
        setState(() {
          _duplicatas = duplicatas;
          _isLoading = false;
        });
        
        _logger.i("✅ Carregamento concluído: ${duplicatas.length} duplicatas");
        
        if (duplicatas.isEmpty) {
          _logger.i("ℹ️ Nenhuma duplicata encontrada para o cliente");
        }
      }

    } catch (e, stackTrace) {
      _logger.e("❌ Erro no carregamento", error: e, stackTrace: stackTrace);
      
      if (mounted) {
        setState(() {
          _errorMessage = "Erro ao carregar duplicatas: ${_simplificarErro(e)}";
          _isLoading = false;
        });
      }
    }
  }

  /// Atualização com sincronização melhorada
  Future<void> _atualizarDuplicatasCompleto() async {
    if (_isRefreshing || !mounted) return;
    
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      _logger.i("🔄 Iniciando atualização completa...");
      
      // Tentar sincronizar com servidor se VendasService disponível
      if (_vendasService != null) {
        try {
          _logger.i("🌐 Sincronizando com servidor...");
          
          final duplicatasResult = await _vendasService!.buscarDuplicatasCliente(
            widget.duplicata.codcli
          );
          
          if (duplicatasResult.isSuccess && duplicatasResult.data != null && _repositoryManager != null) {
            _logger.i("📊 Servidor retornou ${duplicatasResult.data!.length} duplicatas");
            
            // Atualizar banco local
            final db = await _repositoryManager!.dbHelper.database;
            
            await db.delete('duplicata', where: 'codcli = ?', whereArgs: [widget.duplicata.codcli]);
            
            for (final duplicata in duplicatasResult.data!) {
              await db.insert('duplicata', duplicata.toJson());
            }
            
            _logger.i("✅ Banco local atualizado");
            
          } else {
            _logger.w("⚠️ Erro na sincronização: ${duplicatasResult.errorMessage ?? 'Desconhecido'}");
          }
          
        } catch (syncError) {
          _logger.w("⚠️ Erro na sincronização (continuando): $syncError");
        }
      } else {
        _logger.i("ℹ️ VendasService não disponível - usando apenas dados locais");
      }
      
      // Recarregar dados locais
      final duplicatasAtualizadas = await _buscarDuplicatasCompleto(widget.duplicata.codcli);
      
      if (mounted) {
        setState(() {
          _duplicatas = duplicatasAtualizadas;
          _isRefreshing = false;
        });

        // Feedback para o usuário
        if (duplicatasAtualizadas.isNotEmpty) {
          _mostrarMensagem('${duplicatasAtualizadas.length} duplicatas atualizadas');
        } else {
          _mostrarMensagem('Cliente sem duplicatas pendentes', isWarning: true);
        }
      }
      
      _logger.i("✅ Atualização completa finalizada");
      
    } catch (e, stackTrace) {
      _logger.e("❌ Erro na atualização", error: e, stackTrace: stackTrace);
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _errorMessage = "Erro na atualização: ${_simplificarErro(e)}";
        });
        _mostrarMensagem('Erro ao atualizar', isError: true);
      }
    }
  }

  // RESTANTE DOS MÉTODOS PERMANECEM IGUAIS...
  
  Widget _buildEmptyViewMelhorado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              "Sem duplicatas pendentes",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Este cliente está em dia com seus pagamentos ou não possui duplicatas cadastradas no sistema.",
              style: TextStyle(
                color: Colors.grey[600], 
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Recarregar"),
                  onPressed: _carregarDuplicatasCompleto,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("Sincronizar"),
                  onPressed: _atualizarDuplicatasCompleto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DuplicataResumo get _resumoFinanceiro {
    double total = 0;
    double emAberto = 0;
    double vencido = 0;
    int quantidadeVencidas = 0;

    for (final duplicata in _duplicatas) {
      try {
        final valor = duplicata.vlrdpl;
        total += valor;
        
        final isVencida = _isDuplicataVencida(duplicata.dtavct);
        
        if (isVencida) {
          vencido += valor;
          quantidadeVencidas++;
        } else {
          emAberto += valor;
        }
      } catch (e) {
        _logger.w("Erro ao processar duplicata ${duplicata.numdoc}: $e");
        final valor = duplicata.vlrdpl;
        total += valor;
        emAberto += valor;
      }
    }

    return DuplicataResumo(
      total: total,
      emAberto: emAberto,
      vencido: vencido,
      quantidadeVencidas: quantidadeVencidas,
    );
  }

  String _formatarValor(double valor) {
    return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  String _formatarData(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Data inválida";
    
    try {
      DateTime date;
      if (dateString.contains('-')) {
        date = DateTime.parse(dateString);
      } else if (dateString.contains('/')) {
        final parts = dateString.split('/');
        if (parts.length == 3) {
          date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else {
          return dateString;
        }
      } else {
        return dateString;
      }
      
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    } catch (e) {
      _logger.w("Erro ao formatar data: $dateString", error: e);
      return dateString;
    }
  }

  bool _isDuplicataVencida(String? dataVencimento) {
    if (dataVencimento == null || dataVencimento.isEmpty) return false;
    
    try {
      DateTime dataVenc;
      if (dataVencimento.contains('-')) {
        dataVenc = DateTime.parse(dataVencimento);
      } else if (dataVencimento.contains('/')) {
        final parts = dataVencimento.split('/');
        if (parts.length == 3) {
          dataVenc = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else {
          return false;
        }
      } else {
        return false;
      }
      
      return dataVenc.isBefore(DateTime.now().subtract(const Duration(hours: 23, minutes: 59)));
    } catch (e) {
      _logger.w("Erro ao verificar vencimento: $dataVencimento", error: e);
      return false;
    }
  }

  String _obterStatusDuplicata(Duplicata duplicata) {
    return _isDuplicataVencida(duplicata.dtavct) ? 'Vencida' : 'Em Aberto';
  }

  Color _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'vencida':
        return Colors.red[700]!;
      case 'pago':
        return Colors.green[700]!;
      case 'cancelado':
        return Colors.grey[700]!;
      case 'em aberto':
      default:
        return Colors.blue[700]!;
    }
  }

  Color _getCorFundoStatus(String status) {
    switch (status.toLowerCase()) {
      case 'vencida':
        return Colors.red[50]!;
      case 'pago':
        return Colors.green[50]!;
      case 'cancelado':
        return Colors.grey[50]!;
      case 'em aberto':
      default:
        return Colors.blue[50]!;
    }
  }

  String _simplificarErro(dynamic erro) {
    final errorString = erro.toString().toLowerCase();
    
    if (errorString.contains('no such table')) {
      return 'Tabela não encontrada - Execute sincronização inicial';
    } else if (errorString.contains('database')) {
      return 'Erro no banco de dados local';
    } else if (errorString.contains('connection')) {
      return 'Erro de conexão com servidor';
    } else if (errorString.contains('provider')) {
      return 'Serviço não disponível - Reinicie o app';
    } else {
      return erro.toString();
    }
  }

  void _mostrarMensagem(String mensagem, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: isError
              ? Colors.red[700]
              : isWarning
                  ? Colors.orange[700]
                  : _primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final nomeCliente = widget.cliente?.nomcli ?? "Cliente #${widget.duplicata.codcli}";
    final codigoCliente = widget.duplicata.codcli.toString();

    return AppBar(
      title: const Text("Duplicatas", style: TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.refresh),
          onPressed: _isRefreshing ? null : _atualizarDuplicatasCompleto,
          tooltip: "Atualizar Duplicatas",
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: _buildClienteInfo(nomeCliente, codigoCliente),
      ),
    );
  }

  Widget _buildClienteInfo(String nomeCliente, String codigoCliente) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nomeCliente,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            "Código: $codigoCliente",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingView();
    }
    
    if (_errorMessage != null) {
      return _buildErrorView();
    }
    
    if (_duplicatas.isEmpty) {
      return _buildEmptyViewMelhorado();
    }
    
    return _buildDuplicatasView();
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Carregando duplicatas...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              "Não foi possível carregar as duplicatas",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text("Tentar Novamente"),
                  onPressed: _carregarDuplicatasCompleto,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync),
                  label: const Text("Sincronizar"),
                  onPressed: _atualizarDuplicatasCompleto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDuplicatasView() {
    return Column(
      children: [
        _buildResumoFinanceiro(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregarDuplicatasCompleto,
            color: _primaryColor,
            child: ListView.builder(
              itemCount: _duplicatas.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) => _buildItemDuplicata(_duplicatas[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoFinanceiro() {
    final resumo = _resumoFinanceiro;
    
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[100]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${_duplicatas.length} duplicata${_duplicatas.length != 1 ? 's' : ''}",
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildResumoValor("Total", resumo.total, Colors.grey[800]!),
              _buildResumoValor("Em Aberto", resumo.emAberto, Colors.blue[700]!),
              _buildResumoValor("Vencido", resumo.vencido, Colors.red[700]!),
            ],
          ),
          if (resumo.quantidadeVencidas > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[100]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[700], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "${resumo.quantidadeVencidas} duplicata${resumo.quantidadeVencidas > 1 ? 's' : ''} vencida${resumo.quantidadeVencidas > 1 ? 's' : ''}",
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
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
    final status = _obterStatusDuplicata(duplicata);
    final corStatus = _getCorStatus(status);
    final corFundoStatus = _getCorFundoStatus(status);
    final isPago = status.toLowerCase() == 'pago';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      duplicata.numdoc ?? "Sem número",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: corFundoStatus,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: corStatus,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Vencimento",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatarData(duplicata.dtavct),
                          style: const TextStyle(fontSize: 14),
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
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatarValor(duplicata.vlrdpl),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: isPago ? Colors.green[700] : corStatus,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (duplicata.numdoc != null && duplicata.numdoc!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        "Documento: ${duplicata.numdoc}",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DuplicataResumo {
  final double total;
  final double emAberto;
  final double vencido;
  final int quantidadeVencidas;

  const DuplicataResumo({
    required this.total,
    required this.emAberto,
    required this.vencido,
    required this.quantidadeVencidas,
  });
}