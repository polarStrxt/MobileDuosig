import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/data/datasources/local/database_helper.dart';
import 'package:flutter_docig_venda/data/repositories/all_repositories.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart'; // Correção do import
import 'package:flutter_docig_venda/presentation/screens/carrinhoScreen.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
import 'package:flutter_docig_venda/data/datasources/remoto/api_client.dart';

class AdicionarProdutoScreen extends StatefulWidget {
  final Cliente? cliente;

  const AdicionarProdutoScreen({super.key, this.cliente});

  @override
  State<AdicionarProdutoScreen> createState() => _AdicionarProdutoScreenState();
}

class _AdicionarProdutoScreenState extends State<AdicionarProdutoScreen> {
  // Constantes de Cores
  static const Color _kPrimaryColor = Color(0xFF5D5CDE);
  static const Color _kErrorColor = Color(0xFFE53935);
  static const Color _kSuccessColor = Color(0xFF43A047);
  static const Color _kBackgroundColor = Colors.white;
  static const Color _kSurfaceColor = Color(0xFFF5F5F5);
  static const Color _kTextPrimaryColor = Color(0xFF212121);
  static const Color _kTextSecondaryColor = Color(0xFF757575);

  // Repositórios
  late final RepositoryManager _repositoryManager;
  late final ProdutoRepository _produtoRepository;
  
  // Services - Correção: adicionando repositoryManager como parâmetro obrigatório
  late final CarrinhoService _carrinhoService;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 100,
      // Correção: substituindo printTime por dateTimeFormat
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  // Controllers e Focus Nodes
  final TextEditingController _codigoProdutoController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _descontoController = TextEditingController();
  final FocusNode _codigoFocusNode = FocusNode();
  final FocusNode _quantidadeFocusNode = FocusNode();
  final FocusNode _descontoFocusNode = FocusNode();

  // Estado
  ProdutoModel? _produtoSelecionado;
  bool _isLoading = false;
  String? _errorMessageApi;
  bool _didDependenciesChangeRunOnce = false;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _quantidadeController.text = '0';
    _descontoController.text = '0';
    _logger.i("AdicionarProdutoScreen: initState completado.");
  }

  void _initializeRepositories() {
    final dbHelper = DatabaseHelper.instance;
    _repositoryManager = RepositoryManager(dbHelper);
    _produtoRepository = _repositoryManager.produtos;
    // Correção: inicializando CarrinhoService com repositoryManager
    _carrinhoService = CarrinhoService(repositoryManager: _repositoryManager);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logger.i("AdicionarProdutoScreen: didChangeDependencies chamado. Primeira execução: ${!_didDependenciesChangeRunOnce}");
    if (!_didDependenciesChangeRunOnce) {
      _verificarCarrinhoExistente();
      _didDependenciesChangeRunOnce = true;
    }
  }

  @override
  void dispose() {
    _codigoProdutoController.dispose();
    _quantidadeController.dispose();
    _descontoController.dispose();
    _codigoFocusNode.dispose();
    _quantidadeFocusNode.dispose();
    _descontoFocusNode.dispose();
    _logger.i("AdicionarProdutoScreen: dispose chamado, resources liberados.");
    super.dispose();
  }

  void _logErro(String mensagem, dynamic erro, [StackTrace? stackTrace]) {
    _logger.e('ERRO: $mensagem', error: erro, stackTrace: stackTrace);
  }

  void _mostrarMensagem(String mensagem, {Color? cor}) {
    if (!mounted) {
      _logger.w("Tentativa de mostrar mensagem com widget desmontado: $mensagem");
      return;
    }
    
    _logger.i("Mostrando SnackBar: '$mensagem'");
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem),
          backgroundColor: cor ?? Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<void> _verificarCarrinhoExistente() async {
    _logger.i("_verificarCarrinhoExistente iniciado.");
    if (widget.cliente == null) {
      _logger.w("Cliente nulo em _verificarCarrinhoExistente, interrompendo.");
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    _logger.i("CarrinhoProvider isEmpty: ${carrinhoProvider.isEmpty}");

    if (carrinhoProvider.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
      
      try {
        _logger.i("Verificando se cliente ${widget.cliente!.codcli} tem carrinho pendente...");
        final ApiResult<bool> resultado = await _carrinhoService.clienteTemCarrinhoPendente(widget.cliente!);
        _logger.i("Resultado clienteTemCarrinhoPendente: success=${resultado.isSuccess}, data=${resultado.data}");

        if (mounted) {
          if (resultado.isSuccess && resultado.data == true) {
            _logger.i("Carrinho pendente encontrado. Mostrando diálogo.");
            final bool? deveRecuperar = await _mostrarDialogCarrinhoPendente();
            _logger.i("Usuário escolheu recuperar? $deveRecuperar");
            if (mounted && deveRecuperar == true) {
              await _recuperarItensCarrinho();
            }
          } else if (!resultado.isSuccess) {
            _logger.e("Falha ao verificar carrinho pendente: ${resultado.errorMessage}");
            _mostrarMensagem("Falha ao verificar carrinho: ${resultado.errorMessage}", cor: _kErrorColor);
          }
        }
      } catch (e, s) {
        _logErro('Exceção em _verificarCarrinhoExistente', e, s);
        if (mounted) {
          _mostrarMensagem("Erro ao verificar carrinho.", cor: _kErrorColor);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      _logger.i("CarrinhoProvider já possui ${carrinhoProvider.itens.length} tipos de itens.");
    }
  }

  Future<bool?> _mostrarDialogCarrinhoPendente() {
    _logger.i("_mostrarDialogCarrinhoPendente chamado.");
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout_rounded, color: _kPrimaryColor, size: 22),
            SizedBox(width: 10),
            Text(
              "Carrinho Pendente",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _kTextPrimaryColor,
              ),
            ),
          ],
        ),
        content: Text(
          "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.\nDeseja recuperá-lo?",
          style: const TextStyle(
            fontSize: 14.5,
            color: _kTextSecondaryColor,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              "IGNORAR",
              style: TextStyle(
                color: _kTextSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              "RECUPERAR",
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recuperarItensCarrinho() async {
    _logger.i("_recuperarItensCarrinho iniciado.");
    if (widget.cliente == null) {
      _logger.w('Cliente nulo, não é possível recuperar o carrinho.');
      return;
    }
    if (!mounted) {
      _logger.w('_recuperarItensCarrinho chamado com widget desmontado.');
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);

    if (mounted) setState(() => _isLoading = true);

    try {
      final ApiResult<Carrinho> resultado = await _carrinhoService.recuperarCarrinho(widget.cliente!);
      _logger.i('Resultado de recuperarCarrinho: success=${resultado.isSuccess}, data nulo=${resultado.data == null}');
      
      if (resultado.data != null) {
        _logger.i('Carrinho recuperado: isEmpty=${resultado.data!.isEmpty}, itens.length=${resultado.data!.itens.length}');
        if (resultado.data!.itens.isNotEmpty) {
          resultado.data!.itens.forEach((prod, qtd) {
            _logger.d("Item recuperado: ${prod.dcrprd} (ID: ${prod.codprd}) - Qtd: $qtd - Desc: ${resultado.data!.descontos[prod]}%");
          });
        }
      }

      if (mounted) {
        if (resultado.isSuccess && resultado.data != null) {
          final Carrinho carrinhoRecuperado = resultado.data!;

          if (carrinhoRecuperado.isEmpty) {
            _logger.i("Carrinho recuperado está vazio.");
            if (!carrinhoProvider.isEmpty) {
              _logger.i("Limpando carrinhoProvider local.");
              carrinhoProvider.limpar();
            }
            _mostrarMensagem("Nenhum item pendente no carrinho.", cor: _kTextSecondaryColor);
          } else {
            _logger.i("ANTES: Itens no provider local: ${carrinhoProvider.itens.length}");
            carrinhoProvider.substituir(carrinhoRecuperado);
            _logger.i("DEPOIS: Itens no provider local: ${carrinhoProvider.itens.length}");
            _mostrarMensagem("Carrinho recuperado com sucesso!", cor: _kSuccessColor);
          }
        } else {
          _logErro('Falha ao recuperar carrinho', resultado.errorMessage);
          _mostrarMensagem(
            "Erro ao recuperar carrinho: ${resultado.errorMessage ?? 'Não foi possível carregar os dados.'}",
            cor: _kErrorColor,
          );
        }
      }
    } catch (e, s) {
      _logErro('Exceção em _recuperarItensCarrinho', e, s);
      if (mounted) {
        _mostrarMensagem("Erro crítico ao recuperar carrinho: $e", cor: _kErrorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buscarProdutoPorCodigo() async {
    _logger.i("_buscarProdutoPorCodigo iniciado com texto: '${_codigoProdutoController.text}'.");
    final codigoStr = _codigoProdutoController.text.trim();

    if (codigoStr.isEmpty) {
      _mostrarMensagem('Digite o código do produto', cor: _kErrorColor);
      _codigoFocusNode.requestFocus();
      return;
    }

    final codigo = int.tryParse(codigoStr);
    if (codigo == null) {
      _mostrarMensagem('Código de produto inválido', cor: _kErrorColor);
      _codigoFocusNode.requestFocus();
      _codigoProdutoController.selectAll();
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessageApi = null;
        _produtoSelecionado = null;
      });
    }

    try {
      _logger.i("Buscando produto com código: $codigo");
      final produto = await _produtoRepository.getProdutoByCodigo(codigo);
      _logger.i("Produto encontrado para código $codigo: ${produto?.dcrprd ?? "Nenhum"}");

      if (mounted) {
        setState(() {
          _isLoading = false;
          _produtoSelecionado = produto;
          _errorMessageApi = produto == null ? 'Produto não encontrado' : null;
        });

        if (produto != null) {
          _quantidadeController.text = '0';
          _descontoController.text = '0';
          _quantidadeFocusNode.requestFocus();
        } else {
          _codigoFocusNode.requestFocus();
          _codigoProdutoController.selectAll();
        }
      }
    } catch (e, s) {
      _logErro('Erro em _buscarProdutoPorCodigo', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessageApi = 'Erro ao buscar produto: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _adicionarAoCarrinho() async {
    _logger.i("_adicionarAoCarrinho iniciado.");

    if (_produtoSelecionado == null) {
      _mostrarMensagem('Selecione um produto primeiro', cor: _kErrorColor);
      _codigoFocusNode.requestFocus();
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem('Selecione um cliente para adicionar ao carrinho', cor: _kErrorColor);
      return;
    }

    final quantidade = int.tryParse(_quantidadeController.text.trim());
    if (quantidade == null || quantidade <= 0) {
      _mostrarMensagem('A quantidade deve ser maior que zero', cor: _kErrorColor);
      _quantidadeFocusNode.requestFocus();
      _quantidadeController.selectAll();
      return;
    }

    final descontoText = _descontoController.text.trim().replaceAll(',', '.');
    final desconto = double.tryParse(descontoText);
    if (desconto == null || desconto < 0 || desconto > 100) {
      _mostrarMensagem('O desconto deve estar entre 0 e 100%', cor: _kErrorColor);
      _descontoFocusNode.requestFocus();
      _descontoController.selectAll();
      return;
    }

    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.adicionarItem(_produtoSelecionado!, quantidade, desconto);
      
      _logger.i(
        "Produto ${_produtoSelecionado!.codprd} (${_produtoSelecionado!.dcrprd}) "
        "adicionado ao carrinho. Qtd: $quantidade, Desc: $desconto%"
      );

      if (mounted) {
        setState(() {
          _produtoSelecionado = null;
          _codigoProdutoController.clear();
          _quantidadeController.text = '0';
          _descontoController.text = '0';
          _errorMessageApi = null;
        });
      }

      _codigoFocusNode.requestFocus();
      _mostrarMensagem('Produto adicionado ao carrinho!', cor: _kSuccessColor);

      // Salvar alterações assíncronamente
      _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
          .then((resultado) {
        if (mounted && !resultado.isSuccess) {
          _logErro('Falha ao salvar alterações no carrinho', resultado.errorMessage);
          _mostrarMensagem('Erro ao salvar carrinho: ${resultado.errorMessage}', cor: _kErrorColor);
        } else if (resultado.isSuccess) {
          _logger.i("Alterações do carrinho salvas no banco de dados.");
        }
      }).catchError((e, s) {
        _logErro('Exceção ao salvar alterações no carrinho', e, s);
        if (mounted) {
          _mostrarMensagem('Erro inesperado ao salvar carrinho.', cor: _kErrorColor);
        }
      });
    } catch (e, s) {
      _logErro('Erro em _adicionarAoCarrinho', e, s);
      if (mounted) {
        _mostrarMensagem('Erro ao adicionar produto: ${e.toString()}', cor: _kErrorColor);
      }
    }
  }

  void _navegarParaCarrinho() {
    _logger.i("_navegarParaCarrinho chamado.");
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);

    if (carrinhoProvider.isEmpty) {
      _mostrarMensagem('O carrinho está vazio.', cor: _kTextSecondaryColor);
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem('Selecione um cliente primeiro.', cor: _kErrorColor);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarrinhoScreen(
          cliente: widget.cliente,
          codcli: widget.cliente!.codcli,
        ),
      ),
    ).then((_) {
      _logger.i("Retornou da CarrinhoScreen.");
    });
  }

  double _getValorProdutoTabela(ProdutoModel produto) {
    if (widget.cliente == null) {
      _logger.w("Cliente nulo ao obter valor da tabela para ${produto.dcrprd}. Usando vlrbasvda.");
      return produto.vlrbasvda;
    }
    
    switch (widget.cliente!.codtab) {
      case 2:
        return produto.vlrtab1;
      case 10:
        return produto.vlrtab2;
      default:
        return produto.vlrbasvda;
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.d(
      "build chamado. Loading: $_isLoading, "
      "Produto: ${_produtoSelecionado?.dcrprd}, "
      "Erro: $_errorMessageApi"
    );
    
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: _construirAppBar(),
      body: _construirCorpo(),
      floatingActionButton: _construirBotaoCarrinhoFlutuante(),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: _kPrimaryColor,
      elevation: 2,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Adicionar Produto",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          if (widget.cliente != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                "Cliente: ${widget.cliente!.nomcli}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirCorpo() {
    return SafeArea(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          children: [
            _construirBarraInfo(),
            const SizedBox(height: 24),
            _construirCampoCodigo(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(_kPrimaryColor),
                  ),
                ),
              )
            else if (_produtoSelecionado != null) ...[
              _construirDetalhesProduto(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _construirCampoQuantidade()),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _construirCampoDesconto()),
                ],
              ),
              const SizedBox(height: 28),
              _construirBotaoAdicionar(),
            ] else if (_errorMessageApi != null)
              _construirMensagemErroApi()
            else
              _construirEstadoInicial(),
          ],
        ),
      ),
    );
  }

  Widget _construirBarraInfo() {
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, quantidadeTotal, _) {
        _logger.d("_construirBarraInfo rebuild. Quantidade total: $quantidadeTotal");
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kSurfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 17, color: _kTextSecondaryColor),
                  const SizedBox(width: 8),
                  Text(
                    "Itens: $quantidadeTotal",
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (widget.cliente != null)
                Row(
                  children: [
                    const Icon(Icons.list_alt_outlined, size: 17, color: _kTextSecondaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "Tabela: ${widget.cliente!.codtab}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kTextSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _construirCampoCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Código do Produto",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
            color: _kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codigoProdutoController,
          focusNode: _codigoFocusNode,
          decoration: InputDecoration(
            hintText: "Digite ou leia o código",
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimaryColor, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded, color: _kPrimaryColor, size: 22),
              onPressed: _buscarProdutoPorCodigo,
            ),
          ),
          style: const TextStyle(fontSize: 16, color: _kTextPrimaryColor),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _buscarProdutoPorCodigo(),
        ),
      ],
    );
  }

  Widget _construirDetalhesProduto() {
    final produto = _produtoSelecionado!;
    final estoqueDisponivel = (produto.qtdetq ?? 0) > 0;
    // Correção: substituindo withOpacity por withValues
    final corEstoque = estoqueDisponivel 
        ? _kSuccessColor.withValues(alpha: 0.8)
        : _kErrorColor.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "#${produto.codprd}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _kPrimaryColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.dcrprd,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.5,
                        color: _kTextPrimaryColor,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Marca: ${produto.nommrc}",
                      style: const TextStyle(
                        color: _kTextSecondaryColor,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "R\$ ${_getValorProdutoTabela(produto).toStringAsFixed(2)}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: _kPrimaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: corEstoque.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  estoqueDisponivel ? "Estoque: ${produto.qtdetq}" : "Sem estoque",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    color: corEstoque,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirCampoQuantidade() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quantidade",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
            color: _kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _quantidadeController,
          focusNode: _quantidadeFocusNode,
          decoration: InputDecoration(
            hintText: "0",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimaryColor, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 16, color: _kTextPrimaryColor),
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _descontoFocusNode.requestFocus(),
          onTap: () => _quantidadeController.selectAll(),
        ),
      ],
    );
  }

  Widget _construirCampoDesconto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Desconto (%)",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.5,
            color: _kTextPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descontoController,
          focusNode: _descontoFocusNode,
          decoration: InputDecoration(
            hintText: "0.00",
            suffixText: "%",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[350]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _kPrimaryColor, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 16, color: _kTextPrimaryColor),
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Correção: regex para permitir números decimais com até 2 casas
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'
                ))],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _adicionarAoCarrinho(),
          onTap: () => _descontoController.selectAll(),
        ),
      ],
    );
  }

  Widget _construirBotaoAdicionar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
        label: const Text("ADICIONAR AO CARRINHO"),
        onPressed: _adicionarAoCarrinho,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 1,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _construirMensagemErroApi() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kErrorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kErrorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: _kErrorColor.withValues(alpha: 0.8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessageApi ?? "Ocorreu um erro desconhecido.",
              style: TextStyle(
                color: _kErrorColor.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoInicial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Digite o código para buscar um produto.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kTextSecondaryColor.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirBotaoCarrinhoFlutuante() {
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, totalItens, child) {
        _logger.d("_construirBotaoCarrinhoFlutuante rebuild. Total de itens: $totalItens");
        
        if (totalItens <= 0) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: _navegarParaCarrinho,
          backgroundColor: _kPrimaryColor,
          elevation: 3,
          icon: Badge(
            label: Text(
              '$totalItens',
              style: const TextStyle(
                color: _kPrimaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: totalItens > 9 ? 4 : 6,
            ),
            isLabelVisible: totalItens > 0,
            child: const Icon(
              Icons.shopping_cart_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          label: const Text(
            "VER CARRINHO",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        );
      },
    );
  }
}

// Extensão para selecionar todo o texto em um TextEditingController
extension TextEditingControllerExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}