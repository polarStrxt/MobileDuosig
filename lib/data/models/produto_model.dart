// lib/models/produto_model.dart
import 'package:flutter/foundation.dart'; // Para kDebugMode, se for usar prints condicionais

class ProdutoModel {
  final int? codprd;
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

  ProdutoModel({
    this.codprd,
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

  factory ProdutoModel.fromJson(Map<String, dynamic> map) {
    // Helper para converter num (int ou double) para double de forma segura
    double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value is double) {
        return value;
      } else if (value is int) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    // Helper para converter num (int ou double) para int de forma segura
     int _parseInt(dynamic value, {int defaultValue = 0}) {
      if (value is int) {
        return value;
      } else if (value is double) {
        return value.toInt();
      } else if (value is String) {
        return int.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }


    // Linha 53 que você mencionou provavelmente está entre estas conversões para double:
    return ProdutoModel(
      codprd: map['codprd'] != null ? _parseInt(map['codprd']) : null,
      staati: map['staati'] as String? ?? 'A', // Default 'A' se nulo
      dcrprd: map['dcrprd'] as String? ?? '',
      qtdmulvda: _parseInt(map['qtdmulvda'], defaultValue: 1), // Default 1 se nulo/inválido
      nommrc: map['nommrc'] as String? ?? '',
      // ----- ATENÇÃO A ESTAS CONVERSÕES -----
      vlrbasvda: _parseDouble(map['vlrbasvda']),
      qtdetq: map['qtdetq'] != null ? _parseInt(map['qtdetq']) : null,
      vlrpmcprd: _parseDouble(map['vlrpmcprd']),
      dtaini: map['dtaini'] as String?,
      dtafin: map['dtafin'] as String?,
      vlrtab1: _parseDouble(map['vlrtab1']),
      vlrtab2: _parseDouble(map['vlrtab2']),
      peracrdsc1: _parseDouble(map['peracrdsc1']),
      peracrdsc2: _parseDouble(map['peracrdsc2']),
      // --------------------------------------
      codundprd: map['codundprd'] as String? ?? 'UN',
      vol: _parseInt(map['vol'], defaultValue: 1),
      qtdvol: _parseInt(map['qtdvol'], defaultValue: 1),
      perdscmxm: _parseDouble(map['perdscmxm']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codprd': codprd,
      'staati': staati,
      'dcrprd': dcrprd,
      'qtdmulvda': qtdmulvda,
      'nommrc': nommrc,
      'vlrbasvda': vlrbasvda,
      'qtdetq': qtdetq,
      'vlrpmcprd': vlrpmcprd,
      'dtaini': dtaini,
      'dtafin': dtafin,
      'vlrtab1': vlrtab1,
      'vlrtab2': vlrtab2,
      'peracrdsc1': peracrdsc1,
      'peracrdsc2': peracrdsc2,
      'codundprd': codundprd,
      'vol': vol,
      'qtdvol': qtdvol,
      'perdscmxm': perdscmxm,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoModel &&
          runtimeType == other.runtimeType &&
          codprd == other.codprd &&
          // Considerar apenas codprd para igualdade se ele for único e não nulo
          // Se codprd puder ser nulo, a lógica de igualdade pode precisar ser mais complexa
          // ou baseada em mais campos se necessário.
          codprd != null; 

  @override
  int get hashCode => codprd.hashCode;

  double getPrecoParaTabela(int clienteTabela) {
    // Adiciona verificação para campos de preço nulos, se eles puderem ser
    // No seu modelo, eles são 'double', então não devem ser nulos se o objeto foi criado corretamente.
    // Mas se o JSON da API puder omiti-los, o _parseDouble já trata com defaultValue.
    if (clienteTabela == 1) {
      return vlrtab1;
    } else {
      return vlrtab2;
    }
  }
}