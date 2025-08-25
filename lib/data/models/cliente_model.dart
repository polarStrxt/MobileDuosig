class Cliente {
  final int codcli;
  final String nomcli;
  final String cgccpfcli;
  final String ufdcli;
  final String endcli;
  final String baicli;
  final String muncli;
  final String numtel001;
  final String? numtel002; // Corretamente nulável
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

  // Construtor para cliente "vazio" ou "não encontrado"
  Cliente.empty() :
    codcli = 0, // CORRIGIDO: Usando 0 como ID padrão para "vazio"
    nomcli = "Cliente Desconhecido", // Mensagem padrão
    cgccpfcli = "",
    ufdcli = "",
    endcli = "",
    baicli = "",
    muncli = "",
    numtel001 = "",
    numtel002 = null,
    nomfnt = "",
    emailcli = "",
    vlrlimcrd = 0.0,
    codtab = 0,
    codcndpgt = 0,
    vlrsldlimcrd = 0.0,
    vlrdplabe = 0.0,
    vlrdplats = 0.0,
    staati = "";

  // Converte JSON para Cliente
  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      codcli: json['codcli'] as int? ?? 0, // Garante que é int, default para 0 se null
      nomcli: json['nomcli'] as String? ?? "",
      cgccpfcli: json['cgccpfcli'] as String? ?? "",
      ufdcli: json['ufdcli'] as String? ?? "",
      endcli: json['endcli'] as String? ?? "",
      baicli: json['baicli'] as String? ?? "",
      muncli: json['muncli'] as String? ?? "",
      numtel001: json['numtel001'] as String? ?? "",
      numtel002: json['numtel002'] as String?, // Pode ser null
      nomfnt: json['nomfnt'] as String? ?? "",
      emailcli: json['emailcli'] as String? ?? "",
      vlrlimcrd: (json['vlrlimcrd'] as num? ?? 0).toDouble(),
      codtab: json['codtab'] as int? ?? 0,
      codcndpgt: json['codcndpgt'] as int? ?? 0,
      vlrsldlimcrd: (json['vlrsldlimcrd'] as num? ?? 0).toDouble(),
      vlrdplabe: (json['vlrdplabe'] as num? ?? 0).toDouble(),
      vlrdplats: (json['vlrdplats'] as num? ?? 0).toDouble(),
      staati: json['staati'] as String? ?? "",
    );
  }

  // Converte Cliente para JSON
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