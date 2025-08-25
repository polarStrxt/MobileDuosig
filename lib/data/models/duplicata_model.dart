// Arquivo: lib/home/duplicata_model.dart

class Duplicata {
  final String numdoc;
  final int codcli;
  final String dtavct;
  final double vlrdpl;

  Duplicata({
    required this.numdoc,
    required this.codcli,
    required this.dtavct,
    required this.vlrdpl,
  });

  // Método para converter JSON da API para um objeto Duplicata
  factory Duplicata.fromJson(Map<String, dynamic> json) {
    return Duplicata(
      numdoc: json['numdoc'],
      codcli: json['codcli'],
      dtavct: json['dtavct'],
      vlrdpl: (json['vlrdpl'] as num).toDouble(),
    );
  }

  // Método para converter um objeto Duplicata para JSON (se necessário)
  Map<String, dynamic> toJson() {
    return {
      'numdoc': numdoc,
      'codcli': codcli,
      'dtavct': dtavct,
      'vlrdpl': vlrdpl,
    };
  }
}
