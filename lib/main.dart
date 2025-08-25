import 'package:flutter/material.dart';
// --- ADICIONE ESTAS IMPORTAÇÕES ---
import 'package:provider/provider.dart';
import 'package:flutter_docig_venda/presentation/widgets/carrinho.dart';
// ---------------------------------
// Corrija o nome do arquivo para o padrão (login_screen.dart)
import 'package:flutter_docig_venda/presentation/screens/LoginScreen.dart';

void main() {
  runApp(
    // --- ADICIONE O PROVIDER AQUI --- 
    ChangeNotifierProvider(
      create: (context) => Carrinho(), // Cria a instância única do seu Carrinho
      child: const MyApp(), // Seu widget MyApp agora é filho do Provider
    ),
    // ---------------------------------
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobileDuosig',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Se LoginScreen for o nome da classe, está ok, mas o nome do arquivo deveria ser login_screen.dart
      home: LoginScreen(), 
    );
  }
}