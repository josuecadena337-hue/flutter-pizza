import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/product_model.dart';

class ProductController with ChangeNotifier {
  List<Product> _products = [];
  List<Product> get products => _products;

  Future<void> loadProducts() async {
    _products = await DBHelper.instance.getProducts();
    notifyListeners();
  }

  Future<bool> addProduct(Product product) async {
    final result = await DBHelper.instance.insertProduct(product);
    if (result > 0) {
      await loadProducts();
      return true;
    }
    return false;
  }

  Future<bool> updateProduct(Product product) async {
    final result = await DBHelper.instance.updateProduct(product);
    if (result > 0) {
      await loadProducts();
      return true;
    }
    return false;
  }

  Future<bool> deleteProduct(int id) async {
    final result = await DBHelper.instance.deleteProduct(id);
    if (result > 0) {
      await loadProducts();
      return true;
    }
    return false;
  }
}
