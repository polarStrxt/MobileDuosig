import 'dart:convert'; // Para jsonEncode e jsonDecode

class RegistroPedidoLocal {
  final int? idPedidoLocal;
  final String codigoPedidoApp; // Seu numPedidoFinalGerado
  final Map<String, dynamic> jsonDoPedido; // Seu 'dadosPedido' original
  String statusEnvio;
  final DateTime dataCriacao;

  RegistroPedidoLocal({
    this.idPedidoLocal,
    required this.codigoPedidoApp,
    required this.jsonDoPedido,
    this.statusEnvio = 'PENDENTE',
    required this.dataCriacao,
  });

  // Converte para Map para salvar no SQFLite
  Map<String, dynamic> toMap() {
    return {
      // Não inclua 'id_pedido_local' se for nulo, para autoincrement funcionar
      if (idPedidoLocal != null) 'id_pedido_local': idPedidoLocal,
      'codigo_pedido_app': codigoPedidoApp,
      'json_do_pedido': jsonEncode(jsonDoPedido), // Converte o Map para String JSON
      'status_envio': statusEnvio,
      'data_criacao': dataCriacao.toIso8601String(),
    };
  }

  // Converte um Map (vindo do SQFLite) para um objeto RegistroPedidoLocal
  factory RegistroPedidoLocal.fromMap(Map<String, dynamic> map) {
    return RegistroPedidoLocal(
      idPedidoLocal: map['id_pedido_local'] as int?,
      codigoPedidoApp: map['codigo_pedido_app'] as String,
      jsonDoPedido: jsonDecode(map['json_do_pedido'] as String) as Map<String, dynamic>, // Converte String JSON de volta para Map
      statusEnvio: map['status_envio'] as String,
      dataCriacao: DateTime.parse(map['data_criacao'] as String),
    );
  }

  @override
  String toString() {
    return 'RegistroPedidoLocal(id: $idPedidoLocal, codigo: $codigoPedidoApp, status: $statusEnvio, json: $jsonDoPedido)';
  }
}