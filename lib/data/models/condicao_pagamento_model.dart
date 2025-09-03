class CondicaoPagamentoModel {
  final int codcndpgt;
  final String dcrcndpgt;
  final double perdsccel;
  final String staati;

  CondicaoPagamentoModel({
    required this.codcndpgt,
    required this.dcrcndpgt,
    required this.perdsccel,
    required this.staati,
  });

  factory CondicaoPagamentoModel.fromJson(Map<String, dynamic> json) {
    return CondicaoPagamentoModel(
      codcndpgt: json['codcndpgt'],
      dcrcndpgt: json['dcrcndpgt'],
      perdsccel: (json['perdsccel'] ?? 0.0).toDouble(),
      staati: json['staati'],
    );
  }

  // Adicione este método se não existir:
  Map<String, dynamic> toJson() {
    return {
      'codcndpgt': codcndpgt,
      'dcrcndpgt': dcrcndpgt,
      'perdsccel': perdsccel,
      'staati': staati,
    };
  }
}