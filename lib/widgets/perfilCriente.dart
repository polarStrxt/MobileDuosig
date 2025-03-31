import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/widgets/infoCliente.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';

class ClientePerfil extends StatelessWidget {
  final Cliente cliente;

  const ClientePerfil({Key? key, required this.cliente}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Garantindo que os campos não sejam nulos
    String nome =
        cliente.nomcli.isNotEmpty ? cliente.nomcli : "Nome não disponível";
    String telefone =
        cliente.numtel001.isNotEmpty ? cliente.numtel001 : "Sem telefone";
    String endereco =
        cliente.endcli.isNotEmpty ? cliente.endcli : "Endereço não informado";

    // Obter iniciais para o avatar
    String iniciais = _obterIniciais(nome);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Infocliente(cliente: cliente),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          width: screenWidth * 0.9,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar com iniciais do cliente
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xFF5D5CDE),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    iniciais,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 16),

              // Informações do cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do cliente
                    Text(
                      nome,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 4),

                    // Telefone
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Text(
                          telefone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 2),

                    // Endereço
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            endereco,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Ícone para indicar que há mais informações
              Icon(
                Icons.chevron_right,
                color: Color(0xFF5D5CDE),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para obter as iniciais do nome
  String _obterIniciais(String nome) {
    if (nome == "Nome não disponível") return "?";

    List<String> partes = nome.split(' ');
    if (partes.length == 1) {
      return partes[0].substring(0, 1).toUpperCase();
    }

    return partes[0].substring(0, 1).toUpperCase() +
        partes[partes.length - 1].substring(0, 1).toUpperCase();
  }
}
