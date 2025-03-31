import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppDrawer extends StatelessWidget {
  final Function clearAllTables;
  final Function syncAllTables;

  const AppDrawer({
    Key? key,
    required this.clearAllTables,
    required this.syncAllTables,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Cabeçalho do Drawer
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF5D5CDE),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 30,
                  child: Icon(
                    Icons.store,
                    size: 30,
                    color: Color(0xFF5D5CDE),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Dousig Vendas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sistema de vendas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // NOVO Item de Menu - Sincronizar Todas Tabelas
          ListTile(
            leading: Icon(Icons.sync, color: Color(0xFF5D5CDE)),
            title: Text(
              'Sincronizar Todas Tabelas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Baixar dados de todas as APIs'),
            onTap: () {
              _confirmarSincronizacaoTabelas(context);
            },
          ),

          // Item de Menu - Limpar Tabelas
          ListTile(
            leading: Icon(Icons.cleaning_services, color: Colors.red),
            title: Text(
              'Limpar Tabelas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('Exclui todos os dados do aplicativo'),
            onTap: () {
              _confirmarLimpezaTabelas(context);
            },
          ),

          Divider(),

          // Item de Menu - Sobre
          ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFF5D5CDE)),
            title: Text('Sobre'),
            onTap: () {
              // Exibir informações sobre o app
              Navigator.pop(context);
              _mostrarSobreDialog(context);
            },
          ),

          // Item de Menu - Sair
          ListTile(
            leading: Icon(Icons.exit_to_app, color: Color(0xFF5D5CDE)),
            title: Text('Sair'),
            onTap: () {
              // Fecha o drawer
              Navigator.pop(context);
              // Mostra diálogo de confirmação
              _confirmarSair(context);
            },
          ),
        ],
      ),
    );
  }

  // NOVA função: Diálogo de confirmação antes de sincronizar as tabelas
  void _confirmarSincronizacaoTabelas(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sync, color: Color(0xFF5D5CDE)),
              SizedBox(width: 10),
              Text('Sincronizar Tabelas'),
            ],
          ),
          content: Text(
            'Esta ação irá baixar todos os dados das APIs e atualizar o banco local.\n\n'
            'Isso pode demorar alguns minutos dependendo da sua conexão. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
              },
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Fecha o diálogo

                // Mostra um indicador de progresso
                _mostrarCarregando(context, 'Sincronizando tabelas...');

                try {
                  // Executa a função de sincronizar tabelas
                  await syncAllTables();

                  // Fecha o diálogo de carregamento
                  Navigator.of(context).pop();

                  // Mostra mensagem de sucesso
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Todas as tabelas foram sincronizadas com sucesso!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  // Fecha o diálogo de carregamento em caso de erro
                  Navigator.of(context).pop();

                  // Mostra mensagem de erro
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao sincronizar tabelas: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('SINCRONIZAR'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de confirmação antes de limpar as tabelas
  void _confirmarLimpezaTabelas(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Text('Atenção!'),
            ],
          ),
          content: Text(
            'Esta ação irá excluir TODOS os dados do aplicativo '
            '(clientes, produtos e duplicatas).\n\n'
            'Esta operação não pode ser desfeita. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
              },
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop(); // Fecha o diálogo

                // Mostra um indicador de progresso
                _mostrarCarregando(context, 'Limpando tabelas...');

                try {
                  // Executa a função de limpar tabelas
                  await clearAllTables();

                  // Fecha o diálogo de carregamento
                  Navigator.of(context).pop();

                  // Mostra mensagem de sucesso
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Todas as tabelas foram limpas com sucesso!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  // Fecha o diálogo de carregamento em caso de erro
                  Navigator.of(context).pop();

                  // Mostra mensagem de erro
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao limpar tabelas: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: Text('LIMPAR TABELAS'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo com informações sobre o aplicativo
  void _mostrarSobreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sobre o Aplicativo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dousig Vendas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text('Versão 1.0.0'),
              SizedBox(height: 16),
              Text(
                'Aplicativo de vendas desenvolvido para facilitar o '
                'gerenciamento de clientes, produtos e pedidos.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('FECHAR'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de carregamento
  void _mostrarCarregando(BuildContext context, String mensagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5D5CDE)),
              ),
              SizedBox(width: 20),
              Text(mensagem),
            ],
          ),
        );
      },
    );
  }

  // Diálogo de confirmação para sair
  void _confirmarSair(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: Color(0xFF5D5CDE)),
              SizedBox(width: 10),
              Text('Sair do Aplicativo'),
            ],
          ),
          content: Text(
            'Deseja realmente sair do aplicativo?\nQuaisquer alterações não salvas serão perdidas.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o diálogo
              },
              child: Text('CANCELAR'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5D5CDE),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                // Fecha o aplicativo
                SystemNavigator.pop();
              },
              child: Text('SAIR'),
            ),
          ],
        );
      },
    );
  }
}
