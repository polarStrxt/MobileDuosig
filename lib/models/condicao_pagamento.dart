class CondicaoPagamento {
  final int codcndpgt;
  final String dcrcndpgt;
  final double perdsccel;
  final String staati;

  CondicaoPagamento({
    required this.codcndpgt,
    required this.dcrcndpgt,
    required this.perdsccel,
    required this.staati,
  });

  // Renomeado de fromMap para fromJson e com melhorias de segurança
  factory CondicaoPagamento.fromJson(Map<String, dynamic> json) {
    return CondicaoPagamento(
      // Tenta converter para int. Se falhar ou for nulo, usa 0 como padrão.
      // Ajuste o valor padrão se fizer mais sentido ser outro (ex: -1) ou lançar um erro customizado.
      codcndpgt: (json['codcndpgt'] as num?)?.toInt() ?? 0,

      // Tenta converter para String. Se for nulo, usa uma string vazia como padrão.
      dcrcndpgt: json['dcrcndpgt'] as String? ?? '',

      // Tenta converter para double. Se falhar ou for nulo, usa 0.0 como padrão.
      perdsccel: (json['perdsccel'] as num?)?.toDouble() ?? 0.0,

      // Tenta converter para String. Se for nulo, usa uma string vazia como padrão.
      staati: json['staati'] as String? ?? '',
    );
  }

  // Seu método toMap está ótimo!
  // Apenas para consistência, se você renomeou fromJson,
  // poderia chamar este de toJson, mas toMap também é comum.
  Map<String, dynamic> toMap() {
    return {
      'codcndpgt': codcndpgt,
      'dcrcndpgt': dcrcndpgt,
      'perdsccel': perdsccel,
      'staati': staati,
    };
  }

  // (Opcional, mas útil se você também for usar json_serializable no futuro ou precisar de toJson)
  // Map<String, dynamic> toJson() => toMap(); // Simplesmente reusa o toMap
}