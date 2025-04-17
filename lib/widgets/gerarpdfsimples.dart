import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/models/produto_model.dart';
import 'package:flutter_docig_venda/models/cliente_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfGeneratorSimples {
  // Cores da marca Dousig Vendas
  static final PdfColor corPrimaria = PdfColor.fromHex("#5D5CDE"); // Roxo/azul
  static final PdfColor corSecundaria =
      PdfColor.fromHex("#2D2D5F"); // Roxo/azul escuro
  static final PdfColor corDestaque =
      PdfColor.fromHex("#FF5757"); // Vermelho para destaques
  static final PdfColor corTexto =
      PdfColor.fromHex("#333333"); // Cinza escuro para texto
  static final PdfColor corFundo =
      PdfColor.fromHex("#F8F8F8"); // Cinza claro para fundos

  // Versões mais claras das cores (já que .lighter não existe)
  static final PdfColor corPrimariaClara =
      PdfColor.fromHex("#8988E8"); // Versão clara do roxo/azul
  static final PdfColor corTextoClara =
      PdfColor.fromHex("#777777"); // Cinza médio para texto secundário

  // Método simples que apenas gera e salva o PDF sem tentar exibi-lo
  static Future<String?> gerarPdfSimples(
    Map<Produto, int> itens,
    Map<Produto, double> descontos, [
    Cliente? cliente,
    String observacao = '',
    String nomeVendedor = '',
    String nomeClienteResponsavel = '',
    String emailCliente = '',
    String formaPagamento = '',
    String numPedido = '',
  ]) async {
    print("📌 Iniciando geração de PDF para MobileDousig...");
    try {
      // 1. Criar o documento PDF
      final pdf = pw.Document();
      print("📌 Documento PDF criado");

      // 2. Preparar dados
      final DateTime agora = DateTime.now();
      final String dataFormatada =
          "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}";
      final String dataArquivo =
          "${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}_${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}${agora.second.toString().padLeft(2, '0')}";

      // Usar numPedido fornecido ou gerar um
      final String numeroPedido = numPedido.isNotEmpty
          ? numPedido
          : "${dataArquivo.substring(0, 8)}-${(cliente?.codcli ?? '000').toString().padLeft(3, '0')}";

      // 3. Calcular valores
      final tabelaPreco = cliente?.codtab ?? 1;
      double totalSemDesconto = 0.0;
      double totalComDesconto = 0.0;

      itens.forEach((produto, quantidade) {
        final double precoBase =
            tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
        final double desconto = descontos[produto] ?? 0.0;
        final double precoComDesconto = precoBase * (1 - desconto / 100);

        totalSemDesconto += precoBase * quantidade;
        totalComDesconto += precoComDesconto * quantidade;
      });
      print("📌 Cálculos concluídos");

      // 4. Formatar moeda
      String formatarMoeda(double valor) {
        return "R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}";
      }

      // 5. Criar conteúdo do PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(30),
          header: (pw.Context context) {
            return pw.Container(
              padding: pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: corPrimaria, width: 1))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Logo e nome da empresa
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "AMBAR DISTRIBUIÇÃO",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: corPrimaria,
                        ),
                      ),
                      pw.Text(
                        "Ambar Comercio E Distribuição LTDA",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: corTexto,
                        ),
                      ),
                    ],
                  ),

                  // Informações do documento
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "PEDIDO DE VENDA",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: corSecundaria,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Nº ${numeroPedido}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: corSecundaria,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              padding: pw.EdgeInsets.only(top: 10),
              decoration: pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: corPrimaria, width: 0.5))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Dousig Vendas • ${dataFormatada}",
                    style: pw.TextStyle(
                      color: corTexto,
                      fontSize: 8,
                    ),
                  ),
                  pw.Text(
                    "Página ${context.pageNumber} de ${context.pagesCount}",
                    style: pw.TextStyle(
                      color: corTexto,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // Informações do pedido
              pw.Container(
                padding: pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: corFundo,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Data de Emissão:",
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: corTexto,
                          ),
                        ),
                        pw.Text(
                          dataFormatada,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: corSecundaria,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Tabela de Preço:",
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: corTexto,
                          ),
                        ),
                        pw.Text(
                          "$tabelaPreco",
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: corSecundaria,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Cliente info - Seção ultra-simplificada apenas com dados essenciais
              if (cliente != null)
                pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: corFundo,
                    border: pw.Border.all(color: corPrimariaClara),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding:
                            pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        decoration: pw.BoxDecoration(
                          color: corPrimaria,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          "DADOS DO CLIENTE",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Seção única: Identificação e endereço
                      pw.Container(
                        padding: pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(
                              color: corPrimariaClara, width: 0.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Linha 1: Código e Nome
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Código:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.codcli}",
                                        style: pw.TextStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 5,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Nome/Razão Social:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.nomcli}",
                                        style: pw.TextStyle(
                                          fontSize: 11,
                                          fontWeight: pw.FontWeight.bold,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            // Linha 2: Nome Fantasia e CPF/CNPJ
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Nome Fantasia:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.nomfnt ?? 'Não informado'}",
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "CPF/CNPJ:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.cgccpfcli}",
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            // Linha 3: Endereço e Condição de Pagamento
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 4,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Endereço:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.endcli ?? ''}, ${cliente.baicli ?? ''} - ${cliente.muncli ?? ''}/${cliente.ufdcli ?? ''}",
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 1,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Cond. Pagamento:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        "${cliente.codcndpgt}",
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            // Linha 4: Forma de Pagamento
                            pw.Row(
                              children: [
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "Forma de Pagamento:",
                                        style: pw.TextStyle(
                                          fontSize: 8,
                                          color: corTextoClara,
                                        ),
                                      ),
                                      pw.Text(
                                        formaPagamento.isNotEmpty
                                            ? formaPagamento
                                            : "À vista",
                                        style: pw.TextStyle(
                                          fontSize: 10,
                                          fontWeight: pw.FontWeight.bold,
                                          color: corTexto,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              pw.SizedBox(height: 20),

              // Tabela de produtos - Cabeçalho estilizado
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: pw.BoxDecoration(
                  color: corSecundaria,
                  borderRadius: pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(8),
                    topRight: pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      padding: pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        "${itens.length}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: corSecundaria,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      "ITENS DO PEDIDO",
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Tabela de produtos - Conteúdo
              pw.Table(
                border: pw.TableBorder.all(
                  color: corPrimariaClara,
                  width: 0.5,
                ),
                columnWidths: {
                  0: pw.FlexColumnWidth(1), // Código
                  1: pw.FlexColumnWidth(4), // Produto
                  2: pw.FlexColumnWidth(0.8), // Qtd
                  3: pw.FlexColumnWidth(1.2), // Preço Un.
                  4: pw.FlexColumnWidth(0.8), // Desc.
                  5: pw.FlexColumnWidth(1.2), // Total
                },
                children: [
                  // Cabeçalho da tabela
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: corPrimariaClara,
                    ),
                    children: [
                      _cabecalhoTabela('Código'),
                      _cabecalhoTabela('Produto'),
                      _cabecalhoTabela('Qtd'),
                      _cabecalhoTabela('Preço Un.'),
                      _cabecalhoTabela('Desc.'),
                      _cabecalhoTabela('Total'),
                    ],
                  ),
                  // Linhas de dados
                  ...itens.entries.map((entry) {
                    final produto = entry.key;
                    final quantidade = entry.value;
                    final precoBase =
                        tabelaPreco == 1 ? produto.vlrtab1 : produto.vlrtab2;
                    final desconto = descontos[produto] ?? 0.0;
                    final precoComDesconto = precoBase * (1 - desconto / 100);
                    final total = precoComDesconto * quantidade;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                      ),
                      children: [
                        _celulaTabela(produto.codprd.toString(),
                            alignment: pw.Alignment.centerLeft),
                        _celulaTabela(produto.dcrprd,
                            alignment: pw.Alignment.centerLeft),
                        _celulaTabela(quantidade.toString()),
                        _celulaTabela(formatarMoeda(precoBase)),
                        _celulaTabela(desconto > 0
                            ? "${desconto.toStringAsFixed(1)}%"
                            : "-"),
                        _celulaTabela(formatarMoeda(total),
                            bold: true, color: corSecundaria),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Resumo financeiro
              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: corFundo,
                  border: pw.Border.all(color: corPrimariaClara),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "Subtotal:",
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: corTexto,
                          ),
                        ),
                        pw.Text(
                          formatarMoeda(totalSemDesconto),
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: corTexto,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    if (totalSemDesconto > totalComDesconto)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Descontos:",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: corDestaque,
                            ),
                          ),
                          pw.Text(
                            "- ${formatarMoeda(totalSemDesconto - totalComDesconto)}",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: corDestaque,
                            ),
                          ),
                        ],
                      ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: corPrimariaClara),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "TOTAL A PAGAR:",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: corSecundaria,
                          ),
                        ),
                        pw.Container(
                          padding: pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(
                            color: corSecundaria,
                            borderRadius: pw.BorderRadius.circular(20),
                          ),
                          child: pw.Text(
                            formatarMoeda(totalComDesconto),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Observações
              pw.Container(
                padding: pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: corFundo,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "Observações:",
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: corTexto,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      observacao.isNotEmpty
                          ? observacao
                          : "Este documento representa um pedido de venda gerado pelo sistema Dousig Vendas. Os valores e condições apresentados estão sujeitos à confirmação. Este documento não possui valor fiscal.",
                      style: pw.TextStyle(
                        fontSize: 7,
                        color: corTextoClara,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );
      print("📌 Páginas do PDF criadas");

      // 6. Salvar o PDF - estratégia super simples
      final pdfBytes = await pdf.save();
      print("📌 PDF gerado em memória");

      // 7. Salvar no diretório de documentos do app (mais confiável)
      try {
        final docDir = await getApplicationDocumentsDirectory();
        print("📌 Diretório de documentos obtido: ${docDir.path}");

        final fileName = "DousigVendas_Pedido_$dataArquivo.pdf";
        final pdfDir = Directory("${docDir.path}/DousigVendasPDFs");

        if (!await pdfDir.exists()) {
          await pdfDir.create();
          print("📌 Diretório DousigVendasPDFs criado");
        }

        final file = File("${pdfDir.path}/$fileName");
        await file.writeAsBytes(pdfBytes);
        print("✅ PDF salvo com sucesso em: ${file.path}");

        return file.path;
      } catch (e) {
        print("❌ Erro ao salvar no diretório de documentos: $e");

        // 8. Fallback: Salvar no cache (sempre funciona)
        try {
          final cacheDir = await getTemporaryDirectory();
          print("📌 Diretório temporário obtido: ${cacheDir.path}");

          final fileName = "DousigVendas_Pedido_$dataArquivo.pdf";
          final file = File("${cacheDir.path}/$fileName");
          await file.writeAsBytes(pdfBytes);
          print("✅ PDF salvo em cache: ${file.path}");

          return file.path;
        } catch (innerError) {
          print("❌ Erro fatal ao salvar PDF: $innerError");
          return null;
        }
      }
    } catch (e) {
      print("❌ ERRO DETALHADO: $e");
      print("❌ TIPO DE ERRO: ${e.runtimeType}");
      if (e is Error) {
        print("❌ STACK TRACE: ${e.stackTrace}");
      }
      return null;
    }
  }

  // Método para criar cabeçalho da tabela com estilo consistente
  static pw.Widget _cabecalhoTabela(String texto) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: corSecundaria,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  // Método para criar célula da tabela com estilo consistente
  static pw.Widget _celulaTabela(
    String texto, {
    pw.Alignment alignment = pw.Alignment.center,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? corTexto,
        ),
        textAlign: alignment == pw.Alignment.center
            ? pw.TextAlign.center
            : alignment == pw.Alignment.centerLeft
                ? pw.TextAlign.left
                : pw.TextAlign.right,
      ),
    );
  }

  // Método simples para compartilhar um PDF
  static Future<bool> compartilharArquivo(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: "Pedido Dousig Vendas");
      return true;
    } catch (e) {
      print("❌ Erro ao compartilhar: $e");
      return false;
    }
  }
}
