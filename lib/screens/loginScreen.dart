import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/screens/homeScreen.dart';
import 'package:flutter_docig_venda/widgets/textField.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool isLoading = false;

  void _handleLogin() {
    if (usuarioController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, preencha todos os campos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simular um tempo de processamento
    Future.delayed(Duration(seconds: 1), () {
      String usuario = usuarioController.text;
      String senha = senhaController.text;

      // Chamar a função de verificação
      FuncVerificacao(context, usuario, senha);

      setState(() {
        isLoading = false;
      });

      print('Tentativa de login: $usuario');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Obtém o tamanho da tela para responsividade
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Espaço para logo do cliente
                Container(
                  height: 120,
                  margin: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "LOGO DO CLIENTE",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40),

                // Ícone da aplicação e título
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color(0xFF5D5CDE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Título da aplicação
                Center(
                  child: Text(
                    'Sistema de Vendas',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D5CDE),
                    ),
                  ),
                ),

                SizedBox(height: 10),

                // Subtítulo
                Center(
                  child: Text(
                    'Entre com suas credenciais para acessar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 40),

                // Título do formulário
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D5CDE),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Campo de usuário
                Leia(
                  texto: 'Digite seu usuário',
                  icone: Icons.person,
                  dados: usuarioController,
                ),

                SizedBox(height: 16),

                // Campo de senha
                Leia(
                  texto: 'Digite sua senha',
                  icone: Icons.lock,
                  dados: senhaController,
                  isPassword: true,
                ),

                SizedBox(height: 16),

                // Esqueci minha senha
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Implementar funcionalidade de recuperação de senha
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Funcionalidade em desenvolvimento.'),
                          backgroundColor: Colors.grey[700],
                        ),
                      );
                    },
                    child: Text(
                      'Esqueci minha senha',
                      style: TextStyle(
                        color: Color(0xFF5D5CDE),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Botão de login
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5D5CDE),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Color(0xFF5D5CDE).withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            'ENTRAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 40),

                // Rodapé com informações adicionais
                Center(
                  child: Text(
                    'Versão 1.0.0',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usuarioController.dispose();
    senhaController.dispose();
    super.dispose();
  }
}

void FuncVerificacao(BuildContext context, String user, String pass) {
  List<String> loginList = [
    'tone:123',
    'erick:erick124',
    'victor:senha',
    'adm:adm'
  ];
  String credenciais = '$user:$pass';

  if (loginList.contains(credenciais)) {
    print('✅ Bem-vindo.');

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  } else {
    print('❌ Usuário ou senha inválida.');

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Senha ou usuário incorretos!")));
  }
}
