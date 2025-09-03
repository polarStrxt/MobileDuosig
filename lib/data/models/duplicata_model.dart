// Arquivo: lib/data/models/duplicata_model.dart

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

  /// Método para converter JSON da API para um objeto Duplicata
  factory Duplicata.fromJson(Map<String, dynamic> json) {
    return Duplicata(
      numdoc: json['numdoc']?.toString() ?? '',
      codcli: _parseInt(json['codcli']),
      dtavct: json['dtavct']?.toString() ?? '',
      vlrdpl: _parseDouble(json['vlrdpl']),
    );
  }

  /// Método para converter um objeto Duplicata para JSON
  Map<String, dynamic> toJson() {
    return {
      'numdoc': numdoc,
      'codcli': codcli,
      'dtavct': dtavct,
      'vlrdpl': vlrdpl,
    };
  }

  /// Helper para converter int com segurança
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  /// Helper para converter double com segurança
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Método para teste/debug
  factory Duplicata.teste({int? codcli}) {
    return Duplicata(
      numdoc: 'TESTE-${DateTime.now().millisecondsSinceEpoch}',
      codcli: codcli ?? 999,
      dtavct: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
      vlrdpl: 100.50,
    );
  }

  @override
  String toString() {
    return 'Duplicata{numdoc: $numdoc, codcli: $codcli, dtavct: $dtavct, vlrdpl: $vlrdpl}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Duplicata &&
        other.numdoc == numdoc &&
        other.codcli == codcli &&
        other.dtavct == dtavct &&
        other.vlrdpl == vlrdpl;
  }

  @override
  int get hashCode {
    return Object.hash(numdoc, codcli, dtavct, vlrdpl);
  }
}