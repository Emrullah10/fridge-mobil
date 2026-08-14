import '../../../core/api/api_client.dart';

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
}
