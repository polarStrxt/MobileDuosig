class Cliente {
  final int codcli;
  final String nomcli;
  final String cgccpfcli;
  final String ufdcli;
  final String endcli;
  final String baicli;
  final String muncli;
  final String numtel001;
  final String? numtel002;
  final String nomfnt;
  final String emailcli;
  final double vlrlimcrd;
  final int codtab;
  final int codcndpgt;
  final double vlrsldlimcrd;
  final double vlrdplabe;
  final double vlrdplats;
  final String staati;

  Cliente({
    required this.codcli,
    required this.nomcli,
    required this.cgccpfcli,
    required this.ufdcli,
    required this.endcli,
    required this.baicli,
    required this.muncli,
    required this.numtel001,
    this.numtel002,
    required this.nomfnt,
    required this.emailcli,
    required this.vlrlimcrd,
    required this.codtab,
    required this.codcndpgt,
    required this.vlrsldlimcrd,
    required this.vlrdplabe,
    required this.vlrdplats,
    required this.staati,
  });

  // ✅ Converte JSON para Cliente
  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      codcli: json['codcli'] ?? 0,
      nomcli: json['nomcli'] ?? "",
      cgccpfcli: json['cgccpfcli'] ?? "",
      ufdcli: json['ufdcli'] ?? "",
      endcli: json['endcli'] ?? "",
      baicli: json['baicli'] ?? "",
      muncli: json['muncli'] ?? "",
      numtel001: json['numtel001'] ?? "",
      numtel002: json['numtel002'], // Pode ser null
      nomfnt: json['nomfnt'] ?? "",
      emailcli: json['emailcli'] ?? "",
      vlrlimcrd: (json['vlrlimcrd'] ?? 0).toDouble(),
      codtab: json['codtab'] ?? 0,
      codcndpgt: json['codcndpgt'] ?? 0,
      vlrsldlimcrd: (json['vlrsldlimcrd'] ?? 0).toDouble(),
      vlrdplabe: (json['vlrdplabe'] ?? 0).toDouble(),
      vlrdplats: (json['vlrdplats'] ?? 0).toDouble(),
      staati: json['staati'] ?? "",
    );
  }

  // ✅ Converte Cliente para JSON
  Map<String, dynamic> toJson() {
    return {
      'codcli': codcli,
      'nomcli': nomcli,
      'cgccpfcli': cgccpfcli,
      'ufdcli': ufdcli,
      'endcli': endcli,
      'baicli': baicli,
      'muncli': muncli,
      'numtel001': numtel001,
      'numtel002': numtel002,
      'nomfnt': nomfnt,
      'emailcli': emailcli,
      'vlrlimcrd': vlrlimcrd,
      'codtab': codtab,
      'codcndpgt': codcndpgt,
      'vlrsldlimcrd': vlrsldlimcrd,
      'vlrdplabe': vlrdplabe,
      'vlrdplats': vlrdplats,
      'staati': staati,
    };
  }
}
