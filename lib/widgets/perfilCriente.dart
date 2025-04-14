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
    String municipio =
        cliente.muncli.isNotEmpty ? cliente.muncli : "Município não informado";
    String codigo = cliente.codcli.toString();
    String bairro = cliente.baicli.isNotEmpty ? cliente.baicli : "";

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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome do cliente e código
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          // Permitindo que o nome quebre a linha
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Código: $codigo",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ícone para indicar que há mais informações
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF5D5CDE),
                    size: 24,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Telefone
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      telefone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Endereço
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      endereco,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      // Removido o maxLines e overflow para permitir quebra de linha
                    ),
                  ),
                ],
              ),

              // Bairro (se disponível)
              if (bairro.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    bairro,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 6),

              // Município
              Row(
                children: [
                  Icon(
                    Icons.location_city,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    municipio,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  // UF (se disponível)
                  if (cliente.ufdcli.isNotEmpty) ...[
                    Text(
                      " - ${cliente.ufdcli}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
