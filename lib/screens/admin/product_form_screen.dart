import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_model.dart';

/// Formulario para Crear y Editar Productos (Pizzas y Bebidas) en Cloud Firestore.
///
/// Permite al Administrador:
/// 1. Seleccionar fotos desde la galería o cámara con `image_picker`.
/// 2. Subir la imagen en bytes a Firebase Storage (`products/{timestamp}.jpg`).
/// 3. Guardar o actualizar los metadatos (nombre, precio, categoría, descripción, URL) en Firestore.
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _sizeController = TextEditingController();
  final _urlController = TextEditingController();

  String _selectedCategory = 'pizza';
  Uint8List? _pickedBytes;
  String _existingImageUrl = '';

  bool _isSaving = false;
  String _statusMessage = '';

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameController.text = p.name;
      _descController.text = p.description;
      _priceController.text = p.price.toStringAsFixed(0);
      _sizeController.text = p.pizzaSize;
      _selectedCategory = p.categoria.toLowerCase() == 'bebida' ? 'bebida' : 'pizza';
      _existingImageUrl = p.imageUrl;
      _urlController.text = p.imageUrl;
    } else {
      _sizeController.text = 'Mediana';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// Permite elegir una imagen desde la galería o la cámara
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _pickedBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar imagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Guarda el producto (sube foto a Storage si hay una nueva y guarda documento en Firestore)
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _statusMessage = 'Preparando datos...';
    });

    try {
      String finalImageUrl = _urlController.text.trim();

      // 1. Si seleccionó un archivo local, subirlo a Firebase Storage
      if (_pickedBytes != null) {
        setState(() {
          _statusMessage = 'Subiendo imagen a Firebase Storage...';
        });

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$_selectedCategory.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('products')
            .child(fileName);

        final uploadTask = storageRef.putData(
          _pickedBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        final snapshot = await uploadTask;
        finalImageUrl = await snapshot.ref.getDownloadURL();
      } else if (finalImageUrl.isEmpty && _existingImageUrl.isNotEmpty) {
        finalImageUrl = _existingImageUrl;
      }

      // 2. Guardar o actualizar en Cloud Firestore
      setState(() {
        _statusMessage = _isEditing ? 'Actualizando en Firestore...' : 'Creando producto en Firestore...';
      });

      final productData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'categoria': _selectedCategory,
        'imageUrl': finalImageUrl,
        'pizza_size': _sizeController.text.trim().isNotEmpty
            ? _sizeController.text.trim()
            : (_selectedCategory == 'pizza' ? 'Mediana' : '500ml'),
        'stock': widget.product?.stock ?? 50,
      };

      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product!.id.toString())
            .update({
          ...productData,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('products').add({
          ...productData,
          'available': true, // Activo por defecto en productos nuevos
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '✅ Producto actualizado correctamente'
                : '🎉 ¡Producto creado y publicado con éxito!',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Color(0xFFE64A19)),
              SizedBox(width: 8),
              Text('Error al guardar', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Ocurrió un error al procesar el producto:\n$e\n\n'
            'Verifica que Firebase Storage esté habilitado en Firebase Console.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido', style: TextStyle(color: Color(0xFFFF7043))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Producto' : 'Nuevo Producto',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── SECCIÓN FOTO DEL PRODUCTO ─────────────────────────────
                  _buildImagePickerSection(),
                  const SizedBox(height: 24),

                  // ── CATEGORÍA: PIZZA O BEBIDA ─────────────────────────────
                  const Text(
                    'Categoría del Producto',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCategoryOption('pizza', '🍕 Pizza', Icons.local_pizza_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCategoryOption('bebida', '🥤 Bebida', Icons.local_drink_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── NOMBRE ────────────────────────────────────────────────
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _selectedCategory == 'pizza' ? 'Nombre de la Pizza' : 'Nombre de la Bebida',
                      hintText: _selectedCategory == 'pizza' ? 'Ej. Pepperoni Suprema' : 'Ej. Coca-Cola 400ml',
                      prefixIcon: Icon(
                        _selectedCategory == 'pizza' ? Icons.local_pizza_outlined : Icons.local_drink_outlined,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa el nombre del producto';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── PRECIO Y TAMAÑO/PRESENTACIÓN ──────────────────────────
                  Row(
                    children: [
                      // Precio
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Precio (\$)',
                            hintText: 'Ej. 35000',
                            prefixIcon: Icon(Icons.attach_money_rounded),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Ingresa el precio';
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) return 'Precio inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Tamaño
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _sizeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: _selectedCategory == 'pizza' ? 'Tamaño' : 'Porción',
                            hintText: _selectedCategory == 'pizza' ? 'Mediana' : '500ml',
                            prefixIcon: const Icon(Icons.aspect_ratio_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── DESCRIPCIÓN / INGREDIENTES ────────────────────────────
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Descripción / Ingredientes',
                      hintText: _selectedCategory == 'pizza'
                          ? 'Salsa de tomate especial, queso mozzarella, pepperoni seleccionado...'
                          : 'Bebida helada refrescante servida en botella de vidrio.',
                      prefixIcon: const Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa una descripción breve';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── OPCIÓN ADICIONAL: URL WEB DIRECTA ─────────────────────
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'O pegar URL de imagen directamente',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    children: [
                      TextFormField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'URL de imagen (opcional)',
                          hintText: 'https://images.unsplash.com/...',
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── BOTÓN GUARDAR ─────────────────────────────────────────
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE64A19),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: Text(
                        _isEditing ? 'GUARDAR CAMBIOS' : 'PUBLICAR PRODUCTO',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── OVERLAY DE CARGA Y SUBIDA A STORAGE ───────────────────────────
          if (_isSaving)
            Container(
              color: Colors.black87,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFE64A19)),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Selector y preview visual de la foto
  Widget _buildImagePickerSection() {
    final hasPickedBytes = _pickedBytes != null;
    final hasExistingUrl = _existingImageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto del Producto',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F3460),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPickedBytes)
                Image.memory(_pickedBytes!, fit: BoxFit.cover)
              else if (hasExistingUrl)
                Image.network(
                  _existingImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              else
                _buildPlaceholder(),

              // Botones superpuestos para cambiar foto
              Positioned(
                bottom: 10,
                right: 10,
                child: Row(
                  children: [
                    _buildPickButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Galería',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                    const SizedBox(width: 8),
                    _buildPickButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Cámara',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedCategory == 'pizza' ? Icons.local_pizza_outlined : Icons.local_drink_outlined,
            size: 52,
            color: Colors.white30,
          ),
          const SizedBox(height: 8),
          const Text(
            'Elige una foto desde la galería o cámara',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFFF7043)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption(String key, String label, IconData icon) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = key;
          if (!_isEditing) {
            _sizeController.text = key == 'pizza' ? 'Mediana' : '500ml';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE64A19) : const Color(0xFF0F3460),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF7043) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
