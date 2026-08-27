import '../../../core/api/api_client.dart';

class ProductCategory {
  const ProductCategory({required this.key, required this.nameTr});

  final String key;
  final String nameTr;

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
        key: json['key'] as String,
        nameTr: json['nameTr'] as String,
      );
}

class Product {
  const Product({
    required this.id,
    required this.canonicalName,
    required this.defaultUnit,
    required this.isGlobal,
    required this.source,
  });

  final String id;
  final String canonicalName;
  final String defaultUnit;
  final bool isGlobal;
  final String source;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        canonicalName: json['canonicalName'] as String,
        defaultUnit: json['defaultUnit'] as String,
        isGlobal: json['isGlobal'] as bool? ?? false,
        source: json['source'] as String? ?? 'user',
      );
}

class BarcodeLookupResult {
  const BarcodeLookupResult({required this.found, required this.barcode, this.product, this.source});
  final bool found;
  final String barcode;
  final Product? product;
  final String? source; // 'catalog' | 'openfoodfacts'
}

class ProductRepository {
  ProductRepository(this._client);

  final ApiClient _client;

  Future<List<Product>> search(String householdId, {String query = ''}) async {
    final response = await _client.dio.get(
      '/households/$householdId/products',
      queryParameters: query.isNotEmpty ? {'q': query} : null,
    );
    final products = response.data['products'] as List;
    return products.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<Product> create(String householdId, {required String canonicalName, required String defaultUnit}) async {
    final response = await _client.dio.post(
      '/households/$householdId/products',
      data: {'canonicalName': canonicalName, 'defaultUnit': defaultUnit},
    );
    return Product.fromJson(response.data['product'] as Map<String, dynamic>);
  }

  /// Barkod -> ürün. [found] false ise [barcode] döner ve ürün yaratılmamıştır
  /// (kullanıcı manuel eklemeli).
  Future<BarcodeLookupResult> lookupBarcode(String householdId, String code) async {
    final response = await _client.dio.get('/households/$householdId/products/barcode/$code');
    final data = response.data as Map<String, dynamic>;
    return BarcodeLookupResult(
      found: data['found'] as bool? ?? false,
      barcode: data['barcode'] as String? ?? code,
      product: data['product'] != null
          ? Product.fromJson(data['product'] as Map<String, dynamic>)
          : null,
      source: data['source'] as String?,
    );
  }

  Future<List<ProductCategory>> listCategories(String householdId) async {
    final response = await _client.dio.get('/households/$householdId/products/categories');
    final categories = response.data['categories'] as List;
    return categories.map((c) => ProductCategory.fromJson(c as Map<String, dynamic>)).toList();
  }
}
