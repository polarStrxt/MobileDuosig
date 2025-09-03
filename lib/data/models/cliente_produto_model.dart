// lib/data/models/cliente_produto_model.dart

class ClienteProdutoModel {
  final int codcli;
  final int codprd;
  
  ClienteProdutoModel({
    required this.codcli,
    required this.codprd,
  });

  factory ClienteProdutoModel.fromJson(Map<String, dynamic> json) {
    return ClienteProdutoModel(
      codcli: json['codcli'],
      codprd: json['codprd'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codcli': codcli,
      'codprd': codprd,
    };
  }

  ClienteProdutoModel copyWith({
    int? codcli,
    int? codprd,
  }) {
    return ClienteProdutoModel(
      codcli: codcli ?? this.codcli,
      codprd: codprd ?? this.codprd,
    );
  }

  @override
  String toString() {
    return 'ClienteProdutoModel(codcli: $codcli, codprd: $codprd)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClienteProdutoModel &&
        other.codcli == codcli &&
        other.codprd == codprd;
  }

  @override
  int get hashCode => codcli.hashCode ^ codprd.hashCode;
}