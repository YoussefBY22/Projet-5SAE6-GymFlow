import '../core/errors.dart';
import '../core/search.dart';
import '../models/enums.dart';
import '../models/prefs.dart';
import '../models/shop.dart';
import '../repositories/repository.dart';
import 'backend.dart';
import 'exercise_service.dart';

/// API interne du catalogue boutique. Écriture : super admin uniquement.
class ProductService {
  ProductService(this._b);
  final Backend _b;

  List<Product> list({String query = '', ProductCategory? category}) {
    final me = _b.requireUser();
    final q = ExerciseService.normalize(query);
    return _b.products.where(
      (p) =>
          (p.active || me.isAdmin) &&
          (category == null || p.category == category) &&
          (q.isEmpty ||
              ExerciseService.normalize(
                '${p.name} ${p.category.label}',
              ).contains(q)),
    )..sort((a, b) {
      if (a.inStock != b.inStock) return a.inStock ? -1 : 1;
      return a.name.compareTo(b.name);
    });
  }

  /// Recherche + filtres de la boutique : `category`, `price`
  /// (lt20, 20_50, 50_100, gt100 DT), `stock` (in), `promo` (only).
  List<Product> search({String query = '', FilterValues filters = const {}}) {
    final f = filters;
    final v = Search.expand(query);
    bool priceOk(double p) => f
        .of('price')
        .any(
          (k) => switch (k) {
            'lt20' => p < 20,
            '20_50' => p >= 20 && p <= 50,
            '50_100' => p > 50 && p <= 100,
            'gt100' => p > 100,
            _ => true,
          },
        );
    return list().where((p) {
      if (f.isActive('category') && !f.has('category', p.category.name)) {
        return false;
      }
      if (f.isActive('price') && !priceOk(p.effectivePrice)) return false;
      if (f.has('stock', 'in') && !p.inStock) return false;
      if (f.has('promo', 'only') && !p.onPromo) return false;
      return Search.matches(
        v,
        '${p.name} ${p.category.label} ${p.description}',
      );
    }).toList();
  }

  List<Product> featured() =>
      list().where((p) => p.featured || p.onPromo).toList();

  Product? byId(String id) => _b.products.byId(id);

  Future<Product> save({
    String? id,
    required String name,
    required String description,
    required ProductCategory category,
    required double price,
    double? promoPrice,
    required int stock,
    required List<String> images,
    bool active = true,
    bool featured = false,
  }) async {
    _b.requireRole(Backend.adminOnly);
    if (name.trim().length < 3) {
      throw const ValidationException('Nom : 3 caractères minimum.');
    }
    if (price <= 0 || price > 5000) {
      throw const ValidationException('Prix : entre 0,1 et 5 000 TND.');
    }
    if (promoPrice != null && (promoPrice <= 0 || promoPrice >= price)) {
      throw const ValidationException(
        'Le prix promo doit être inférieur au prix normal.',
      );
    }
    if (stock < 0 || stock > 10000) {
      throw const ValidationException('Stock : entre 0 et 10 000.');
    }
    final Product p;
    if (id == null) {
      p = Product(
        id: IdGen.next('pr_'),
        name: name.trim(),
        description: description.trim(),
        category: category,
        price: price,
        promoPrice: promoPrice,
        stock: stock,
        images: images,
        active: active,
        featured: featured,
        createdAt: _b.now(),
      );
    } else {
      final existing =
          _b.products.byId(id) ?? (throw const NotFoundException());
      p = existing.copyWith(
        name: name.trim(),
        description: description.trim(),
        category: category,
        price: price,
        promoPrice: promoPrice,
        clearPromo: promoPrice == null,
        stock: stock,
        images: images,
        active: active,
        featured: featured,
      );
    }
    await _b.products.save(p);
    await _b.audit.log(
      id == null ? 'Création de produit' : 'Modification de produit',
      p.name,
      targetId: p.id,
    );
    _b.cart.refreshProducts();
    _b.bus.emit();
    return p;
  }

  Future<void> adjustStock(String id, int delta) async {
    _b.requireRole(Backend.adminOnly);
    final p = _b.products.byId(id) ?? (throw const NotFoundException());
    final next = p.stock + delta;
    if (next < 0) throw const BusinessRuleException('Stock insuffisant.');
    await _b.products.save(p.copyWith(stock: next));
    _b.cart.refreshProducts();
    _b.bus.emit();
  }

  /// Supprime un produit jamais commandé ; sinon il est archivé (inactif).
  Future<void> delete(String id) async {
    _b.requireRole(Backend.adminOnly);
    final p = _b.products.byId(id) ?? (throw const NotFoundException());
    final ordered = _b.orders.all.any(
      (o) => o.lines.any((l) => l.productId == id),
    );
    if (ordered) {
      await _b.products.save(p.copyWith(active: false));
      await _b.audit.log('Archivage de produit', p.name, targetId: id);
    } else {
      await _b.products.delete(id);
      await _b.audit.log('Suppression de produit', p.name, targetId: id);
    }
    _b.cart.refreshProducts();
    _b.bus.emit();
  }
}
