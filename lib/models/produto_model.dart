// lib/models/produto_model.dart

class ProdutoModel {
  final int? codprd;
  final String staati;
  final String dcrprd;
  final int qtdmulvda;
  final String nommrc;
  final double vlrbasvda;
  final int? qtdetq;
  final double vlrpmcprd;
  final String? dtaini;
  final String? dtafin;
  final double vlrtab1;
  final double vlrtab2;
  final double peracrdsc1;
  final double peracrdsc2;
  final String codundprd;
  final int vol;
  final int qtdvol;
  final double perdscmxm;

  ProdutoModel({
    this.codprd,
    required this.staati,
    required this.dcrprd,
    required this.qtdmulvda,
    required this.nommrc,
    required this.vlrbasvda,
    this.qtdetq,
    required this.vlrpmcprd,
    this.dtaini,
    this.dtafin,
    required this.vlrtab1,
    required this.vlrtab2,
    required this.peracrdsc1,
    required this.peracrdsc2,
    required this.codundprd,
    required this.vol,
    required this.qtdvol,
    required this.perdscmxm,
  });

  factory ProdutoModel.fromJson(Map<String, dynamic> map) {
    return ProdutoModel(
      codprd: map['codprd'] as int?,
      staati: map['staati'] as String,
      dcrprd: map['dcrprd'] as String,
      qtdmulvda: map['qtdmulvda'] as int,
      nommrc: map['nommrc'] as String,
      vlrbasvda: map['vlrbasvda'] as double,
      qtdetq: map['qtdetq'] as int?,
      vlrpmcprd: map['vlrpmcprd'] as double,
      dtaini: map['dtaini'] as String?,
      dtafin: map['dtafin'] as String?,
      vlrtab1: map['vlrtab1'] as double,
      vlrtab2: map['vlrtab2'] as double,
      peracrdsc1: map['peracrdsc1'] as double,
      peracrdsc2: map['peracrdsc2'] as double,
      codundprd: map['codundprd'] as String,
      vol: map['vol'] as int,
      qtdvol: map['qtdvol'] as int,
      perdscmxm: map['perdscmxm'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codprd': codprd,
      'staati': staati,
      'dcrprd': dcrprd,
      'qtdmulvda': qtdmulvda,
      'nommrc': nommrc,
      'vlrbasvda': vlrbasvda,
      'qtdetq': qtdetq,
      'vlrpmcprd': vlrpmcprd,
      'dtaini': dtaini,
      'dtafin': dtafin,
      'vlrtab1': vlrtab1,
      'vlrtab2': vlrtab2,
      'peracrdsc1': peracrdsc1,
      'peracrdsc2': peracrdsc2,
      'codundprd': codundprd,
      'vol': vol,
      'qtdvol': qtdvol,
      'perdscmxm': perdscmxm,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoModel &&
          runtimeType == other.runtimeType &&
          codprd == other.codprd &&
          codprd != null;

  @override
  int get hashCode => codprd.hashCode;

  // V V V ADICIONE OU VERIFIQUE ESTE MÉTODO V V V
  /// Retorna o preço do produto baseado na tabela de preço do cliente.
  ///
  /// [clienteTabela] deve ser 1 para `vlrtab1` ou 2 (ou qualquer outro valor) para `vlrtab2`.
  double getPrecoParaTabela(int clienteTabela) {
    if (clienteTabela == 1) {
      return vlrtab1;
    } else {
      // Assume vlrtab2 para qualquer outro valor de clienteTabela (ou adicione mais lógica se necessário)
      return vlrtab2;
    }
  }
  // ^ ^ ^ ADICIONE OU VERIFIQUE ESTE MÉTODO ^ ^ ^
}