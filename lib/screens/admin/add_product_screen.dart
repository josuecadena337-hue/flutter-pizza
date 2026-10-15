import 'package:flutter/material.dart';
import 'product_form_screen.dart';

/// Redirección al nuevo formulario de productos con soporte para Cloud Firestore y Firebase Storage.
class AddProductScreen extends StatelessWidget {
  const AddProductScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductFormScreen();
  }
}
