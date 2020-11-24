import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/http_exception.dart';
import './product.dart';

class Products with ChangeNotifier {
  final String authToken;
  final String userId;

  Products(this.authToken, this._items, this.userId);

  List<Product> _items = [];

  List<Product> get items {
    return [..._items];
  }

  List<Product> get favoriteItems {
    return _items.where((prodItem) => prodItem.isFavorite).toList();
  }

  Product findById(String id) {
    return _items.firstWhere((prod) => prod.id == id);
  }

  Future<void> fetchProducts([bool filterByUser = false]) async {
    final filterValue =
        filterByUser ? 'orderBy="userId"&equalTo="$userId"' : '';
    final url =
        'https://shops-app-84d00.firebaseio.com/products.json?auth=$authToken&$filterValue';
    try {
      final response = await http.get(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data == null) {
        return;
      }
      final favUrl =
          'https://shops-app-84d00.firebaseio.com/userFavorites/$userId.json?auth=$authToken';
      final getFav = await http.get(favUrl);
      final favData = json.decode(getFav.body);
      final List<Product> loadedProducts = [];
      data.forEach(
        (id, product) {
          loadedProducts.add(
            Product(
              id: id,
              title: product['title'],
              description: product['description'],
              price: product['price'],
              imageUrl: product['imageUrl'],
              isFavorite: favData == null ? false : favData[id] ?? false,
            ),
          );
        },
      );
      _items = loadedProducts;
      notifyListeners();
    } catch (err) {
      throw (err);
    }
  }

  Future<void> addProduct(Product product) async {
    final url =
        'https://shops-app-84d00.firebaseio.com/products.json?auth=$authToken';
    try {
      final response = await http.post(
        url,
        body: json.encode(
          {
            'title': product.title,
            'description': product.description,
            'imageUrl': product.imageUrl,
            'price': product.price,
            'userId': userId,
          },
        ),
      );
      final newProduct = Product(
        id: json.decode(response.body)['name'],
        title: product.title,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
      );
      _items.add(newProduct);
      notifyListeners();
    } catch (err) {
      print(err);
      throw err;
    }
  }

  Future<void> updateProduct(String id, Product newProduct) async {
    final prodIndex = _items.indexWhere((element) => element.id == id);
    if (prodIndex >= 0) {
      final url =
          'https://shops-app-84d00.firebaseio.com/products/$id.json?auth=$authToken';
      await http.patch(
        url,
        body: json.encode(
          {
            'title': newProduct.title,
            'description': newProduct.description,
            'price': newProduct.price,
            'imageUrl': newProduct.imageUrl,
            'isFavorite': newProduct.isFavorite,
          },
        ),
      );
      _items[prodIndex] = newProduct;
      notifyListeners();
    }
  }

  Future<void> deleteProduct(String id) async {
    final url =
        'https://shops-app-84d00.firebaseio.com/products/$id.json?auth=$authToken';
    final currentProductIndex =
        _items.indexWhere((element) => element.id == id);
    var currentProduct = _items[currentProductIndex];
    _items.removeAt(currentProductIndex);
    notifyListeners();
    final response = await http.delete(url);
    if (response.statusCode >= 400) {
      _items.insert(currentProductIndex, currentProduct);
      notifyListeners();
      throw HttpException('Could not delete the product!');
    }
    currentProduct = null;
  }
}
