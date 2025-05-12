// lib/widgets/carrinho_widget.dart (Nome de arquivo sugerido)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Pacote para gerenciamento de estado
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/services/carrinhoService.dart';
import 'package:flutter_docig_venda/widgets/carrinho.dart'; // Sua classe Carrinho (ChangeNotifier)
import 'package:flutter_docig_venda/services/api_client.dart'; // Onde ApiResult está definido
import 'package:logger/logger.dart'; // Para logging

class CarrinhoWidget extends StatefulWidget {
  final Cliente cliente;

  // Construtor com super.key
  const CarrinhoWidget({super.key, required this.cliente});

  @override
  State<CarrinhoWidget> createState() => _CarrinhoWidgetState();
}

class _CarrinhoWidgetState extends State<CarrinhoWidget> {
  final CarrinhoService _carrinhoService = CarrinhoService(); // Idealmente injetado
  final Logger _logger = Logger();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Garante que o carregamento ocorra após o primeiro build, se necessário
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (mounted) { // Checa se o widget ainda está montado
           _carregarCarrinhoDoBanco();
       }
    });
  }

  Future<void> _carregarCarrinhoDoBanco() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Acessa o provider SEM ouvir mudanças aqui, pois vamos atualizar o estado
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final resultado = await _carrinhoService.recuperarCarrinho(widget.cliente);

    if (!mounted) return;

    // ----- Correção Aqui: usar resultado.isSuccess -----
    if (resultado.isSuccess && resultado.data != null) {
      carrinhoProvider.limpar(); // Limpa antes de popular

      resultado.data!.itens.forEach((produto, quantidade) {
        final descontoPercentual = resultado.data!.descontos[produto] ?? 0.0;
        // Assumindo que adicionarItem notifica listeners. Se não, veja comentário abaixo.
        carrinhoProvider.adicionarItem(produto, quantidade, descontoPercentual);
      });
      // Se seu método adicionarItem NÃO notifica, e você quer apenas uma reconstrução
      // da UI após carregar tudo, você precisaria de um método que não notifica
      // e chamar carrinhoProvider.notifyListeners(); aqui.
      _logger.i("Carrinho carregado do banco para a UI.");
    } else {
      _errorMessage = resultado.errorMessage ?? "Falha ao carregar carrinho.";
      _logger.e("Erro ao carregar carrinho inicial: $_errorMessage");
      if(mounted) { // Checa novamente antes de mostrar o SnackBar
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(_errorMessage ?? "Erro desconhecido.")),
           );
       }
    }

    setState(() => _isLoading = false);
  }

  /// Persiste o estado atual do carrinho (do Provider) no banco de dados.
  Future<void> _persistirAlteracoesCarrinho() async {
    if (!mounted) return;
    // Opcional: mostrar um indicador sutil de salvamento
    // setState(() => _isSaving = true);

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    final resultado = await _carrinhoService.salvarAlteracoesCarrinho(
        carrinhoProvider, widget.cliente);

    if (!mounted) return;
    // Opcional: esconder indicador de salvamento
    // setState(() => _isSaving = false);

    // ----- Correção Aqui: usar resultado.isSuccess -----
    if (!resultado.isSuccess) {
      _errorMessage = resultado.errorMessage ?? "Falha ao salvar carrinho.";
      _logger.e("Erro ao salvar alterações do carrinho: $_errorMessage");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage ?? "Erro desconhecido.")),
      );
    } else {
      _logger.i("Alterações do carrinho salvas com sucesso no banco.");
    }
  }

  // --- Métodos de interação da UI ---

  // Comentado para evitar erro 'unused_element'. Descomente quando for usar na UI.
  /*
  void _handleAdicionarItem(ProdutoModel produto, int quantidade, double descontoPercentual) {
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.adicionarItem(produto, quantidade, descontoPercentual);
    _persistirAlteracoesCarrinho(); // Salva o estado completo no banco
  }
  */

  void _handleRemoverItem(ProdutoModel produto) {
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.removerItem(produto);
    _persistirAlteracoesCarrinho();
  }

  void _handleAtualizarQuantidade(ProdutoModel produto, int novaQuantidade) {
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.atualizarQuantidade(produto, novaQuantidade);
    _persistirAlteracoesCarrinho();
  }

  // Comentado para evitar erro 'unused_element'. Descomente quando for usar na UI.
  /*
  void _handleAtualizarDesconto(ProdutoModel produto, double novoDescontoPercentual) {
    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    carrinhoProvider.atualizarDesconto(produto, novoDescontoPercentual);
    _persistirAlteracoesCarrinho();
  }
  */

  Future<void> _handleFinalizarPedido() async {
    if (!mounted) return;
    setState(() => _isLoading = true); // Mostra loading ao finalizar

    final carrinhoProvider = Provider.of<Carrinho>(context, listen: false);
    if (carrinhoProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Carrinho está vazio!")),
      );
      setState(() => _isLoading = false);
      return;
    }

    final resultado = await _carrinhoService.finalizarCarrinho(widget.cliente);
    if (!mounted) return;

    // ----- Correção Aqui: usar resultado.isSuccess -----
    if (resultado.isSuccess) {
      _logger.i("Pedido finalizado com sucesso para cliente ${widget.cliente.codcli}");
      carrinhoProvider.limpar(); // Limpa o carrinho da UI após finalizar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido finalizado com sucesso!")),
      );
      // TODO: Navegar para outra tela ou atualizar estado geral do app
    } else {
      _errorMessage = resultado.errorMessage ?? "Falha ao finalizar pedido.";
      _logger.e("Erro ao finalizar pedido: $_errorMessage");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage ?? "Erro desconhecido.")),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Consumer<Carrinho> ouve o seu Carrinho (ChangeNotifier) e reconstrói
    // apenas esta parte da árvore quando ele notifica mudanças.
    return Consumer<Carrinho>(
      builder: (context, carrinhoUi, child) {
        // Feedback de Loading e Erro
        if (_isLoading && carrinhoUi.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        // Se não está carregando e está vazio E houve erro no carregamento
        if (_errorMessage != null && carrinhoUi.isEmpty && !_isLoading) {
             return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Erro ao carregar: $_errorMessage\nTente novamente mais tarde.", textAlign: TextAlign.center),
                )
             );
        }
        // Se não está carregando e está vazio (sem erro prévio)
        if (carrinhoUi.isEmpty && !_isLoading) {
          return const Center(child: Text("Seu carrinho está vazio."));
        }

        // --- Construção da UI do Carrinho ---
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: carrinhoUi.itens.length,
                itemBuilder: (context, index) {
                  ProdutoModel produto = carrinhoUi.itens.keys.elementAt(index);
                  int quantidade = carrinhoUi.itens[produto] ?? 0;
                  double descontoPercentual = carrinhoUi.descontos[produto] ?? 0.0;
                  // Usa o codtab do cliente atual (removido '!' desnecessário se codtab for não-nulável)
                  double precoFinalUnitario = carrinhoUi.precoUnitarioComDesconto(produto, widget.cliente.codtab);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      title: Text(produto.dcrprd),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Qtd: $quantidade (Unit: R\$ ${precoFinalUnitario.toStringAsFixed(2)})"),
                          if (descontoPercentual > 0)
                            Text("Desconto Aplicado: ${descontoPercentual.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.green)),
                          Text("Subtotal Linha: R\$ ${(precoFinalUnitario * quantidade).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            tooltip: "Diminuir Quantidade",
                            onPressed: () {
                              if (quantidade > 0) { // Evita ir para 0 aqui, pois handle já trata <=0
                                _handleAtualizarQuantidade(produto, quantidade - 1);
                              }
                            },
                          ),
                           // Adicionar botão para aumentar quantidade (Exemplo)
                           IconButton(
                             icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                             tooltip: "Aumentar Quantidade",
                             onPressed: () {
                               _handleAtualizarQuantidade(produto, quantidade + 1);
                             },
                           ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                             tooltip: "Remover Item",
                            onPressed: () => _handleRemoverItem(produto),
                          ),
                        ],
                      ),
                      // TODO: Adicionar controles para editar desconto, etc., se necessário.
                    ),
                  );
                },
              ),
            ),
            // --- Sumário do Carrinho ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "RESUMO DO PEDIDO",
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                         textAlign: TextAlign.center,
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Subtotal:"),
                          // Removido '!' desnecessário se codtab for não-nulável
                          Text("R\$ ${carrinhoUi.calcularSubtotal(widget.cliente.codtab).toStringAsFixed(2)}"),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Descontos:", style: TextStyle(color: Colors.green)),
                           // Removido '!' desnecessário se codtab for não-nulável
                          Text("- R\$ ${carrinhoUi.calcularTotalDescontosValor(widget.cliente.codtab).toStringAsFixed(2)}", style: const TextStyle(color: Colors.green)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Valor Total:", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                           // Removido '!' desnecessário se codtab for não-nulável
                          Text(
                            "R\$ ${carrinhoUi.calcularValorTotal(widget.cliente.codtab).toStringAsFixed(2)}",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: _isLoading
                            ? Container( // Container para dar tamanho ao SizedBox
                                width: 24,
                                height: 24,
                                padding: const EdgeInsets.all(2.0),
                                child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_isLoading ? "Finalizando..." : "Finalizar Pedido"),
                        onPressed: _isLoading || carrinhoUi.isEmpty ? null : _handleFinalizarPedido,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          // backgroundColor: Colors.green, // Exemplo de cor
                          // foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}