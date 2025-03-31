import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PdfGenerator {
  // Variável para armazenar o último contexto usado
  static BuildContext? _ultimoContexto;

  // Método original para compatibilidade com código existente
  static Future<String?> gerarPdf(
      Map<Produto, int> itens, Map<Produto, double> descontos,
      [Cliente? cliente]) async {
    try {
      print("📌 Iniciando geração de PDF...");
      print(
          "📌 itens: ${itens.length}, descontos: ${descontos.length}, cliente: ${cliente?.codcli ?? 'nulo'}");

      // Verificar se temos um contexto armazenado
      if (_ultimoContexto == null) {
        print(
            "⚠️ Aviso: Nenhum contexto disponível para exibir o PDF automaticamente");
        return await _gerarPdfSemContexto(itens, descontos, cliente);
      }

      print("📌 Usando contexto armazenado para gerar PDF");
      // Usar o último contexto armazenado para chamar a versão completa
      try {
        return await gerarPdfComContexto(
            _ultimoContexto!, itens, descontos, cliente);
      } catch (e) {
        print("❌ Erro ao chamar gerarPdfComContexto: $e");
        // Fallback para método sem contexto
        return await _gerarPdfSemContexto(itens, descontos, cliente);
      }
    } catch (e) {
      print("❌ Erro inicial no gerarPdf: $e");
      return null;
    }
  }

  // Novo método que aceita um contexto
  static Future<String?> gerarPdfComContexto(BuildContext context,
      Map<Produto, int> itens, Map<Produto, double> descontos,
      [Cliente? cliente]) async {
    print("📌 Iniciando gerarPdfComContexto");

    // Armazena o contexto para uso futuro
    _ultimoContexto = context;

    // Verificar valores nulos
    if (itens.isEmpty) {
      print("❌ Erro: Itens não podem ser vazios");
      return null;
    }

    try {
      print("📌 Exibindo diálogo de progresso");
      // Mostrar indicador de progresso
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Gerando PDF..."),
                ],
              ),
            );
          },
        );
      } catch (dialogError) {
        print("⚠️ Erro ao mostrar diálogo: $dialogError");
        // Continuar mesmo se falhar ao mostrar o diálogo
      }

      print("📌 Criando documento PDF");
      // Criar o documento PDF
      final pdf = pw.Document();

      // Data atual formatada manualmente
      final DateTime agora = DateTime.now();
      final String dataFormatada =
          "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
      final String dataArquivo =
          "${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}${agora.second.toString().padLeft(2, '0')}";

      print("📌 Calculando valores totais");
      // Calcular valores totais
      final tabelaPreco = cliente?.codtab ?? 1;

      double totalSemDesconto = 0.0;
      double totalComDesconto = 0.0;

      itens.forEach((produto, quantidade) {
        // Usar o preço baseado na tabela do cliente
        final double precoBase =
            tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
        final double desconto = descontos[produto] ?? 0.0;
        final double precoComDesconto = precoBase * (1 - desconto / 100);

        totalSemDesconto += precoBase * quantidade;
        totalComDesconto += precoComDesconto * quantidade;
      });

      // Função para formatar valores monetários
      String formatarMoeda(double valor) {
        return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
      }

      print("📌 Adicionando páginas ao PDF");
      // Criar páginas do PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Cabeçalho
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Nome da empresa
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DociBoy Distribuição",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Pedido de Venda",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),

                  // Data e informações do pedido
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Data: $dataFormatada",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Tabela de preço: $tabelaPreco",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Informações do cliente (se disponível)
              if (cliente != null)
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DADOS DO CLIENTE",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text("Código: ${cliente.codcli}"),
                          ),
                          pw.Expanded(
                            child: pw.Text("Nome: ${cliente.nomcli}"),
                          ),
                        ],
                      ),
                      if (cliente.endcli != null && cliente.endcli!.isNotEmpty)
                        pw.Text("Endereço: ${cliente.endcli}"),
                    ],
                  ),
                ),

              pw.SizedBox(height: 15),

              // Título da lista de produtos
              pw.Center(
                child: pw.Text(
                  "ITENS DO PEDIDO",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),

              pw.SizedBox(height: 10),

              // Tabela de produtos com formatação simplificada
              pw.TableHelper.fromTextArray(
                headers: [
                  'Código',
                  'Produto',
                  'Qtd',
                  'Preço Un.',
                  'Desc.',
                  'Total'
                ],
                data: itens.entries.map((entry) {
                  final produto = entry.key;
                  final quantidade = entry.value;
                  final precoBase =
                      tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
                  final desconto = descontos[produto] ?? 0.0;
                  final precoComDesconto = precoBase * (1 - desconto / 100);
                  final total = precoComDesconto * quantidade;

                  return [
                    produto.codprd,
                    produto.dcrprd,
                    quantidade.toString(),
                    formatarMoeda(precoBase),
                    desconto > 0 ? "${desconto.toStringAsFixed(1)}%" : "-",
                    formatarMoeda(total),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
                cellStyle: pw.TextStyle(
                  fontSize: 10,
                ),
                border: pw.TableBorder.all(color: PdfColors.grey400),
              ),

              pw.SizedBox(height: 20),

              // Resumo financeiro
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Subtotal:"),
                        pw.Text(formatarMoeda(totalSemDesconto)),
                      ],
                    ),
                    if (totalSemDesconto > totalComDesconto)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Descontos:"),
                          pw.Text(
                              "- ${formatarMoeda(totalSemDesconto - totalComDesconto)}"),
                        ],
                      ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          formatarMoeda(totalComDesconto),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Assinaturas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text("Assinatura do Vendedor"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text("Assinatura do Cliente"),
                    ],
                  ),
                ],
              ),

              // Rodapé com número de página
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  "Página ${context.pageNumber} de ${context.pagesCount}",
                  style: pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 9,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      try {
        print("📌 Tentando fechar o diálogo de progresso");
        // Tentar fechar o diálogo de progresso
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e) {
        print("⚠️ Aviso: Não foi possível fechar o diálogo: $e");
      }

      print("📌 Salvando o PDF");
      // Salvar o PDF no dispositivo
      final pdfBytes = await pdf.save();
      final fileName = "Pedido_$dataArquivo.pdf";

      print("📌 Salvando no armazenamento interno");
      // Tentar salvar direto no armazenamento interno do app (mais seguro)
      try {
        print("📌 Obtendo diretório de documentos do app");
        final diretorioDocumentos = await getApplicationDocumentsDirectory();
        if (diretorioDocumentos != null) {
          print(
              "📌 Criando subdiretório: ${diretorioDocumentos.path}/DociBoy_PDFs");
          final subDiretorio =
              Directory("${diretorioDocumentos.path}/DociBoy_PDFs");
          if (!await subDiretorio.exists()) {
            await subDiretorio.create(recursive: true);
          }
          final filePath = "${subDiretorio.path}/$fileName";

          print("📌 Escrevendo arquivo em: $filePath");
          // Escrever arquivo
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          print("✅ PDF gerado e salvo no armazenamento interno: ${file.path}");

          // Agora, tente exibir o PDF
          try {
            print("📌 Tentando exibir o PDF");
            exibirPdf(context, file.path, "Pedido de Venda");
          } catch (displayError) {
            print("⚠️ Não foi possível exibir o PDF: $displayError");
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      "PDF salvo, mas não foi possível exibi-lo. Salvo em: ${file.path}"),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Compartilhar',
                    onPressed: () {
                      compartilharPdf(file.path);
                    },
                  ),
                ),
              );
            } catch (snackBarError) {
              print("⚠️ Erro ao mostrar SnackBar: $snackBarError");
            }
          }

          return file.path;
        } else {
          print("❌ diretorioDocumentos é nulo!");
          throw Exception("Não foi possível obter o diretório de documentos");
        }
      } catch (internalError) {
        print("⚠️ Erro ao salvar no armazenamento interno: $internalError");

        print("📌 Tentando armazenamento temporário como última alternativa");
        // Último recurso: salvar em cache
        try {
          print("📌 Obtendo diretório temporário");
          final diretorioTemp = await getTemporaryDirectory();
          print("📌 Diretório temp: ${diretorioTemp.path}");
          final subDiretorio = Directory("${diretorioTemp.path}/DociBoy_PDFs");
          if (!await subDiretorio.exists()) {
            await subDiretorio.create(recursive: true);
          }
          final filePath = "${subDiretorio.path}/$fileName";

          print("📌 Escrevendo arquivo em: $filePath");
          // Escrever arquivo
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          print("✅ PDF gerado e salvo no cache: ${file.path}");

          // Exibir o PDF
          try {
            exibirPdf(context, file.path, "Pedido de Venda");
          } catch (displayError) {
            print("⚠️ Erro ao exibir PDF: $displayError");
          }

          // Informar ao usuário
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "PDF salvo temporariamente. Use a opção de compartilhar para salvá-lo permanentemente.",
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          } catch (snackBarError) {
            print("⚠️ Erro ao mostrar SnackBar: $snackBarError");
          }

          return file.path;
        } catch (tempError) {
          print("❌ Erro fatal ao salvar PDF: $tempError");
          throw Exception(
              "Não foi possível salvar o PDF em nenhum local: $tempError");
        }
      }
    } catch (e) {
      print("❌ Erro detalhado ao gerar PDF: $e");
      print("❌ Tipo de erro: ${e.runtimeType}");

      if (e is Error) {
        print("❌ Stack trace: ${e.stackTrace}");
      }

      // Garantir que o diálogo de progresso seja fechado em caso de erro
      try {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (_) {
        // Ignorar erros ao fechar o diálogo
      }

      // Mostrar erro ao usuário
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao gerar PDF: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 8),
          ),
        );
      } catch (snackBarError) {
        print("⚠️ Erro ao mostrar SnackBar de erro: $snackBarError");
      }

      return null;
    }
  }

  // Versão que não requer contexto - para compatibilidade com código legado
  static Future<String?> _gerarPdfSemContexto(
      Map<Produto, int> itens, Map<Produto, double> descontos,
      [Cliente? cliente]) async {
    print("📌 Iniciando _gerarPdfSemContexto");

    if (itens.isEmpty) {
      print("❌ Erro: Itens não podem ser vazios");
      return null;
    }

    try {
      // Criar o documento PDF
      final pdf = pw.Document();

      // Data atual formatada manualmente
      final DateTime agora = DateTime.now();
      final String dataFormatada =
          "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
      final String dataArquivo =
          "${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}${agora.second.toString().padLeft(2, '0')}";

      // Calcular valores totais
      final tabelaPreco = cliente?.codtab ?? 1;

      double totalSemDesconto = 0.0;
      double totalComDesconto = 0.0;

      itens.forEach((produto, quantidade) {
        // Usar o preço baseado na tabela do cliente
        final double precoBase =
            tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
        final double desconto = descontos[produto] ?? 0.0;
        final double precoComDesconto = precoBase * (1 - desconto / 100);

        totalSemDesconto += precoBase * quantidade;
        totalComDesconto += precoComDesconto * quantidade;
      });

      // Função para formatar valores monetários
      String formatarMoeda(double valor) {
        return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
      }

      // Criar páginas do PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              // Cabeçalho
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Nome da empresa
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DociBoy Distribuição",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        "Pedido de Venda",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),

                  // Data e informações do pedido
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Data: $dataFormatada",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        "Tabela de preço: $tabelaPreco",
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Informações do cliente (se disponível)
              if (cliente != null)
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "DADOS DO CLIENTE",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text("Código: ${cliente.codcli}"),
                          ),
                          pw.Expanded(
                            child: pw.Text("Nome: ${cliente.nomcli}"),
                          ),
                        ],
                      ),
                      if (cliente.endcli != null && cliente.endcli!.isNotEmpty)
                        pw.Text("Endereço: ${cliente.endcli}"),
                    ],
                  ),
                ),

              pw.SizedBox(height: 15),

              // Título da lista de produtos
              pw.Center(
                child: pw.Text(
                  "ITENS DO PEDIDO",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),

              pw.SizedBox(height: 10),

              // Tabela de produtos com formatação simplificada
              pw.TableHelper.fromTextArray(
                headers: [
                  'Código',
                  'Produto',
                  'Qtd',
                  'Preço Un.',
                  'Desc.',
                  'Total'
                ],
                data: itens.entries.map((entry) {
                  final produto = entry.key;
                  final quantidade = entry.value;
                  final precoBase =
                      tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
                  final desconto = descontos[produto] ?? 0.0;
                  final precoComDesconto = precoBase * (1 - desconto / 100);
                  final total = precoComDesconto * quantidade;

                  return [
                    produto.codprd,
                    produto.dcrprd,
                    quantidade.toString(),
                    formatarMoeda(precoBase),
                    desconto > 0 ? "${desconto.toStringAsFixed(1)}%" : "-",
                    formatarMoeda(total),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
                cellStyle: pw.TextStyle(
                  fontSize: 10,
                ),
                border: pw.TableBorder.all(color: PdfColors.grey400),
              ),

              pw.SizedBox(height: 20),

              // Resumo financeiro
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Subtotal:"),
                        pw.Text(formatarMoeda(totalSemDesconto)),
                      ],
                    ),
                    if (totalSemDesconto > totalComDesconto)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Descontos:"),
                          pw.Text(
                              "- ${formatarMoeda(totalSemDesconto - totalComDesconto)}"),
                        ],
                      ),
                    pw.Divider(),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          formatarMoeda(totalComDesconto),
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14,
                            color: PdfColors.blue900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Assinaturas
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text("Assinatura do Vendedor"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text("Assinatura do Cliente"),
                    ],
                  ),
                ],
              ),

              // Rodapé com número de página
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  "Página ${context.pageNumber} de ${context.pagesCount}",
                  style: pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 9,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      print("📌 Salvando o PDF");
      // Salvar o PDF no dispositivo
      final pdfBytes = await pdf.save();
      final fileName = "Pedido_$dataArquivo.pdf";

      print("📌 Tentando salvar no diretório de documentos do app");
      // Primeiro, tentar salvar no armazenamento interno do app (mais seguro)
      try {
        final diretorioDocumentos = await getApplicationDocumentsDirectory();
        if (diretorioDocumentos != null) {
          final subDiretorio =
              Directory("${diretorioDocumentos.path}/DociBoy_PDFs");
          if (!await subDiretorio.exists()) {
            await subDiretorio.create(recursive: true);
          }
          final filePath = "${subDiretorio.path}/$fileName";

          // Escrever arquivo
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          print("✅ PDF gerado e salvo em armazenamento interno: ${file.path}");

          // Se tivermos um contexto salvo, tentar mostrar o PDF
          if (_ultimoContexto != null) {
            try {
              exibirPdf(_ultimoContexto!, file.path, "Pedido de Venda");
            } catch (e) {
              print("⚠️ Não foi possível exibir o PDF: $e");
            }
          }

          return file.path;
        } else {
          print("❌ diretorioDocumentos é nulo!");
        }
      } catch (e) {
        print("⚠️ Erro ao salvar no diretório de documentos: $e");
      }

      print("📌 Tentando salvar em diretório temporário");
      // Último recurso: diretório temporário
      try {
        final diretorioTemp = await getTemporaryDirectory();
        if (diretorioTemp != null) {
          final subDiretorio = Directory("${diretorioTemp.path}/DociBoy_PDFs");
          if (!await subDiretorio.exists()) {
            await subDiretorio.create(recursive: true);
          }
          final filePath = "${subDiretorio.path}/$fileName";

          // Escrever arquivo
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);

          print("✅ PDF gerado e salvo em cache: ${file.path}");

          // Se tivermos um contexto salvo, tentar mostrar o PDF
          if (_ultimoContexto != null) {
            try {
              exibirPdf(_ultimoContexto!, file.path, "Pedido de Venda");
            } catch (e) {
              print("⚠️ Não foi possível exibir o PDF: $e");
            }
          }

          return file.path;
        } else {
          print("❌ diretorioTemp é nulo!");
          throw Exception(
              "Não foi possível obter um diretório para salvar o PDF");
        }
      } catch (e) {
        print("❌ Erro ao salvar PDF: $e");
        return null;
      }
    } catch (e) {
      print("❌ Erro ao gerar PDF: $e");
      return null;
    }
  }

  // Método para definir o contexto que será usado para exibir o PDF
  static void definirContexto(BuildContext context) {
    print("📌 Contexto definido para uso futuro");
    _ultimoContexto = context;
  }

  // Método aprimorado para solicitar permissão de armazenamento
  static Future<bool> _solicitarPermissaoArmazenamento() async {
    try {
      // Verificar versão do Android (dispositivos iOS não precisam)
      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo? androidInfo;

        try {
          androidInfo = await deviceInfo.androidInfo;
        } catch (e) {
          print("⚠️ Erro ao obter informações do dispositivo: $e");
          // Em caso de erro, tentar permissão padrão
          final status = await Permission.storage.request();
          return status.isGranted;
        }

        // Se conseguiu obter a versão
        if (androidInfo != null) {
          final sdkInt = androidInfo.version.sdkInt;

          // Android 11+ (API 30+) usa uma permissão diferente
          if (sdkInt >= 30) {
            // Verificar se já temos permissão
            if (await Permission.manageExternalStorage.isGranted) {
              return true;
            }

            // Solicitar permissão para gerenciar todos os arquivos
            final status = await Permission.manageExternalStorage.request();
            return status.isGranted;
          }
          // Android 10 ou inferior
          else {
            // Verificar se já temos permissão
            if (await Permission.storage.isGranted) {
              return true;
            }

            // Solicitar permissão de armazenamento
            final status = await Permission.storage.request();
            return status.isGranted;
          }
        } else {
          // Fallback se não conseguir obter a versão
          final status = await Permission.storage.request();
          return status.isGranted;
        }
      }
      // iOS ou outras plataformas
      else {
        return true; // iOS não requer permissão específica
      }
    } catch (e) {
      print("❌ Erro ao solicitar permissão: $e");
      return false;
    }
  }

  // Método para exibir o PDF na tela
  static void exibirPdf(BuildContext context, String filePath, String titulo) {
    print("📌 Exibindo PDF: $filePath");
    // Armazenar o contexto para uso futuro
    _ultimoContexto = context;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(
          filePath: filePath,
          titulo: titulo,
        ),
      ),
    );
  }

  // Método para compartilhar o PDF
  static Future<void> compartilharPdf(String filePath) async {
    try {
      print("📌 Compartilhando PDF: $filePath");
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Pedido de Venda DociBoy',
      );
      print("✅ Compartilhamento iniciado para: $filePath");
    } catch (e) {
      print("❌ Erro ao compartilhar PDF: $e");
    }
  }

  // Método para fazer uma cópia do PDF para o diretório de Downloads com contexto
  static Future<String?> baixarCopia(
      BuildContext context, String filePath) async {
    print("📌 Baixando cópia (com contexto): $filePath");
    // Armazenar o contexto para uso futuro
    _ultimoContexto = context;

    try {
      final File arquivoOriginal = File(filePath);
      if (!await arquivoOriginal.exists()) {
        print("❌ Arquivo original não encontrado: $filePath");
        return null;
      }

      // Verificar permissão para armazenamento externo
      bool permissao = await _solicitarPermissaoArmazenamento();
      if (!permissao) {
        // Se não tiver permissão, sugerir usar compartilhamento
        _mostrarDialogoSemPermissao(context, filePath);
        return null;
      }

      // Obter caminho para Downloads
      final diretorioDownload = Directory("/storage/emulated/0/Download");
      if (!await diretorioDownload.exists()) {
        print("❌ Diretório de Downloads não encontrado");
        _mostrarDialogoSemPermissao(context, filePath);
        return null;
      }

      // Nome do arquivo com timestamp para evitar duplicatas
      final DateTime agora = DateTime.now();
      final String timestamp =
          "${agora.day}${agora.month}${agora.year}_${agora.hour}${agora.minute}${agora.second}";
      final String nomeArquivoOriginal = filePath.split('/').last;
      final String nomeSemExtensao = nomeArquivoOriginal.split('.').first;
      final String novoNomeArquivo = "${nomeSemExtensao}_copia_$timestamp.pdf";

      // Criar caminho para o novo arquivo
      final String novoCaminho = "${diretorioDownload.path}/$novoNomeArquivo";

      // Copiar o arquivo
      final File novoArquivo = await arquivoOriginal.copy(novoCaminho);
      print("✅ Cópia salva em: ${novoArquivo.path}");

      return novoArquivo.path;
    } catch (e) {
      print("❌ Erro ao fazer cópia do PDF: $e");
      return null;
    }
  }

  // Método para fazer uma cópia do PDF sem contexto
  static Future<String?> baixarCopiaSemContexto(String filePath) async {
    print("📌 Baixando cópia (sem contexto): $filePath");
    try {
      final File arquivoOriginal = File(filePath);
      if (!await arquivoOriginal.exists()) {
        print("❌ Arquivo original não encontrado: $filePath");
        return null;
      }

      // Verificar permissão para armazenamento externo
      bool permissao = await _solicitarPermissaoArmazenamento();
      if (!permissao) {
        // Se não tiver permissão e tivermos um contexto, mostrar diálogo
        if (_ultimoContexto != null) {
          _mostrarDialogoSemPermissao(_ultimoContexto!, filePath);
        }
        return null;
      }

      // Obter caminho para Downloads
      final diretorioDownload = Directory("/storage/emulated/0/Download");
      if (!await diretorioDownload.exists()) {
        print("❌ Diretório de Downloads não encontrado");
        if (_ultimoContexto != null) {
          _mostrarDialogoSemPermissao(_ultimoContexto!, filePath);
        }
        return null;
      }

      // Nome do arquivo com timestamp para evitar duplicatas
      final DateTime agora = DateTime.now();
      final String timestamp =
          "${agora.day}${agora.month}${agora.year}_${agora.hour}${agora.minute}${agora.second}";
      final String nomeArquivoOriginal = filePath.split('/').last;
      final String nomeSemExtensao = nomeArquivoOriginal.split('.').first;
      final String novoNomeArquivo = "${nomeSemExtensao}_copia_$timestamp.pdf";

      // Criar caminho para o novo arquivo
      final String novoCaminho = "${diretorioDownload.path}/$novoNomeArquivo";

      // Copiar o arquivo
      final File novoArquivo = await arquivoOriginal.copy(novoCaminho);
      print("✅ Cópia salva em: ${novoArquivo.path}");

      return novoArquivo.path;
    } catch (e) {
      print("❌ Erro ao fazer cópia do PDF: $e");
      return null;
    }
  }

  // Mostrar diálogo quando não há permissão
  static void _mostrarDialogoSemPermissao(
      BuildContext context, String filePath) {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Permissão Negada"),
            content: Text(
                "Não foi possível salvar o arquivo no diretório de Downloads. "
                "Você pode usar a opção de compartilhar para salvá-lo em outro aplicativo."),
            actions: [
              TextButton(
                child: Text("Cancelar"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Compartilhar"),
                onPressed: () {
                  Navigator.of(context).pop();
                  compartilharPdf(filePath);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Erro ao mostrar diálogo de permissão: $e");
    }
  }
}

// Tela para exibir o PDF
class PDFViewerScreen extends StatefulWidget {
  final String filePath;
  final String titulo;

  PDFViewerScreen({required this.filePath, required this.titulo});

  @override
  _PDFViewerScreenState createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  int _paginaAtual = 0;
  int _paginasTotal = 0;
  bool _carregando = true;
  PDFViewController? _pdfViewController;

  @override
  Widget build(BuildContext context) {
    print("📌 Construindo PDFViewerScreen para arquivo: ${widget.filePath}");
    // Armazenar o contexto para uso futuro
    PdfGenerator.definirContexto(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          // Botão para compartilhar
          IconButton(
            icon: Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () {
              PdfGenerator.compartilharPdf(widget.filePath);
            },
          ),
          // Botão para baixar cópia
          IconButton(
            icon: Icon(Icons.download),
            tooltip: 'Salvar cópia',
            onPressed: () async {
              final String? caminhoCopia =
                  await PdfGenerator.baixarCopia(context, widget.filePath);
              if (caminhoCopia != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("PDF salvo em Downloads/DociBoy_PDFs"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Verificar se o arquivo existe antes de tentar exibi-lo
          FutureBuilder<bool>(
            future: File(widget.filePath).exists(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              // Verificar se o arquivo existe
              if (snapshot.hasData && snapshot.data == true) {
                print("📌 Arquivo PDF existe. Exibindo...");
                return PDFView(
                  filePath: widget.filePath,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: _paginaAtual,
                  fitPolicy: FitPolicy.BOTH,
                  preventLinkNavigation: false,
                  onRender: (_pages) {
                    setState(() {
                      _paginasTotal = _pages ?? 0;
                      _carregando = false;
                    });
                    print(
                        "📌 PDF renderizado. Total de páginas: $_paginasTotal");
                  },
                  onError: (error) {
                    setState(() {
                      _carregando = false;
                    });
                    print("❌ Erro ao carregar PDF: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Erro ao carregar PDF: $error"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                  onPageError: (page, error) {
                    print("❌ Erro na página $page: $error");
                  },
                  onViewCreated: (PDFViewController pdfViewController) {
                    _pdfViewController = pdfViewController;
                    print("📌 PDFViewController criado");
                  },
                  onPageChanged: (int? page, int? total) {
                    if (page != null) {
                      setState(() {
                        _paginaAtual = page;
                      });
                    }
                  },
                );
              } else {
                // Arquivo não existe
                print("❌ Arquivo PDF não encontrado: ${widget.filePath}");
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        "Arquivo PDF não encontrado",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text("O arquivo pode ter sido movido ou excluído"),
                      SizedBox(height: 24),
                      ElevatedButton(
                        child: Text("Voltar"),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    ],
                  ),
                );
              }
            },
          ),

          // Indicador de carregamento
          if (_carregando)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Carregando PDF..."),
                ],
              ),
            ),

          // Controles de navegação e indicador de página atual
          if (!_carregando && _paginasTotal > 0)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão para página anterior (se não estiver na primeira página)
                      if (_paginaAtual > 0)
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios,
                              color: Colors.white, size: 18),
                          onPressed: () {
                            _pdfViewController?.setPage(_paginaAtual - 1);
                          },
                        ),

                      // Indicador de página
                      Text(
                        "Página ${_paginaAtual + 1} de $_paginasTotal",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),

                      // Botão para próxima página (se não estiver na última página)
                      if (_paginaAtual < _paginasTotal - 1)
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 18),
                          onPressed: () {
                            _pdfViewController?.setPage(_paginaAtual + 1);
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
