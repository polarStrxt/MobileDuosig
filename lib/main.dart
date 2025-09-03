import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/presentation/screens/loginscreen.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/services/vendas_service.dart';
import 'package:flutter_docig_venda/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// Provider principal que inicializa TUDO
class AppServicesProvider extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isInitializing = false;
  String _initializationStatus = 'Iniciando...';
  String? _errorMessage;
  
  // Serviços principais
  VendasService? _vendasService;
  SyncService? _syncService;
  RepositoryManager? _repositoryManager;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String get initializationStatus => _initializationStatus;
  String? get errorMessage => _errorMessage;
  
  VendasService? get vendasService => _vendasService;
  SyncService? get syncService => _syncService;
  RepositoryManager? get repositoryManager => _repositoryManager;
  
  Future<void> initializeSystem({
    String? codigoVendedor,
    String? baseUrl,
    bool pularSincronizacao = false,
  }) async {
    if (_isInitializing || _isInitialized) return;
    
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();
    
    final logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );
    
    try {
      // 1. Inicializar banco de dados
      _updateStatus('Inicializando banco de dados...');
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.database;
      _repositoryManager = RepositoryManager(dbHelper);
      logger.i("Banco de dados inicializado");
      
      // 2. Configurar API Client
      _updateStatus('Configurando cliente API...');
      final apiClient = UnifiedApiClient(
        baseUrl: baseUrl ?? 'http://duotecsuprilev.ddns.com.br:8082',
        codigoVendedor: codigoVendedor ?? '001',
        timeout: const Duration(seconds: 30),
      );
      logger.i("Cliente API configurado");
      
      // 3. Inicializar VendasService
      _updateStatus('Inicializando serviço de vendas...');
      _vendasService = VendasService(apiClient: apiClient);
      logger.i("Serviço de vendas inicializado");
      
      // 4. Inicializar SyncService
      _updateStatus('Inicializando serviço de sincronização...');
      _syncService = SyncService(
        vendasService: _vendasService,
        logger: logger,
        repositories: _repositoryManager,
      );
      logger.i("Serviço de sincronização inicializado");
      
      // 5. Sincronização (se necessário)
      if (!pularSincronizacao) {
        _updateStatus('Verificando conectividade...');
        final conectividade = await _syncService!.verificarConexaoInternet();
        final temDadosLocais = await _syncService!.temDadosLocais();
        
        if (conectividade.isSuccess && conectividade.data == true) {
          logger.i("Conectividade confirmada");
          
          if (!temDadosLocais) {
            _updateStatus('Sincronização inicial...');
            final resultado = await _syncService!.sincronizarDadosEssenciais();
            
            if (resultado.isSuccess) {
              logger.i("Sincronização inicial concluída: ${resultado.totalCount} registros");
            } else {
              logger.w("Sincronização inicial falhou: ${resultado.errorMessage}");
            }
          } else {
            logger.i("Dados locais disponíveis");
          }
        } else {
          logger.w("Sem conectividade - verificando dados locais");
        }
      } else {
        logger.i("Pulando sincronização - modo offline");
        _updateStatus('Inicializando em modo offline...');
      }
      
      _updateStatus('Sistema inicializado com sucesso!');
      _isInitialized = true;
      logger.i("Sistema completamente inicializado e pronto para uso!");
      
    } catch (e, stackTrace) {
      _errorMessage = _gerarMensagemErroAmigavel(e);
      _updateStatus('Erro na inicialização');
      logger.e("Erro crítico na inicialização", error: e, stackTrace: stackTrace);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }
  
  String _gerarMensagemErroAmigavel(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('connection') || errorString.contains('network') || errorString.contains('socket')) {
      return 'Problema de conexão com a internet.\nVerifique sua conexão e tente novamente.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Timeout na conexão com o servidor.\nO servidor pode estar lento ou indisponível.';
    }
    
    if (errorString.contains('database')) {
      return 'Erro no banco de dados local.\nTente reiniciar o aplicativo.';
    }
    
    if (errorString.contains('api') || errorString.contains('http')) {
      return 'Erro na comunicação com o servidor.\nVerifique se o servidor está funcionando.';
    }
    
    return 'Ocorreu um erro durante a inicialização.\nVerifique sua conexão e tente novamente.';
  }
  
  void _updateStatus(String status) {
    _initializationStatus = status;
    notifyListeners();
  }
  
  Future<void> restartSystem({String? novoCodigoVendedor}) async {
    _isInitialized = false;
    await initializeSystem(codigoVendedor: novoCodigoVendedor);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.level = Level.info;
  
  final logger = Logger();
  logger.i("Iniciando aplicativo MobileDuosig...");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. Provider de inicialização
        ChangeNotifierProvider(
          create: (context) => AppServicesProvider(),
        ),
        // 2. CARRINHO GLOBAL - DISPONÍVEL DESDE O INÍCIO
        ChangeNotifierProvider<Carrinho>(
          create: (_) => Carrinho(),
        ),
      ],
      child: MaterialApp(
        title: 'MobileDuosig',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 2,
          ),
        ),
        home: const AppInitializationScreen(),
      ),
    );
  }
}

class AppInitializationScreen extends StatefulWidget {
  const AppInitializationScreen({super.key});

  @override
  State<AppInitializationScreen> createState() => _AppInitializationScreenState();
}

class _AppInitializationScreenState extends State<AppInitializationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    final provider = context.read<AppServicesProvider>();
    
    await provider.initializeSystem(
      codigoVendedor: '001',
      baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppServicesProvider>(
      builder: (context, provider, child) {
        if (provider.isInitialized) {
          // AGORA SÓ ADICIONA OS PROVIDERS DE SERVIÇOS
          return MultiProvider(
            providers: [
              // Repass o provider de serviços
              ChangeNotifierProvider.value(value: provider),
              
              // Serviços principais
              Provider<VendasService>.value(value: provider.vendasService!),
              Provider<SyncService>.value(value: provider.syncService!),
              Provider<RepositoryManager>.value(value: provider.repositoryManager!),
              
              // CARRINHO JÁ ESTÁ DISPONÍVEL GLOBALMENTE - NÃO PRECISA REDECLARAR
            ],
            // Vai para o LoginScreen com TODOS os providers disponíveis
            child: const LoginScreen(),
          );
        }
        
        if (provider.errorMessage != null) {
          return _buildErrorScreen(provider);
        }
        
        return _buildLoadingScreen(provider);
      },
    );
  }

  Widget _buildLoadingScreen(AppServicesProvider provider) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'MobileDuosig',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Sistema de Vendas',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              
              Text(
                provider.initializationStatus,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              if (provider.isInitializing)
                SizedBox(
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(AppServicesProvider provider) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 80,
                color: Colors.orange[400],
              ),
              const SizedBox(height: 24),
              
              Text(
                'Problema na Inicialização',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                provider.errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _initializeApp(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar Novamente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _continuarSemSincronizacao(),
                      icon: const Icon(Icons.offline_bolt),
                      label: const Text('Continuar Offline'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  Future<void> _continuarSemSincronizacao() async {
    final provider = context.read<AppServicesProvider>();
    
    await provider.initializeSystem(
      codigoVendedor: '001',
      baseUrl: 'http://duotecsuprilev.ddns.com.br:8082',
      pularSincronizacao: true,
    );
  }
}