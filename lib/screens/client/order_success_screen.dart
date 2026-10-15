import 'package:flutter/material.dart';
import 'order_tracking_screen.dart';

/// Pantalla de Confirmación de Pedido Exitoso.
///
/// Informa al cliente que su orden fue guardada en Firestore y le permite:
/// 1. Ir directamente al seguimiento en tiempo real de su pizza (`OrderTrackingScreen`).
/// 2. O volver al menú principal.
class OrderSuccessScreen extends StatelessWidget {
  final String orderId;
  final String? metodoPago;
  final String? transaccionId;
  final double? total;
  final String? tarjetaUltimos4;
  final String? tarjetaMarca;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    this.metodoPago,
    this.transaccionId,
    this.total,
    this.tarjetaUltimos4,
    this.tarjetaMarca,
  });

  @override
  Widget build(BuildContext context) {
    final isOnlinePayment = metodoPago == 'en_linea';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono animado de éxito
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 48)),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  '¡Pedido Realizado con Éxito!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  isOnlinePayment
                      ? 'Tu pago ha sido procesado y aprobado. La orden ya está en la cocina.'
                      : 'Hemos enviado tu orden a la cocina. Tu pedido ya está registrado en estado Pendiente.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 20),

                // ── Comprobante de Pago / Método ──────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOnlinePayment ? Colors.teal.withValues(alpha: 0.5) : Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isOnlinePayment ? Icons.verified : Icons.payments_outlined,
                                color: isOnlinePayment ? Colors.tealAccent : Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOnlinePayment ? 'PAGO EN LÍNEA APROBADO' : 'PAGO CONTRA ENTREGA',
                                style: TextStyle(
                                  color: isOnlinePayment ? Colors.tealAccent : Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          if (total != null)
                            Text(
                              '\$${total!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFFFF7043),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      if (isOnlinePayment) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Medio de Pago:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(
                              '💳 ${tarjetaMarca ?? "Tarjeta"} •••• ${tarjetaUltimos4 ?? "4242"}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (transaccionId != null && transaccionId!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('N° Transacción:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                              Text(
                                transaccionId!,
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '🛡️ Tu pedido está 100% pagado. No entregues efectivo al repartidor.',
                            style: TextStyle(color: Colors.tealAccent, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Modalidad:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            const Text('💵 Efectivo en Puerta', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '💵 Ten listo el dinero en efectivo al recibir tu pizza.',
                            style: TextStyle(color: Colors.amber, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tarjeta con ID del pedido
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag, color: Color(0xFFFF7043), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'ID de Orden: ${orderId.substring(0, orderId.length > 8 ? 8 : orderId.length)}...',
                        style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Botón: Ver Estado del Pedido
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderTrackingScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delivery_dining, size: 22),
                    label: const Text(
                      'VER ESTADO DE MI PEDIDO',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE64A19),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón: Volver al menú
                TextButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text(
                    'Volver al Menú Principal',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
