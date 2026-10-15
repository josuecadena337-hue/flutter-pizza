import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../admin/admin_dashboard_screen.dart';
import '../client/catalogo_screen.dart';
import '../repartidor/repartidor_screen.dart';
import 'welcome_screen.dart';

/// Centinela de Autenticación y Enrutador por Roles (`AuthWrapper`).
///
/// ¿Qué hace esta pantalla?
/// - Escucha continuamente al `AuthController` mediante `Provider`.
/// - Si no hay ningún usuario logueado en Firebase, muestra automáticamente la `WelcomeScreen`.
/// - Si el usuario ya inició sesión (o su sesión estaba guardada), lee el campo `role` de Firestore
///   y lo envía de inmediato a la pantalla correcta sin que tenga que presionar nada:
///     - 'admin'      ➔ Panel de Administración
///     - 'repartidor' ➔ Panel de Entregas y Pedidos Asignados
///     - 'cliente'    ➔ Catálogo de Pizzas para pedir a domicilio
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    // 1. Si la app está verificando la sesión inicial con Firebase, mostramos pantalla de carga
    if (authController.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🍕', style: TextStyle(fontSize: 64)),
              SizedBox(height: 20),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE64A19)),
              ),
              SizedBox(height: 16),
              Text(
                'Iniciando Appizza...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Si no hay sesión activa, mostramos la pantalla de bienvenida (Welcome)
    if (!authController.isAuthenticated) {
      return const WelcomeScreen();
    }

    // 3. Si hay sesión activa, redirigimos según el rol almacenado en Firestore
    final role = authController.currentUser?.role ?? 'cliente';

    switch (role) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'repartidor':
        return const RepartidorScreen();
      case 'cliente':
      default:
        return const CatalogScreen();
    }
  }
}
