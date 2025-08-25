// lib/screens/adicionar_produto_screen.dart
// (Lembre-se de renomear o arquivo se necessário e atualizar os imports)

import 'package:flutter_docig_venda/services/dao/produto_dao.dart';
import 'package:flutter_docig_venda/services/carrinhoservice.dart'; // Verifique o nome: carrinho_service.dart
import 'package:flutter_docig_venda/presentation/screens/carrinhoScreen.dart'; // Verifique o nome: carrinho_screen.dart
import 'package:flutter_docig_venda/data/models/produto_model.dart';
import 'package:flutter_docig_venda/data/models/cliente_model.dart';
import 'package:flutter_docig_venda/services/api_client.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart'; // Seu ChangeNotifier Carrinho
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:logger/logger.dart';

class AdicionarProdutoScreen extends StatefulWidget {
  final Cliente? cliente;

  const AdicionarProdutoScreen({super.key, this.cliente});

  @override
  State<AdicionarProdutoScreen> createState() => _AdicionarProdutoScreenState();
}

class _AdicionarProdutoScreenState extends State<AdicionarProdutoScreen> {
  // Constantes de Cores
  static const Color kPrimaryColor = Color(0xFF5D5CDE);
  static const Color kErrorColor = Color(0xFFE53935);
  static const Color kSuccessColor = Color(0xFF43A047);
  static const Color kBackgroundColor = Colors.white;
  static const Color kSurfaceColor = Color(0xFFF5F5F5);
  static const Color kTextPrimaryColor = Color(0xFF212121);
  static const Color kTextSecondaryColor = Color(0xFF757575);

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
  String? _errorMessageApi; // Para erros de API na busca de produto ou recuperação

  // Flag para didChangeDependencies
  bool _didDependenciesChangeRunOnce = false;

  // DAOs e Services
  final ProdutoDao _produtoDao = ProdutoDao();
  final CarrinhoService _carrinhoService = CarrinhoService();
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 1, errorMethodCount: 5, lineLength: 100, printTime: true)); // Logger configurado

  @override
  void initState() {
    super.initState();
    _quantidadeController.text = '0';
    _descontoController.text = '0';
    _logger.i("AdicionarProdutoScreen: initState completado.");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logger.i("AdicionarProdutoScreen: didChangeDependencies chamado. _didDependenciesChangeRunOnce: $_didDependenciesChangeRunOnce");
    if (!_didDependenciesChangeRunOnce) {
      _logger.i("AdicionarProdutoScreen: Primeira execução de didChangeDependencies, chamando _verificarCarrinhoExistente.");
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
    _logger.i("AdicionarProdutoScreen: dispose chamado, controllers e focus nodes liberados.");
    super.dispose();
  }

  void _logErro(String mensagem, dynamic erro, [StackTrace? stackTrace]) {
    _logger.e('ERRO: $mensagem', error: erro, stackTrace: stackTrace);
  }

  void _mostrarMensagem(ScaffoldMessengerState messenger, String mensagem, {Color? cor}) {
    if (!mounted) {
      _logger.w("AdicionarProdutoScreen: Tentativa de mostrar mensagem com widget desmontado: $mensagem");
      return;
    }
    _logger.i("AdicionarProdutoScreen: Mostrando SnackBar: '$mensagem'");
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
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
    _logger.i("AdicionarProdutoScreen: _verificarCarrinhoExistente iniciado.");
    if (widget.cliente == null) {
      _logger.w("AdicionarProdutoScreen: Cliente nulo em _verificarCarrinhoExistente, interrompendo.");
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    _logger.i("AdicionarProdutoScreen: Em _verificarCarrinhoExistente, carrinhoProvider.isEmpty: ${carrinhoProvider.isEmpty}");

    if (carrinhoProvider.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
      try {
        _logger.i("AdicionarProdutoScreen: Verificando se cliente ${widget.cliente!.codcli} tem carrinho pendente...");
        final ApiResult<bool> resultado = await _carrinhoService.clienteTemCarrinhoPendente(widget.cliente!);
        _logger.i("AdicionarProdutoScreen: Resultado clienteTemCarrinhoPendente: isSuccess=${resultado.isSuccess}, data=${resultado.data}, error=${resultado.errorMessage}");

        if (mounted) {
          if (resultado.isSuccess && resultado.data == true) {
            _logger.i("AdicionarProdutoScreen: Carrinho pendente encontrado. Mostrando diálogo.");
            final bool? deveRecuperar = await _mostrarDialogCarrinhoPendente();
            _logger.i("AdicionarProdutoScreen: Usuário escolheu recuperar? $deveRecuperar");
            if (mounted && deveRecuperar == true) {
              await _recuperarItensCarrinho();
            }
          } else if (mounted && !resultado.isSuccess) {
            _logger.e("AdicionarProdutoScreen: Falha ao verificar carrinho pendente: ${resultado.errorMessage}");
            _mostrarMensagem(scaffoldMessenger, "Falha ao verificar carrinho: ${resultado.errorMessage}", cor: kErrorColor);
          }
        }
      } catch (e, s) {
        _logErro('AdicionarProdutoScreen: Exceção em _verificarCarrinhoExistente', e, s);
        if (mounted) {
          _mostrarMensagem(scaffoldMessenger, "Exceção ao verificar carrinho.", cor: kErrorColor);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      _logger.i("AdicionarProdutoScreen: CarrinhoProvider já possui itens (${carrinhoProvider.itens.length} tipos). Nenhuma verificação de pendência necessária.");
    }
  }

  Future<bool?> _mostrarDialogCarrinhoPendente() {
    _logger.i("AdicionarProdutoScreen: _mostrarDialogCarrinhoPendente chamado.");
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
        title: Row(
          children: const [
            Icon(Icons.shopping_cart_checkout_rounded, color: kPrimaryColor, size: 22),
            SizedBox(width: 10),
            Text("Carrinho Pendente", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimaryColor)),
          ],
        ),
        content: Text(
          "Encontramos um carrinho não finalizado para ${widget.cliente!.nomcli}.\nDeseja recuperá-lo?",
          style: const TextStyle(fontSize: 14.5, color: kTextSecondaryColor, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("IGNORAR", style: TextStyle(color: kTextSecondaryColor, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("RECUPERAR", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _recuperarItensCarrinho() async {
    _logger.i("AdicionarProdutoScreen: _recuperarItensCarrinho iniciado.");
    if (widget.cliente == null) {
      _logger.w('AdicionarProdutoScreen: Cliente nulo, não é possível recuperar o carrinho.');
      return;
    }
    if (!mounted) {
      _logger.w('AdicionarProdutoScreen: _recuperarItensCarrinho chamado com widget desmontado.');
      return;
    }

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context); 

    if(mounted) setState(() => _isLoading = true);

    try {
      final ApiResult<Carrinho> resultado = await _carrinhoService.recuperarCarrinho(widget.cliente!);
      _logger.i('AdicionarProdutoScreen: Resultado de _carrinhoService.recuperarCarrinho: isSuccess=${resultado.isSuccess}, data NULO? ${resultado.data == null}, errorMessage=${resultado.errorMessage}');
      if (resultado.data != null) {
        _logger.i('AdicionarProdutoScreen: Carrinho recuperado DO SERVIÇO: isEmpty=${resultado.data!.isEmpty}, itens.length=${resultado.data!.itens.length}, descontos.length=${resultado.data!.descontos.length}');
        if (resultado.data!.itens.isNotEmpty) {
            resultado.data!.itens.forEach((prod, qtd) {
                _logger.d("SERVIÇO retornou item: ${prod.dcrprd} (ID: ${prod.codprd}) - Qtd: $qtd - Desc: ${resultado.data!.descontos[prod]}%");
            });
        }
      }

      if (mounted) {
        if (resultado.isSuccess && resultado.data != null) {
          final Carrinho carrinhoRecuperadoDoServico = resultado.data!;

          if (carrinhoRecuperadoDoServico.isEmpty) {
            _logger.i("AdicionarProdutoScreen: Carrinho recuperado do serviço está vazio.");
            if (!carrinhoProvider.isEmpty) {
              _logger.i("AdicionarProdutoScreen: Limpando carrinhoProvider local pois o recuperado está vazio.");
              carrinhoProvider.limpar();
            }
            _mostrarMensagem(scaffoldMessenger, "Nenhum item pendente no carrinho.", cor: kTextSecondaryColor);
          } else {
            _logger.i("AdicionarProdutoScreen: ANTES de carrinhoProvider.substituir. Itens no provider local: ${carrinhoProvider.itens.length}");
            carrinhoProvider.substituir(carrinhoRecuperadoDoServico); 
            _logger.i("AdicionarProdutoScreen: DEPOIS de carrinhoProvider.substituir. Itens no provider local: ${carrinhoProvider.itens.length}");
            _mostrarMensagem(scaffoldMessenger, "Carrinho recuperado com sucesso!", cor: kSuccessColor);
          }
        } else {
          _logErro('AdicionarProdutoScreen: Falha ao recuperar carrinho', resultado.errorMessage);
          _mostrarMensagem(scaffoldMessenger, "Erro ao recuperar carrinho: ${resultado.errorMessage ?? 'Não foi possível carregar os dados.'}", cor: kErrorColor);
        }
      }
    } catch (e, s) {
      _logErro('AdicionarProdutoScreen: Exceção em _recuperarItensCarrinho', e, s);
      if (mounted) {
        _mostrarMensagem(scaffoldMessenger, "Erro crítico ao recuperar carrinho: $e", cor: kErrorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _buscarProdutoPorCodigo() async {
    _logger.i("AdicionarProdutoScreen: _buscarProdutoPorCodigo iniciado com texto: '${_codigoProdutoController.text}'.");
    final codigoStr = _codigoProdutoController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (codigoStr.isEmpty) {
      _mostrarMensagem(scaffoldMessenger, 'Digite o código do produto', cor: kErrorColor);
      _codigoFocusNode.requestFocus();
      return;
    }

    final codigo = int.tryParse(codigoStr);
    if (codigo == null) {
      _mostrarMensagem(scaffoldMessenger, 'Código de produto inválido', cor: kErrorColor);
      _codigoFocusNode.requestFocus();
      _codigoProdutoController.selectAll();
      return;
    }

    if(mounted) {
      setState(() {
        _isLoading = true;
        _errorMessageApi = null; 
        _produtoSelecionado = null; 
      });
    }

    try {
      _logger.i("AdicionarProdutoScreen: Buscando produto com código: $codigo");
      final produto = await _produtoDao.getProdutoByCodigo(codigo);
      _logger.i("AdicionarProdutoScreen: Produto encontrado para código $codigo: ${produto?.dcrprd ?? "Nenhum"}");

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
      _logErro('AdicionarProdutoScreen: Erro em _buscarProdutoPorCodigo', e, s);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessageApi = 'Erro ao buscar produto: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _adicionarAoCarrinho() async {
    _logger.i("AdicionarProdutoScreen: _adicionarAoCarrinho iniciado.");
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (_produtoSelecionado == null) {
      _mostrarMensagem(scaffoldMessenger, 'Selecione um produto primeiro', cor: kErrorColor);
      _codigoFocusNode.requestFocus();
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem(scaffoldMessenger, 'Selecione um cliente para adicionar ao carrinho', cor: kErrorColor);
      return;
    }

    final quantidade = int.tryParse(_quantidadeController.text.trim());
    if (quantidade == null || quantidade <= 0) {
      _mostrarMensagem(scaffoldMessenger, 'A quantidade deve ser maior que zero', cor: kErrorColor);
      _quantidadeFocusNode.requestFocus();
      _quantidadeController.selectAll();
      return;
    }

    final descontoText = _descontoController.text.trim().replaceAll(',', '.');
    final desconto = double.tryParse(descontoText);
    if (desconto == null || desconto < 0 || desconto > 100) {
      _mostrarMensagem(scaffoldMessenger, 'O desconto deve estar entre 0 e 100%', cor: kErrorColor);
      _descontoFocusNode.requestFocus();
      _descontoController.selectAll();
      return;
    }

    try {
      final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
      carrinhoProvider.adicionarItem(_produtoSelecionado!, quantidade, desconto); 
      _logger.i("AdicionarProdutoScreen: Produto ${_produtoSelecionado!.codprd} (${_produtoSelecionado!.dcrprd}) adicionado ao carrinhoProvider. Qtd: $quantidade, Desc: $desconto%");

      if(mounted) {
        setState(() {
          _produtoSelecionado = null; 
          _codigoProdutoController.clear();
          _quantidadeController.text = '0';
          _descontoController.text = '0';
          _errorMessageApi = null; 
        });
      }
      
      _codigoFocusNode.requestFocus();
      _mostrarMensagem(scaffoldMessenger, 'Produto adicionado ao carrinho!', cor: kSuccessColor);
      
      _carrinhoService.salvarAlteracoesCarrinho(carrinhoProvider, widget.cliente!)
        .then((resultado) {
          if (mounted && !resultado.isSuccess) {
            _logErro('AdicionarProdutoScreen: Falha ao salvar alterações no carrinho no DB', resultado.errorMessage);
            _mostrarMensagem(scaffoldMessenger, 'Erro ao salvar carrinho no DB: ${resultado.errorMessage}', cor: kErrorColor);
          } else if (resultado.isSuccess) {
             _logger.i("AdicionarProdutoScreen: Alterações do carrinho salvas com sucesso no banco de dados.");
          }
        }).catchError((e, s){
           _logErro('AdicionarProdutoScreen: Exceção ao salvar alterações no carrinho no DB', e, s);
           if(mounted){
              _mostrarMensagem(scaffoldMessenger, 'Erro inesperado ao salvar carrinho no DB.', cor: kErrorColor);
           }
        });
    } catch (e, s) {
      _logErro('AdicionarProdutoScreen: Erro em _adicionarAoCarrinho', e, s);
       if(mounted){
         _mostrarMensagem(scaffoldMessenger, 'Erro ao adicionar produto: ${e.toString()}', cor: kErrorColor);
       }
    }
  }

  void _navegarParaCarrinho() {
    _logger.i("AdicionarProdutoScreen: _navegarParaCarrinho chamado.");
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (carrinhoProvider.isEmpty) {
      _mostrarMensagem(scaffoldMessenger, 'O carrinho está vazio.', cor: kTextSecondaryColor);
      return;
    }

    if (widget.cliente == null) {
      _mostrarMensagem(scaffoldMessenger, 'Selecione um cliente primeiro.', cor: kErrorColor);
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
      _logger.i("AdicionarProdutoScreen: Retornou da CarrinhoScreen.");
      if (mounted) {
        // setState(() {}); // Opcional: se precisar forçar um rebuild por algum motivo específico
      }
    });
  }

  double _getValorProdutoTabela(ProdutoModel produto) {
    if (widget.cliente == null) {
      _logger.w("AdicionarProdutoScreen: Cliente nulo ao tentar obter valor da tabela para ${produto.dcrprd}. Usando vlrbasvda.");
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
    _logger.d("AdicionarProdutoScreen: build chamado. _isLoading: $_isLoading, _produtoSelecionado: ${_produtoSelecionado?.dcrprd}, _errorMessageApi: $_errorMessageApi");
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _construirAppBar(),
      body: _construirCorpo(),
      floatingActionButton: _construirBotaoCarrinhoFlutuante(),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: kPrimaryColor,
      elevation: 2, 
      centerTitle: false, 
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          const Text("Adicionar Produto", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          if (widget.cliente != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                "Cliente: ${widget.cliente!.nomcli}",
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.white70),
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
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
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
            ] else if (_errorMessageApi != null && !_isLoading)
              _construirMensagemErroApi(),
              if (!_isLoading && _produtoSelecionado == null && _errorMessageApi == null) // Estado inicial ou após limpar
              Center(
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
                        style: TextStyle(color: kTextSecondaryColor.withOpacity(0.7), fontSize: 15, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirBarraInfo() {
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, quantidadeTotal, _) {
        _logger.d("AdicionarProdutoScreen: _construirBarraInfo rebuild. Quantidade total do provider: $quantidadeTotal");
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 17, color: kTextSecondaryColor),
                  const SizedBox(width: 8),
                  Text("Itens: $quantidadeTotal", style: const TextStyle(fontSize: 14, color: kTextSecondaryColor, fontWeight: FontWeight.w500)),
                ],
              ),
              if (widget.cliente != null)
                Row(
                  children: [
                    Icon(Icons.list_alt_outlined, size: 17, color: kTextSecondaryColor),
                    const SizedBox(width: 8),
                    Text("Tabela: ${widget.cliente!.codtab}", style: const TextStyle(fontSize: 14, color: kTextSecondaryColor, fontWeight: FontWeight.w500)),
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
        const Text("Código do Produto", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5, color: kTextPrimaryColor)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search_rounded, color: kPrimaryColor, size: 22),
              onPressed: _buscarProdutoPorCodigo,
            ),
          ),
          style: const TextStyle(fontSize: 16, color: kTextPrimaryColor),
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
    final corEstoque = estoqueDisponivel ? kSuccessColor.withOpacity(0.8) : kErrorColor.withOpacity(0.8);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: Offset(0, 1))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kPrimaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text("#${produto.codprd}", style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(produto.dcrprd, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16.5, color: kTextPrimaryColor, height: 1.3)),
                        const SizedBox(height: 4),
                        Text("Marca: ${produto.nommrc}", style: const TextStyle(color: kTextSecondaryColor, fontSize: 13.5)),
                    ]
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: kPrimaryColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    border: Border.all(color: corEstoque.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  estoqueDisponivel ? "Estoque: ${produto.qtdetq}" : "Sem estoque",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: corEstoque),
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
        const Text("Quantidade", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5, color: kTextPrimaryColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _quantidadeController,
          focusNode: _quantidadeFocusNode,
          decoration: InputDecoration(
            hintText: "0",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 16, color: kTextPrimaryColor),
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
        const Text("Desconto (%)", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5, color: kTextPrimaryColor)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[350]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kPrimaryColor, width: 1.5)),
          ),
          style: const TextStyle(fontSize: 16, color: kTextPrimaryColor),
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
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
            backgroundColor: kPrimaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 1,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
    );
  }

  Widget _construirMensagemErroApi() {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: kErrorColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kErrorColor.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: kErrorColor.withOpacity(0.8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessageApi ?? "Ocorreu um erro desconhecido.",
              style: TextStyle(color: kErrorColor.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotaoCarrinhoFlutuante() {
    return Selector<Carrinho, int>(
      selector: (_, carrinho) => carrinho.quantidadeTotal,
      builder: (context, totalItens, child) {
        _logger.d("AdicionarProdutoScreen: _construirBotaoCarrinhoFlutuante rebuild. Total de itens: $totalItens");
        bool mostrarFab = totalItens > 0; // Mostrar apenas se houver itens

        if (!mostrarFab) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: _navegarParaCarrinho,
          backgroundColor: kPrimaryColor,
          elevation: 3,
          icon: Badge(
            label: Text('$totalItens', style: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: totalItens > 9 ? 4 : 6),
            isLabelVisible: totalItens > 0,
            child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
          ),
          label: const Text("VER CARRINHO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
        );
      },
    );
  }
}

// Extensão para selecionar todo o texto em um TextEditingController (coloque no final do arquivo ou em um arquivo de utils)
extension TextEditingControllerExtension on TextEditingController {
  void selectAll() {
    if (text.isEmpty) return;
    selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }
}