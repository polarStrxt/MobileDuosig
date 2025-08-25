class Cliente_Produto {
  final int codcli;
  final int codprd;
  
  Cliente_Produto({
    required this.codcli,
    required this.codprd
  });

  factory Cliente_Produto.fromJson(Map<String, dynamic> json){
    return Cliente_Produto(
      codcli: json['codcli'],
      codprd: json['codprd']
    );
  }

  Map<String,dynamic> toJson(){
    return{
      'codcli':codcli,
      'codprd':codprd,
    };
  }
}