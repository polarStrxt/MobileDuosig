import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom drawer widget providing application navigation and system actions.
///
/// This drawer includes options for synchronizing data, clearing tables,
/// viewing app information, and exiting the application.
class AppDrawer extends StatefulWidget {
  final Future<void> Function() clearAllTables;
  final Future<void> Function() syncAllTables;

  const AppDrawer({
    Key? key,
    required this.clearAllTables,
    required this.syncAllTables,
  }) : super(key: key);

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  // Store ScaffoldMessenger reference for safe use in async operations
  late ScaffoldMessengerState _scaffoldMessenger;

  // Constants
  static const Color _primaryColor = Color(0xFF5D5CDE);
  static const Duration _snackBarDuration = Duration(seconds: 3);
  static const Duration _longSnackBarDuration = Duration(seconds: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildSyncOption(),
                  _buildClearTablesOption(),
                  const Divider(height: 1),
                  _buildAboutOption(),
                  _buildExitOption(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: _primaryColor,
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 28,
              child: Icon(
                Icons.store_rounded,
                size: 28,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mobile DuoSig',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sistema de vendas',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncOption() {
    return _buildDrawerTile(
      icon: Icons.sync_rounded,
      iconColor: _primaryColor,
      title: 'Sincronizar Dados',
      subtitle: 'Atualizar informações do servidor',
      onTap: () => _confirmSyncTables(context),
    );
  }

  Widget _buildClearTablesOption() {
    return _buildDrawerTile(
      icon: Icons.cleaning_services_rounded,
      iconColor: Colors.redAccent,
      title: 'Limpar Tabelas',
      subtitle: 'Remover todos os dados do aplicativo',
      onTap: () => _confirmClearTables(context),
    );
  }

  Widget _buildAboutOption() {
    return _buildDrawerTile(
      icon: Icons.info_outline_rounded,
      iconColor: _primaryColor,
      title: 'Sobre',
      onTap: () {
        Navigator.pop(context);
        _showAboutDialog(context);
      },
    );
  }

  Widget _buildExitOption() {
    return _buildDrawerTile(
      icon: Icons.logout_rounded,
      iconColor: _primaryColor,
      title: 'Sair',
      onTap: () {
        Navigator.pop(context);
        _confirmExit(context);
      },
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = _primaryColor,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  /// Confirmation dialog for table synchronization
  void _confirmSyncTables(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: _buildDialogTitle(
            icon: Icons.sync_rounded,
            title: 'Sincronizar Dados',
          ),
          content: const Text(
            'Esta ação irá baixar todos os dados do servidor e atualizar o banco local.\n\n'
            'Isso pode levar alguns minutos dependendo da sua conexão. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCELAR'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleSyncTables(dialogContext),
              child: const Text('SINCRONIZAR'),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }

  /// Handles the table synchronization process
  Future<void> _handleSyncTables(BuildContext dialogContext) async {
    // Close the confirmation dialog
    Navigator.of(dialogContext).pop();

    // Show loading indicator
    _showLoadingDialog('Sincronizando dados...');

    try {
      // Execute the sync function
      await widget.syncAllTables();

      // Close loading dialog if widget is still mounted
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      _showSnackBar(
        message: 'Dados sincronizados com sucesso!',
        isError: false,
      );
    } catch (e) {
      // Close loading dialog if widget is still mounted
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error message
      _showSnackBar(
        message: 'Erro ao sincronizar dados: $e',
        isError: true,
        duration: _longSnackBarDuration,
      );
    }
  }

  /// Confirmation dialog for clearing tables
  void _confirmClearTables(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: _buildDialogTitle(
            icon: Icons.warning_amber_rounded,
            title: 'Atenção',
            iconColor: Colors.orange,
          ),
          content: const Text(
            'Esta ação irá remover TODOS os dados do aplicativo '
            '(clientes, produtos e duplicatas).\n\n'
            'Esta operação não pode ser desfeita. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCELAR'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _handleClearTables(dialogContext),
              child: const Text('LIMPAR DADOS'),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }

  /// Handles the table clearing process
  Future<void> _handleClearTables(BuildContext dialogContext) async {
    // Close the confirmation dialog
    Navigator.of(dialogContext).pop();

    // Show loading indicator
    _showLoadingDialog('Limpando dados...');

    try {
      // Execute the clear tables function
      await widget.clearAllTables();

      // Close loading dialog if widget is still mounted
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      _showSnackBar(
        message: 'Dados removidos com sucesso',
        isError: false,
      );
    } catch (e) {
      // Close loading dialog if widget is still mounted
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error message
      _showSnackBar(
        message: 'Erro ao limpar dados: $e',
        isError: true,
        duration: _longSnackBarDuration,
      );
    }
  }

  /// About dialog showing application information
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: _buildDialogTitle(
            icon: Icons.info_outline_rounded,
            title: 'Sobre o Aplicativo',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DuoSig Vendas',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Versão 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Aplicativo de vendas desenvolvido para facilitar o '
                'gerenciamento de clientes, produtos e pedidos.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '© 2025 DuoTec Sistemas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('FECHAR'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
      },
    );
  }

  /// Loading dialog with a progress indicator
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Exit confirmation dialog
  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: _buildDialogTitle(
            icon: Icons.logout_rounded,
            title: 'Sair do Aplicativo',
          ),
          content: const Text(
            'Deseja realmente sair do aplicativo?\n'
            'Alterações não salvas serão perdidas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCELAR'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => SystemNavigator.pop(),
              child: const Text('SAIR'),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }

  /// Helper method to build dialog titles with consistent styling
  Widget _buildDialogTitle({
    required IconData icon,
    required String title,
    Color iconColor = _primaryColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Helper method to show a snackbar message
  void _showSnackBar({
    required String message,
    required bool isError,
    Duration duration = _snackBarDuration,
  }) {
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(8),
      ),
    );
  }
}
