// lib/models/user_credentials.dart
class UserCredentials {
  static const Map<String, Map<String, dynamic>> usuarios = {
    'vendedor1': {
      'senha': '123',
      'codigo': '001',
      'nome': 'João Silva',
      'tipo': 'vendedor',
      'ativo': true,
    },
    'vendedor2': {
      'senha': '123',
      'codigo': '002',
      'nome': 'Maria Santos',
      'tipo': 'vendedor',
      'ativo': true,
    },
    'vendedor3': {
      'senha': '123',
      'codigo': '003',
      'nome': 'Pedro Costa',
      'tipo': 'vendedor',
      'ativo': true,
    },
    'vendedor4': {
      'senha': '123',
      'codigo': '004',
      'nome': 'Ana Oliveira',
      'tipo': 'vendedor',
      'ativo': true,
    },
    'adm': {
      'senha': 'adm',
      'codigo': '999',
      'nome': 'Administrador',
      'tipo': 'admin',
      'ativo': true,
    },
    
    // EXEMPLOS PARA FUTURAS ADIÇÕES:
    // 'vendedor5': {
    //   'senha': '123',
    //   'codigo': '005',
    //   'nome': 'Carlos Ferreira',
    //   'tipo': 'vendedor',
    //   'ativo': true,
    // },
    // 'gerente1': {
    //   'senha': 'gerente123',
    //   'codigo': '100',
    //   'nome': 'Gerente Regional',
    //   'tipo': 'gerente',
    //   'ativo': true,
    // },
    // 'supervisor1': {
    //   'senha': 'super123',
    //   'codigo': '200',
    //   'nome': 'Supervisor Vendas',
    //   'tipo': 'supervisor',
    //   'ativo': true,
    // },
  };

  // Métodos utilitários
  static Map<String, dynamic>? getUsuario(String usuario) {
    final user = usuarios[usuario.toLowerCase()];
    if (user != null && user['ativo'] == true) {
      return user;
    }
    return null;
  }

  static bool validarCredenciais(String usuario, String senha) {
    final user = getUsuario(usuario);
    return user != null && user['senha'] == senha;
  }

  static String? getCodigoVendedor(String usuario) {
    final user = getUsuario(usuario);
    return user?['codigo'];
  }

  static String? getNomeVendedor(String usuario) {
    final user = getUsuario(usuario);
    return user?['nome'];
  }

  static String? getTipoUsuario(String usuario) {
    final user = getUsuario(usuario);
    return user?['tipo'];
  }

  static List<String> getUsuariosAtivos() {
    return usuarios.entries
        .where((entry) => entry.value['ativo'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  static List<String> getVendedoresAtivos() {
    return usuarios.entries
        .where((entry) => 
            entry.value['ativo'] == true && 
            entry.value['tipo'] == 'vendedor')
        .map((entry) => entry.key)
        .toList();
  }

  // Método para verificar se é admin
  static bool isAdmin(String usuario) {
    final user = getUsuario(usuario);
    return user?['tipo'] == 'admin';
  }

  // Método para obter próximo código de vendedor disponível
  static String getProximoCodigoVendedor() {
    final codigosExistentes = usuarios.values
        .where((user) => user['tipo'] == 'vendedor')
        .map((user) => int.tryParse(user['codigo']) ?? 0)
        .toList();
    
    codigosExistentes.sort();
    
    for (int i = 1; i <= 999; i++) {
      if (!codigosExistentes.contains(i)) {
        return i.toString().padLeft(3, '0');
      }
    }
    
    return '999'; // fallback
  }
}