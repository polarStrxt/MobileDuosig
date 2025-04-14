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

  // Converter de Map (banco) para objeto
  factory CondicaoPagamento.fromMap(Map<String, dynamic> map) {
    return CondicaoPagamento(
      codcndpgt: map['codcndpgt'],
      dcrcndpgt: map['dcrcndpgt'],
      perdsccel: map['perdsccel'],
      staati: map['staati'],
    );
  }

  // Converter objeto para Map (para salvar no banco)
  Map<String, dynamic> toMap() {
    return {
      'codcndpgt': codcndpgt,
      'dcrcndpgt': dcrcndpgt,
      'perdsccel': perdsccel,
      'staati': staati,
    };
  }
}
