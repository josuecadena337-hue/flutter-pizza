import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import 'order_success_screen.dart';

/// Formateador para número de tarjeta: agrupa en bloques de 4 dígitos (XXXX XXXX XXXX XXXX)
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Formateador para fecha de expiración: inserta / en MM/AA
class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final string = buffer.toString();
    return TextEditingValue(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

/// Pantalla de Checkout para el Rol CLIENTE.
///
/// Permite al cliente:
/// 1. Ingresar la dirección exacta de entrega a domicilio.
/// 2. Seleccionar el método de pago ('efectivo' o 'en_linea').
/// 3. Si elige pago en línea, ingresar datos de tarjeta o Nequi con simulación de pasarela segura.
/// 4. Botón rápido de prueba para rellenar datos válidos al instante.
/// 5. Guardar el pedido en Firestore ('orders') con metadata de pago y timestamp del servidor.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();

  // Método de pago: 'efectivo' | 'en_linea'
  String _paymentMethod = 'efectivo';

  // Submétodo para pago en línea: 'tarjeta' | 'nequi'
  String _onlineType = 'tarjeta';

  // Controladores para formulario de tarjeta
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  int _selectedCuotas = 1;

  // Controlador para Nequi / PSE
  final _nequiPhoneController = TextEditingController();

  bool _isPlacingOrder = false;
  bool _obscureCvv = true;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(() => setState(() {}));
    _cardHolderController.addListener(() => setState(() {}));
    _expiryController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthController>(context, listen: false);
      if (auth.currentUser != null) {
        if (_cardHolderController.text.isEmpty && auth.currentUser!.name.isNotEmpty) {
          _cardHolderController.text = auth.currentUser!.name.toUpperCase();
        }
        if (_nequiPhoneController.text.isEmpty && auth.currentUser!.phone != null) {
          _nequiPhoneController.text = auth.currentUser!.phone!;
        }
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nequiPhoneController.dispose();
    super.dispose();
  }

  /// Detecta automáticamente la franquicia de la tarjeta
  String _getCardBrand(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('4')) return 'Visa';
    if (clean.startsWith('5')) return 'Mastercard';
    if (clean.startsWith('3')) return 'American Express';
    if (clean.startsWith('6')) return 'Discover';
    return 'Tarjeta';
  }

  /// Llena automáticamente la tarjeta de prueba autorizada
  void _fillTestCard() {
    final auth = Provider.of<AuthController>(context, listen: false);
    final userName = auth.currentUser?.name.isNotEmpty == true
        ? auth.currentUser!.name.toUpperCase()
        : 'AARON JOSUE';

    setState(() {
      _cardNumberController.text = '4532 8920 1024 4242';
      _cardHolderController.text = userName;
      _expiryController.text = '12/28';
      _cvvController.text = '888';
      _selectedCuotas = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Tarjeta de prueba Visa autorizada cargada ✅'),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Llena automáticamente teléfono para Nequi
  void _fillTestNequi() {
    final auth = Provider.of<AuthController>(context, listen: false);
    final phone = auth.currentUser?.phone;
    setState(() {
      _nequiPhoneController.text = (phone != null && phone.isNotEmpty) ? phone : '3104567890';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.phone_android, color: Colors.tealAccent, size: 20),
            SizedBox(width: 8),
            Text('Número de Nequi cargado con éxito ✅'),
          ],
        ),
        backgroundColor: const Color(0xFF16213E),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Valida los campos cuando se elige pago en línea
  bool _validateOnlinePayment() {
    if (_onlineType == 'tarjeta') {
      final cleanNum = _cardNumberController.text.replaceAll(' ', '');
      if (cleanNum.length != 16) {
        _showError('Ingresa un número de tarjeta válido de 16 dígitos');
        return false;
      }
      if (_cardHolderController.text.trim().isEmpty) {
        _showError('Ingresa el nombre del titular de la tarjeta');
        return false;
      }
      final exp = _expiryController.text.trim();
      if (exp.length != 5 || !exp.contains('/')) {
        _showError('Ingresa una fecha de vencimiento válida (MM/AA)');
        return false;
      }
      final parts = exp.split('/');
      final month = int.tryParse(parts[0]);
      if (month == null || month < 1 || month > 12) {
        _showError('El mes de vencimiento debe estar entre 01 y 12');
        return false;
      }
      final cvv = _cvvController.text.trim();
      if (cvv.length < 3 || cvv.length > 4) {
        _showError('El código CVV debe tener 3 o 4 dígitos');
        return false;
      }
    } else {
      final phone = _nequiPhoneController.text.trim().replaceAll(' ', '');
      if (phone.length < 10) {
        _showError('Ingresa un número de celular Nequi válido de 10 dígitos');
        return false;
      }
    }
    return true;
  }

  /// Simula la interacción en vivo con la pasarela de pagos segura (SSL 256 bits)
  Future<bool> _showPaymentGatewayDialog({
    required double total,
    required String txId,
    required String authCode,
  }) async {
    final brand = _getCardBrand(_cardNumberController.text);
    final last4 = _onlineType == 'tarjeta'
        ? (_cardNumberController.text.replaceAll(' ', '').length >= 4
            ? _cardNumberController.text.replaceAll(' ', '').substring(_cardNumberController.text.replaceAll(' ', '').length - 4)
            : '4242')
        : (_nequiPhoneController.text.length >= 4
            ? _nequiPhoneController.text.substring(_nequiPhoneController.text.length - 4)
            : '9876');

    int step = 0; // 0: Conectando, 1: Autorizando, 2: Aprobado

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Manejador secuencial de los pasos de la pasarela
            if (step == 0) {
              Future.delayed(const Duration(milliseconds: 1100), () {
                if (dialogCtx.mounted) {
                  setDialogState(() => step = 1);
                }
              });
            } else if (step == 1) {
              Future.delayed(const Duration(milliseconds: 1300), () {
                if (dialogCtx.mounted) {
                  setDialogState(() => step = 2);
                }
              });
            } else if (step == 2) {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop(true);
                }
              });
            }

            return Dialog(
              backgroundColor: const Color(0xFF16213E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Encabezado de la pasarela
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFFFF7043), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Pasarela Appizza Pay',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cifrado seguro SSL 256-bit • Redeban / Credibanco',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const Divider(color: Colors.white12, height: 26),

                    // Estado dinámico
                    if (step == 0) ...[
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: Color(0xFFFF7043),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Conectando con pasarela segura...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Validando comunicación cifrada con la entidad bancaria',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ] else if (step == 1) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.credit_score, color: Colors.amber, size: 28),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _onlineType == 'tarjeta'
                            ? 'Autorizando cobro de \$${total.toStringAsFixed(0)} COP...'
                            : 'Solicitando autorización Nequi por \$${total.toStringAsFixed(0)} COP...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _onlineType == 'tarjeta'
                            ? '$brand terminada en •••• $last4'
                            : 'Cuenta Nequi: •••• $last4',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.tealAccent, width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.check, color: Colors.tealAccent, size: 32),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '¡Transacción Aprobada!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3460),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text('Ref: $txId', style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                            const SizedBox(height: 2),
                            Text('Autorización: $authCode', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result == true;
  }

  /// Procesa el pedido según el método de pago elegido
  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = Provider.of<AuthController>(context, listen: false);
    final cartController = Provider.of<CartController>(context, listen: false);

    final user = authController.currentUser;
    if (user == null) {
      _showError('Debes iniciar sesión para realizar un pedido.');
      return;
    }

    if (cartController.isEmpty) {
      _showError('Tu carrito está vacío.');
      return;
    }

    // Datos de pago
    String? transaccionId;
    String? codigoAutorizacion;
    String? tarjetaUltimos4;
    String? tarjetaMarca;

    // 1. Si eligió pago en línea, ejecutar validación y pasarela de pago interactiva
    if (_paymentMethod == 'en_linea') {
      if (!_validateOnlinePayment()) return;

      final random = Random();
      final tx = 'TX-APZ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final authCode = 'AUT-${100000 + random.nextInt(900000)}';

      final approved = await _showPaymentGatewayDialog(
        total: cartController.totalAmount,
        txId: tx,
        authCode: authCode,
      );

      if (!approved) {
        _showError('El pago en línea no pudo completarse.');
        return;
      }

      transaccionId = tx;
      codigoAutorizacion = authCode;

      if (_onlineType == 'tarjeta') {
        final clean = _cardNumberController.text.replaceAll(' ', '');
        tarjetaUltimos4 = clean.length >= 4 ? clean.substring(clean.length - 4) : '4242';
        tarjetaMarca = _getCardBrand(_cardNumberController.text);
      } else {
        final phone = _nequiPhoneController.text.replaceAll(' ', '');
        tarjetaUltimos4 = phone.length >= 4 ? phone.substring(phone.length - 4) : '9876';
        tarjetaMarca = 'Nequi';
      }
    }

    setState(() => _isPlacingOrder = true);

    try {
      // 2. Estructura exacta requerida para Firestore ('orders')
      final orderData = {
        'clienteId': user.uid,
        'clienteNombre': user.name,
        'clienteTelefono': user.phone ?? '',
        'productos': cartController.cartItems.map((item) => {
          'nombre': item.product.name,
          'cantidad': item.quantity,
          'precioUnitario': item.product.price,
          'subtotal': item.subtotal,
        }).toList(),
        'total': cartController.totalAmount,
        'direccion': _addressController.text.trim(),
        'metodoPago': _paymentMethod,
        'tipoPago': _paymentMethod == 'en_linea' ? _onlineType : 'efectivo',
        'pagoEstado': _paymentMethod == 'en_linea' ? 'aprobado' : 'pendiente_contra_entrega',
        'transaccionId': transaccionId,
        'codigoAutorizacion': codigoAutorizacion,
        'tarjetaUltimos4': tarjetaUltimos4,
        'tarjetaMarca': tarjetaMarca,
        'cuotas': _paymentMethod == 'en_linea' && _onlineType == 'tarjeta' ? _selectedCuotas : 1,
        'estado': 'pendiente',
        'repartidorId': null,
        'repartidorNombre': null,
        // Usamos timestamp del servidor para sincronía horaria
        'fechaCreacion': FieldValue.serverTimestamp(),
      };

      // 3. Guardamos en Cloud Firestore
      final docRef = await FirebaseFirestore.instance.collection('orders').add(orderData);
      final finalTotal = cartController.totalAmount;

      // 4. Vaciamos el carrito
      cartController.clearCart();

      if (!mounted) return;

      // 5. Navegamos a la pantalla de éxito con comprobante
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessScreen(
            orderId: docRef.id,
            metodoPago: _paymentMethod,
            transaccionId: transaccionId,
            total: finalTotal,
            tarjetaUltimos4: tarjetaUltimos4,
            tarjetaMarca: tarjetaMarca,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      _showError('Error al registrar el pedido: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Confirmar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Dirección de Entrega ──────────────────────────────────
                _sectionHeader(Icons.location_on_outlined, 'Dirección de Entrega'),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Ej. Carrera 15 #85-30, Apto 402, Torre 1',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.home_outlined, color: Color(0xFFE64A19)),
                  ),
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Por favor ingresa la dirección donde te llevaremos la pizza';
                    }
                    if (val.trim().length < 6) {
                      return 'Ingresa una dirección más detallada';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── 2. Método de Pago ────────────────────────────────────────
                _sectionHeader(Icons.payment_outlined, 'Método de Pago'),
                const SizedBox(height: 12),
                _paymentMethodCard(
                  id: 'efectivo',
                  title: 'Efectivo contra entrega',
                  subtitle: 'Paga en efectivo al recibir tu pizza en la puerta de tu casa.',
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(height: 10),
                _paymentMethodCard(
                  id: 'en_linea',
                  title: 'Pago en línea (Tarjeta)',
                  subtitle: 'Tarjeta de crédito / débito (modo de prueba habilitado).',
                  icon: Icons.credit_card_outlined,
                ),

                // ── Detalle Expandible de Pago en Línea ───────────────────────
                if (_paymentMethod == 'en_linea') ...[
                  const SizedBox(height: 14),
                  _buildOnlinePaymentSection(),
                ],

                const SizedBox(height: 24),

                // ── 3. Resumen de solo lectura de la orden ────────────────────
                _sectionHeader(Icons.receipt_long_outlined, 'Resumen de la Orden'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      ...cart.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.quantity}x ${item.product.name}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total a Pagar:',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '\$${cart.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFFFF7043),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── 4. Botón Acción de Pedido ─────────────────────────────────
                ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _paymentMethod == 'en_linea' ? const Color(0xFFE64A19) : const Color(0xFFE64A19),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 5,
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _paymentMethod == 'en_linea' ? Icons.lock_outline : Icons.check_circle,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _paymentMethod == 'en_linea'
                                  ? 'PAGAR \$${cart.totalAmount.toStringAsFixed(0)} Y CONFIRMAR'
                                  : 'REALIZAR PEDIDO (EFECTIVO)',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF7043), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == id;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFE64A19) : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFFE64A19) : Colors.white38,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sección completa de Pago en Línea (Tarjeta / Nequi)
  Widget _buildOnlinePaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE64A19).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pestañas: Tarjeta Crédito / Débito vs Nequi
          Row(
            children: [
              Expanded(
                child: _subMethodButton(
                  id: 'tarjeta',
                  title: 'Tarjeta Débito / Crédito',
                  icon: Icons.credit_card,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _subMethodButton(
                  id: 'nequi',
                  title: 'Nequi / PSE',
                  icon: Icons.phone_android,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_onlineType == 'tarjeta') ...[
            // ── Vista Previa Visual de la Tarjeta ──
            _buildLiveCreditCardPreview(),
            const SizedBox(height: 12),

            // Botón de ayuda para rellenar datos de prueba en 1 tap
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Datos de la Tarjeta:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                TextButton.icon(
                  onPressed: _fillTestCard,
                  icon: const Icon(Icons.bolt, color: Colors.amber, size: 16),
                  label: const Text(
                    '⚡ Tarjeta de prueba',
                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Número de Tarjeta
            TextFormField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _CardNumberFormatter(),
              ],
              style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
              decoration: InputDecoration(
                labelText: 'Número de Tarjeta',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                hintText: '4532 8920 1024 4242',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.credit_card, color: Color(0xFFFF7043)),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      _getCardBrand(_cardNumberController.text),
                      style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF0F3460).withValues(alpha: 0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Nombre del Titular
            TextFormField(
              controller: _cardHolderController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre del Titular',
                labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                hintText: 'COMO APARECE EN EL PLÁSTICO',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF7043)),
                filled: true,
                fillColor: const Color(0xFF0F3460).withValues(alpha: 0.6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Vencimiento + CVV
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CardExpiryFormatter(),
                    ],
                    style: const TextStyle(color: Colors.white, letterSpacing: 1.2),
                    decoration: InputDecoration(
                      labelText: 'Vence (MM/AA)',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: '12/28',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFFFF7043), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF0F3460).withValues(alpha: 0.6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    obscureText: _obscureCvv,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(color: Colors.white, letterSpacing: 2),
                    decoration: InputDecoration(
                      labelText: 'CVV / CVC',
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      hintText: '888',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF7043), size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCvv ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.white54,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F3460).withValues(alpha: 0.6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Selector de Cuotas
            Row(
              children: [
                const Icon(Icons.calendar_view_day_outlined, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                const Text('Cuotas:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3460).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCuotas,
                        dropdownColor: const Color(0xFF16213E),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF7043)),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Cuota (Sin Interés)')),
                          DropdownMenuItem(value: 2, child: Text('2 Cuotas')),
                          DropdownMenuItem(value: 3, child: Text('3 Cuotas')),
                          DropdownMenuItem(value: 6, child: Text('6 Cuotas')),
                          DropdownMenuItem(value: 12, child: Text('12 Cuotas')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCuotas = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // ── Modo Nequi / PSE ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E0854), Color(0xFF1B0933)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.phone_android, color: Colors.purpleAccent, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Nequi Móvil Colombia',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _fillTestNequi,
                        icon: const Icon(Icons.flash_on, color: Colors.tealAccent, size: 14),
                        label: const Text(
                          '⚡ Mi número',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa tu celular registrado en Nequi. Te enviaremos una notificación push para autorizar el cobro.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nequiPhoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(color: Colors.white, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Celular Nequi (10 dígitos)',
                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                      hintText: '310 123 4567',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.dialpad, color: Colors.purpleAccent),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Sello de seguridad
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.verified_user_outlined, color: Colors.tealAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'Transacción protegida por pasarela con tokenización segura',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Pestaña de selección entre Tarjeta y Nequi
  Widget _subMethodButton({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _onlineType == id;
    return GestureDetector(
      onTap: () => setState(() => _onlineType = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE64A19).withValues(alpha: 0.25) : const Color(0xFF0F3460).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7043) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFFFF7043) : Colors.white54),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Previsualización moderna y dinámica de la tarjeta de crédito/débito
  Widget _buildLiveCreditCardPreview() {
    final rawNumber = _cardNumberController.text.trim();
    final displayNumber = rawNumber.isEmpty ? '••••  ••••  ••••  ••••' : rawNumber;
    final holderName = _cardHolderController.text.trim().isEmpty
        ? 'NOMBRE DEL TITULAR'
        : _cardHolderController.text.trim().toUpperCase();
    final expiry = _expiryController.text.trim().isEmpty ? 'MM/AA' : _expiryController.text.trim();
    final brand = _getCardBrand(rawNumber);

    return Container(
      width: double.infinity,
      height: 190,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Fila superior: Chip + Contactless + Marca
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Chip de tarjeta dorado
                  Container(
                    width: 38,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    child: Stack(
                      children: [
                        Center(child: Container(width: 32, height: 1, color: Colors.black26)),
                        Center(child: Container(width: 1, height: 22, color: Colors.black26)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Contactless
                  Transform.rotate(
                    angle: 1.5708,
                    child: const Icon(Icons.wifi, color: Colors.white70, size: 18),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  brand.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // Número de Tarjeta (Centro)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              displayNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2.2,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Fila inferior: Titular y Expiración
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TITULAR DE LA TARJETA',
                      style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      holderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRA',
                    style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
