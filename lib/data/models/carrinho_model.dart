// lib/models/carrinho_model.dart

class CarrinhoModel {
  int? id; // Pode ser nulo se ainda não foi salvo no banco
  int codcli;
  DateTime dataCriacao;
  DateTime dataUltimaModificacao;
  String status;
  int? cupomDescontoId; // Opcional
  double? valorTotalBruto; // Opcional, pode ser calculado
  double? valorTotalDescontos; // Opcional
  double? valorTotalLiquido; // Opcional
  String? observacoes; // Opcional

  CarrinhoModel({
    this.id,
    required this.codcli,
    required this.dataCriacao,
    required this.dataUltimaModificacao,
    required this.status,
    this.cupomDescontoId,
    this.valorTotalBruto,
    this.valorTotalDescontos,
    this.valorTotalLiquido,
    this.observacoes,
  });

  factory CarrinhoModel.fromJson(Map<String, dynamic> map) {
    return CarrinhoModel(
      id: map['id'] as int?,
      codcli: map['codcli'] as int,
      dataCriacao: DateTime.parse(map['data_criacao'] as String),
      dataUltimaModificacao: DateTime.parse(map['data_ultima_modificacao'] as String),
      status: map['status'] as String,
      cupomDescontoId: map['cupom_desconto_id'] as int?,
      valorTotalBruto: map['valor_total_bruto'] as double?,
      valorTotalDescontos: map['valor_total_descontos'] as double?,
      valorTotalLiquido: map['valor_total_liquido'] as double?,
      observacoes: map['observacoes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // SQLite lida com ID nulo em inserts para autoincremento
      'codcli': codcli,
      'data_criacao': dataCriacao.toIso8601String(),
      'data_ultima_modificacao': dataUltimaModificacao.toIso8601String(),
      'status': status,
      'cupom_desconto_id': cupomDescontoId,
      'valor_total_bruto': valorTotalBruto,
      'valor_total_descontos': valorTotalDescontos,
      'valor_total_liquido': valorTotalLiquido,
      'observacoes': observacoes,
    };
  }
}