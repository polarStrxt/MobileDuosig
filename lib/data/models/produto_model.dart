// lib/data/models/produto_model.dart
import 'package:flutter/foundation.dart';

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

  const ProdutoModel({
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

  /// Factory constructor para dados da API com tratamento robusto
  factory ProdutoModel.fromJson(Map<String, dynamic> map) {
    try {
      return ProdutoModel(
        codprd: _parseInt(map['codprd']),
        staati: _parseString(map['staati']) ?? 'A',
        dcrprd: _parseString(map['dcrprd']) ?? '',
        qtdmulvda: _parseInt(map['qtdmulvda']) ?? 1,
        nommrc: _parseString(map['nommrc']) ?? '',
        vlrbasvda: _parseDouble(map['vlrbasvda']) ?? 0.0,
        qtdetq: _parseInt(map['qtdetq']),
        vlrpmcprd: _parseDouble(map['vlrpmcprd']) ?? 0.0,
        dtaini: _parseString(map['dtaini']),
        dtafin: _parseString(map['dtafin']),
        vlrtab1: _parseDouble(map['vlrtab1']) ?? 0.0,
        vlrtab2: _parseDouble(map['vlrtab2']) ?? 0.0,
        peracrdsc1: _parseDouble(map['peracrdsc1']) ?? 0.0,
        peracrdsc2: _parseDouble(map['peracrdsc2']) ?? 0.0,
        codundprd: _parseString(map['codundprd']) ?? 'UN',
        vol: _parseInt(map['vol']) ?? 1,
        qtdvol: _parseInt(map['qtdvol']) ?? 1,
        perdscmxm: _parseDouble(map['perdscmxm']) ?? 0.0,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao criar ProdutoModel: $e');
      }
      throw FormatException('Erro ao processar dados do produto: $e');
    }
  }

  /// Converte para Map - usado tanto para JSON quanto para Database
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

  /// Cria uma cópia com alterações
  ProdutoModel copyWith({
    int? codprd,
    String? staati,
    String? dcrprd,
    int? qtdmulvda,
    String? nommrc,
    double? vlrbasvda,
    int? qtdetq,
    double? vlrpmcprd,
    String? dtaini,
    String? dtafin,
    double? vlrtab1,
    double? vlrtab2,
    double? peracrdsc1,
    double? peracrdsc2,
    String? codundprd,
    int? vol,
    int? qtdvol,
    double? perdscmxm,
  }) {
    return ProdutoModel(
      codprd: codprd ?? this.codprd,
      staati: staati ?? this.staati,
      dcrprd: dcrprd ?? this.dcrprd,
      qtdmulvda: qtdmulvda ?? this.qtdmulvda,
      nommrc: nommrc ?? this.nommrc,
      vlrbasvda: vlrbasvda ?? this.vlrbasvda,
      qtdetq: qtdetq ?? this.qtdetq,
      vlrpmcprd: vlrpmcprd ?? this.vlrpmcprd,
      dtaini: dtaini ?? this.dtaini,
      dtafin: dtafin ?? this.dtafin,
      vlrtab1: vlrtab1 ?? this.vlrtab1,
      vlrtab2: vlrtab2 ?? this.vlrtab2,
      peracrdsc1: peracrdsc1 ?? this.peracrdsc1,
      peracrdsc2: peracrdsc2 ?? this.peracrdsc2,
      codundprd: codundprd ?? this.codundprd,
      vol: vol ?? this.vol,
      qtdvol: qtdvol ?? this.qtdvol,
      perdscmxm: perdscmxm ?? this.perdscmxm,
    );
  }

  // ============= MÉTODOS DE NEGÓCIO =============

  /// Verifica se o produto está ativo
  bool get isAtivo => staati.toUpperCase() == 'A';

  /// Verifica se o produto tem estoque disponível
  bool get temEstoque => (qtdetq ?? 0) > 0;

  /// Verifica se está dentro do período de validade
  bool get isValidoPeriodo {
    final now = DateTime.now();
    
    if (dtaini != null && dtaini!.isNotEmpty) {
      try {
        final dataInicio = DateTime.parse(dtaini!);
        if (now.isBefore(dataInicio)) return false;
      } catch (e) {
        // Se não conseguir parsear a data, ignora a validação
      }
    }
    
    if (dtafin != null && dtafin!.isNotEmpty) {
      try {
        final dataFim = DateTime.parse(dtafin!);
        if (now.isAfter(dataFim)) return false;
      } catch (e) {
        // Se não conseguir parsear a data, ignora a validação
      }
    }
    
    return true;
  }

  /// Verifica se o produto está disponível para venda
  bool get isDisponivelParaVenda => isAtivo && temEstoque && isValidoPeriodo;

  /// Retorna o preço para uma tabela específica
  double getPrecoParaTabela(int clienteTabela) {
    switch (clienteTabela) {
      case 1:
        return vlrtab1;
      case 2:
        return vlrtab2;
      default:
        return vlrtab1; // Padrão tabela 1
    }
  }

  /// Calcula preço com desconto aplicado
  double calcularPrecoComDesconto(int tabela, double descontoPercentual) {
    final precoBase = getPrecoParaTabela(tabela);
    final desconto = descontoPercentual.clamp(0.0, perdscmxm);
    return precoBase * (1 - (desconto / 100));
  }

  /// Valida se o desconto está dentro do limite
  bool isDescontoValido(double desconto) {
    return desconto >= 0 && desconto <= perdscmxm;
  }

  /// Retorna a descrição formatada para exibição
  String get descricaoFormatada {
    return '${dcrprd.trim()} - ${nommrc.trim()}';
  }

  /// Retorna código formatado
  String get codigoFormatado => 'Cód: ${codprd ?? "N/A"}';

  // ============= MÉTODOS AUXILIARES ESTÁTICOS =============

  /// Parse seguro para int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String && value.isNotEmpty) return int.tryParse(value);
    return null;
  }

  /// Parse seguro para double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  /// Parse seguro para String
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    return value.toString().trim();
  }

  // ============= OVERRIDE METHODS =============

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProdutoModel &&
          runtimeType == other.runtimeType &&
          codprd == other.codprd &&
          codprd != null;

  @override
  int get hashCode => codprd.hashCode;

  @override
  String toString() {
    return 'ProdutoModel(codprd: $codprd, dcrprd: $dcrprd, nommrc: $nommrc, vlrtab1: $vlrtab1, vlrtab2: $vlrtab2, isAtivo: $isAtivo)';
  }

  /// Método para debug detalhado
  String toStringDetailed() {
    return '''
ProdutoModel {
  codprd: $codprd,
  staati: $staati,
  dcrprd: $dcrprd,
  qtdmulvda: $qtdmulvda,
  nommrc: $nommrc,
  vlrbasvda: $vlrbasvda,
  qtdetq: $qtdetq,
  vlrpmcprd: $vlrpmcprd,
  dtaini: $dtaini,
  dtafin: $dtafin,
  vlrtab1: $vlrtab1,
  vlrtab2: $vlrtab2,
  peracrdsc1: $peracrdsc1,
  peracrdsc2: $peracrdsc2,
  codundprd: $codundprd,
  vol: $vol,
  qtdvol: $qtdvol,
  perdscmxm: $perdscmxm,
  isAtivo: $isAtivo,
  temEstoque: $temEstoque,
  isValidoPeriodo: $isValidoPeriodo
}''';
  }
}