// lib/models/carrinho_item_model.dart

class CarrinhoItemModel {
  int? id; // Pode ser nulo se ainda não foi salvo no banco
  int idCarrinho;
  int codprd;
  int quantidade;
  double precoUnitarioRegistrado;
  double descontoItem;
  DateTime dataAdicao;

  CarrinhoItemModel({
    this.id,
    required this.idCarrinho,
    required this.codprd,
    required this.quantidade,
    required this.precoUnitarioRegistrado,
    this.descontoItem = 0.0,
    required this.dataAdicao,
  });

  factory CarrinhoItemModel.fromJson(Map<String, dynamic> map) {
    return CarrinhoItemModel(
      id: map['id'] as int?,
      idCarrinho: map['id_carrinho'] as int,
      codprd: map['codprd'] as int,
      quantidade: map['quantidade'] as int,
      precoUnitarioRegistrado: map['preco_unitario_registrado'] as double,
      descontoItem: map['desconto_item'] as double,
      dataAdicao: DateTime.parse(map['data_adicao'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // SQLite lida com ID nulo em inserts para autoincremento
      'id_carrinho': idCarrinho,
      'codprd': codprd,
      'quantidade': quantidade,
      'preco_unitario_registrado': precoUnitarioRegistrado,
      'desconto_item': descontoItem,
      'data_adicao': dataAdicao.toIso8601String(),
    };
  }

  // Helper para calcular subtotal do item, se útil
  double get subtotal {
    return (quantidade * precoUnitarioRegistrado) - descontoItem; // Assumindo que descontoItem é o valor total do desconto para a linha
  }
}