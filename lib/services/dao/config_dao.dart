class Config {
  final int? id;
  final String codVendedor;
  final String enderecoApi;
  final String usuarioDuosig;
  final String usuario;
  final String senha;

  Config({
    this.id,
    required this.codVendedor,
    required this.enderecoApi,
    required this.usuarioDuosig,
    required this.usuario,
    required this.senha,
  });

  // Cria um Campos a partir de um Map
  factory Config.fromMap(Map<String, dynamic> map) {
    return Config(
      id: map['id'],
      codVendedor: map['cod_vendedor'],
      enderecoApi: map['endereco_api'],
      usuarioDuosig: map['usuario_duosig'],
      usuario: map['usuario'],
      senha: map['senha'],
    );
  }

  // Converte um Campos para um Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_vendedor': codVendedor,
      'endereco_api': enderecoApi,
      'usuario_duosig': usuarioDuosig,
      'usuario': usuario,
      'senha': senha,
    };
  }

  // Método para criar uma cópia com algumas alterações
  Config copyWith({
    int? id,
    String? codVendedor,
    String? enderecoApi,
    String? usuarioDuosig,
    String? usuario,
    String? senha,
  }) {
    return Config(
      id: id ?? this.id,
      codVendedor: codVendedor ?? this.codVendedor,
      enderecoApi: enderecoApi ?? this.enderecoApi,
      usuarioDuosig: usuarioDuosig ?? this.usuarioDuosig,
      usuario: usuario ?? this.usuario,
      senha: senha ?? this.senha,
    );
  }
}