import 'package:flutter/material.dart';
import 'package:flutter_docig_venda/presentation/screens/homeScreen.dart';
import 'package:flutter_docig_venda/presentation/widgets/textField.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _isLoading = false;

  // Credenciais válidas
  static const List<String> _loginCredentials = [
    'vendedor1:123',
    'vendedor2:123',
    'vendedor3:123',
    'vendedor4:123',
    'adm:adm'
  ];

  void _handleLogin() {
    // Validar campos
    if (_usuarioController.text.isEmpty || _senhaController.text.isEmpty) {
      _showErrorSnackBar('Por favor, preencha todos os campos.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simular tempo de processamento
    Future.delayed(const Duration(seconds: 1), () {
      final String usuario = _usuarioController.text;
      final String senha = _senhaController.text;

      _verificarCredenciais(usuario, senha);

      setState(() {
        _isLoading = false;
      });
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _verificarCredenciais(String usuario, String senha) {
    final String credenciais = '$usuario:$senha';

    if (_loginCredentials.contains(credenciais)) {
      // Login bem-sucedido
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      // Login falhou
      _showErrorSnackBar('Usuário ou senha incorretos!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo da empresa
                Hero(
                  tag: 'logo',
                  child: Image.asset(
                    'assets/MobileDousigSemfundo.png',
                    height: 160,
                    width: 160,
                  ),
                ),

                const SizedBox(height: 16),

                // Título da aplicação
                const Text(
                  'Sistema de Vendas',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D5CDE),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Subtítulo
                Text(
                  'Entre com suas credenciais para acessar',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Login form
                Card(
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título do formulário
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5D5CDE),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Campo de usuário
                        Leia(
                          texto: 'Digite seu usuário',
                          icone: Icons.person,
                          dados: _usuarioController,
                        ),

                        const SizedBox(height: 16),

                        // Campo de senha
                        Leia(
                          texto: 'Digite sua senha',
                          icone: Icons.lock,
                          dados: _senhaController,
                          isPassword: true,
                        ),

                        const SizedBox(height: 16),

                        // Esqueci minha senha
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Funcionalidade em desenvolvimento.'),
                                  backgroundColor: Colors.grey[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5D5CDE),
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Esqueci minha senha',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botão de login
                        SizedBox(
                          height: 55,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5D5CDE),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF5D5CDE).withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    'ENTRAR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Rodapé com informações adicionais
                Text(
                  'Versão 1.0.0',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
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
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}
