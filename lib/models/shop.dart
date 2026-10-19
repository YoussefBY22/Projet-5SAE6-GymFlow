import 'enums.dart';
import 'json.dart';
import 'nutrition.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.createdAt,
    this.promoPrice,
    this.images = const [],
    this.active = true,
    this.featured = false,
    this.barcode,
    this.brand,
    this.nameEn,
    this.nutrition,
    this.aiSummary,
  });

  final String id;
  final String name;
  final String description;
  final ProductCategory category;
  final double price;

  /// Prix promotionnel (si inférieur au prix normal).
  final double? promoPrice;
  final int stock;
  final List<String> images;
  final bool active;
  final bool featured;
  final DateTime createdAt;

  /// Code-barres EAN (import Open Food Facts).
  final String? barcode;
  final String? brand;

  /// Nom anglais, utilisé par la recherche bilingue.
  final String? nameEn;
  final Nutrition? nutrition;

  /// « Résumé pour le sportif » rédigé par l'IA, relu par l'admin puis
  /// enregistré (aucun appel à l'IA lors de l'affichage).
  final String? aiSummary;

  bool get inStock => stock > 0;

  /// Prix du gramme de protéine au prix de vente actuel (calcul du code).
  double? get pricePerProteinGram =>
      nutrition?.pricePerProteinGram(effectivePrice);
  bool get onPromo => promoPrice != null && promoPrice! < price;
  double get effectivePrice => onPromo ? promoPrice! : price;
  int get discountPercent =>
      onPromo ? ((1 - promoPrice! / price) * 100).round() : 0;

  Product copyWith({
    String? name,
    String? description,
    ProductCategory? category,
    double? price,
    double? promoPrice,
    bool clearPromo = false,
    int? stock,
    List<String>? images,
    bool? active,
    bool? featured,
  }) => Product(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    category: category ?? this.category,
    price: price ?? this.price,
    promoPrice: clearPromo ? null : (promoPrice ?? this.promoPrice),
    stock: stock ?? this.stock,
    images: images ?? this.images,
    active: active ?? this.active,
    featured: featured ?? this.featured,
    createdAt: createdAt,
    barcode: barcode,
    brand: brand,
    nameEn: nameEn,
    nutrition: nutrition,
    aiSummary: aiSummary,
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category.name,
    'price': price,
    'promoPrice': promoPrice,
    'stock': stock,
    'images': images,
    'active': active,
    'featured': featured,
    'createdAt': dateToJson(createdAt),
    'barcode': barcode,
    'brand': brand,
    'nameEn': nameEn,
    'nutrition': nutrition?.toJson(),
    'aiSummary': aiSummary,
  };

  /// Les champs ajoutés après coup (code-barres, nutrition, résumé IA) sont
  /// facultatifs : les produits déjà enregistrés se chargent sans migration.
  factory Product.fromJson(Json j) => Product(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    category: enumFrom(
      ProductCategory.values,
      j['category'],
      ProductCategory.accessories,
    ),
    price: toDouble(j['price']),
    promoPrice: toDoubleOrNull(j['promoPrice']),
    stock: toInt(j['stock']),
    images: stringList(j['images']),
    active: j['active'] as bool? ?? true,
    featured: j['featured'] as bool? ?? false,
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
    barcode: j['barcode'] as String?,
    brand: j['brand'] as String?,
    nameEn: j['nameEn'] as String?,
    nutrition: j['nutrition'] == null
        ? null
        : Nutrition.fromJson(Map<String, dynamic>.from(j['nutrition'] as Map)),
    aiSummary: j['aiSummary'] as String?,
  );
}

/// Ligne du panier (en mémoire, le temps de la session).
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get total => product.effectivePrice * quantity;

  CartLine copyWith({Product? product, int? quantity}) => CartLine(
    product: product ?? this.product,
    quantity: quantity ?? this.quantity,
  );
}

/// Ligne de commande figée au moment de l'achat.
class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.image,
  });

  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;
  final String? image;

  double get total => unitPrice * quantity;

  Json toJson() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'image': image,
  };

  factory OrderLine.fromJson(Json j) => OrderLine(
    productId: j['productId'] as String,
    name: j['name'] as String,
    unitPrice: toDouble(j['unitPrice']),
    quantity: toInt(j['quantity'], 1),
    image: j['image'] as String?,
  );
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.number,
    required this.userId,
    required this.lines,
    required this.status,
    required this.paymentMethod,
    required this.paymentRef,
    required this.createdAt,
  });

  final String id;

  /// Numéro lisible « GF-2026-0007 ».
  final String number;
  final String userId;
  final List<OrderLine> lines;
  final OrderStatus status;

  /// « stripe_test » ou « simulated ».
  final String paymentMethod;
  final String paymentRef;
  final DateTime createdAt;

  double get total => lines.fold(0, (s, l) => s + l.total);
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity);

  /// Commande conservée pour la comptabilité mais détachée de la personne.
  ShopOrder anonymized(String anonymousId) => ShopOrder(
    id: id,
    number: number,
    userId: anonymousId,
    lines: lines,
    status: status,
    paymentMethod: paymentMethod,
    paymentRef: paymentRef,
    createdAt: createdAt,
  );

  ShopOrder copyWith({OrderStatus? status}) => ShopOrder(
    id: id,
    number: number,
    userId: userId,
    lines: lines,
    status: status ?? this.status,
    paymentMethod: paymentMethod,
    paymentRef: paymentRef,
    createdAt: createdAt,
  );

  Json toJson() => {
    'id': id,
    'number': number,
    'userId': userId,
    'lines': lines.map((l) => l.toJson()).toList(),
    'status': status.name,
    'paymentMethod': paymentMethod,
    'paymentRef': paymentRef,
    'createdAt': dateToJson(createdAt),
  };

  factory ShopOrder.fromJson(Json j) => ShopOrder(
    id: j['id'] as String,
    number: j['number'] as String,
    userId: j['userId'] as String,
    lines: jsonList(j['lines']).map(OrderLine.fromJson).toList(),
    status: enumFrom(OrderStatus.values, j['status'], OrderStatus.paid),
    paymentMethod: j['paymentMethod'] as String? ?? 'simulated',
    paymentRef: j['paymentRef'] as String? ?? '',
    createdAt: dateOr(j['createdAt'], DateTime(2026)),
  );
}
