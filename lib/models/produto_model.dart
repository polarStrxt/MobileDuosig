class Produto {
  final int codprd;
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

  Produto({
    required this.codprd,
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

  // 🔹 Converte JSON para objeto Produto
  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      codprd: json["codprd"],
      staati: json["staati"],
      dcrprd: json["dcrprd"],
      qtdmulvda: (json["qtdmulvda"] ?? 0),
      nommrc: json["nommrc"],
      vlrbasvda: (json["vlrbasvda"] ?? 0).toDouble(),
      qtdetq: (json["qtdetq"] ?? 0),
      vlrpmcprd: (json["vlrpmcprd"] ?? 0).toDouble(),
      dtaini: (json["dtaini"] ?? '0'),
      dtafin: (json["dtafin"] ?? '0'),
      vlrtab1: (json["vlrtab1"] ?? 0).toDouble(),
      vlrtab2: (json["vlrtab2"] ?? 0).toDouble(),
      peracrdsc1: (json["peracrdsc1"] ?? 0).toDouble(),
      peracrdsc2: (json["peracrdsc2"] ?? 0).toDouble(),
      codundprd: json["codundprd"],
      vol: json["vol"] ?? 1,
      qtdvol: json["qtdvol"] ?? 1,
      perdscmxm: (json["perdscmxm"] ?? 0).toDouble(),
    );
  }

  // 🔹 Converte Produto para JSON
  Map<String, dynamic> toJson() {
    return {
      "codprd": codprd,
      "staati": staati,
      "dcrprd": dcrprd,
      "qtdmulvda": qtdmulvda,
      "nommrc": nommrc,
      "vlrbasvda": vlrbasvda,
      "qtdetq": qtdetq,
      "vlrpmcprd": vlrpmcprd,
      "dtaini": dtaini,
      "dtafin": dtafin,
      "vlrtab1": vlrtab1,
      "vlrtab2": vlrtab2,
      "peracrdsc1": peracrdsc1,
      "peracrdsc2": peracrdsc2,
      "codundprd": codundprd,
      "vol": vol,
      "qtdvol": qtdvol,
      "perdscmxm": perdscmxm,
    };
  }
}
