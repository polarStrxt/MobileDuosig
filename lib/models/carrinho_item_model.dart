// lib/models/carrinho_item_model.dart

class CarrinhoItem {
  int? id; // ID único do item no carrinho
  int codprd; // Código do produto
  int codcli; // Código do cliente
  int quantidade;
  double desconto; // Desconto em porcentagem
  int finalizado; // 0 = não finalizado, 1 = finalizado
  DateTime dataCriacao; // Data de criação do item

  CarrinhoItem({
    this.id,
    required this.codprd,
    required this.codcli,
    required this.quantidade,
    this.desconto = 0.0,
    this.finalizado = 0,
    DateTime? dataCriacao,
  }) : this.dataCriacao = dataCriacao ?? DateTime.now();

  // Converter um objeto CarrinhoItem para Map (para salvar no banco)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codprd': codprd,
      'codcli': codcli,
      'quantidade': quantidade,
      'desconto': desconto,
      'finalizado': finalizado,
      'data_criacao': dataCriacao.toIso8601String(),
    };
  }

  // Criar um objeto CarrinhoItem a partir de um Map (ao ler do banco)
  factory CarrinhoItem.fromJson(Map<String, dynamic> json) {
    return CarrinhoItem(
      id: json['id'],
      codprd: json['codprd'],
      codcli: json['codcli'],
      quantidade: json['quantidade'],
      desconto: json['desconto'],
      finalizado: json['finalizado'],
      dataCriacao: DateTime.parse(json['data_criacao']),
    );
  }

  // Método para atualizar a quantidade
  void incrementarQuantidade(int valor) {
    quantidade += valor;
    if (quantidade < 1) quantidade = 1;
  }
}
