import '../core/errors.dart';
import '../core/formatters.dart';
import '../models/enums.dart';
import '../models/shop.dart';
import '../repositories/repository.dart';
import 'backend.dart';
import 'payment/payment_gateway.dart';

/// API interne des commandes : contrôle de stock, enregistrement après
/// paiement, suivi (payée → préparée → remise), chiffre d'affaires.
class OrderService {
  OrderService(this._b);
  final Backend _b;

  /// Vérifie que chaque ligne est encore disponible (avant ET après le
  /// paiement : le stock est revérifié au dernier moment).
  void checkStock(List<CartLine> lines) {
    if (lines.isEmpty) {
      throw const BusinessRuleException('Votre panier est vide.');
    }
    for (final l in lines) {
      final p = _b.products.byId(l.product.id);
      if (p == null || !p.active) {
        throw BusinessRuleException(
          '« ${l.product.name} » n\'est plus disponible.',
        );
      }
      if (l.quantity < 1) {
        throw const ValidationException('Quantité invalide.');
      }
      if (p.stock < l.quantity) {
        throw BusinessRuleException(
          p.stock == 0
              ? '« ${p.name} » est en rupture de stock.'
              : 'Stock insuffisant pour « ${p.name} » (reste ${p.stock}).',
        );
      }
    }
  }

  double totalOf(List<CartLine> lines) => lines.fold(0, (s, l) {
    final p = _b.products.byId(l.product.id) ?? l.product;
    return s + p.effectivePrice * l.quantity;
  });

  /// Crée la commande après un paiement accepté et décrémente le stock.
  Future<ShopOrder> placeOrder(
    List<CartLine> lines,
    PaymentResult payment,
  ) async {
    final me = _b.requireUser();
    if (!payment.success) {
      throw const BusinessRuleException('Paiement non validé.');
    }
    checkStock(lines);
    final orderLines = <OrderLine>[];
    for (final l in lines) {
      final p = _b.products.byId(l.product.id)!;
      orderLines.add(
        OrderLine(
          productId: p.id,
          name: p.name,
          unitPrice: p.effectivePrice,
          quantity: l.quantity,
          image: p.images.isEmpty ? null : p.images.first,
        ),
      );
      await _b.products.save(p.copyWith(stock: p.stock - l.quantity));
    }
    final now = _b.now();
    final order = ShopOrder(
      id: IdGen.next('o_'),
      number: _nextNumber(now.year),
      userId: me.id,
      lines: orderLines,
      status: OrderStatus.paid,
      paymentMethod: payment.method,
      paymentRef: payment.reference,
      createdAt: now,
    );
    await _b.orders.save(order);
    await _b.notifications.notify(
      me.id,
      NotificationType.order,
      'Commande ${order.number} payée',
      '${Fmt.money(order.total)} · à retirer à l\'accueil dès qu\'elle est préparée.',
      route: '/orders',
      refId: order.id,
    );
    _b.cart.refreshProducts();
    _b.bus.emit();
    return order;
  }

  String _nextNumber(int year) {
    final count = _b.orders.where((o) => o.createdAt.year == year).length + 1;
    return 'GF-$year-${count.toString().padLeft(4, '0')}';
  }

  List<ShopOrder> mine() {
    final me = _b.requireUser();
    return _b.orders.where((o) => o.userId == me.id)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  ShopOrder? byId(String id) {
    final me = _b.requireUser();
    final o = _b.orders.byId(id);
    if (o == null) return null;
    if (o.userId != me.id && !me.isAdmin) {
      throw const PermissionDeniedException();
    }
    return o;
  }

  // ---------------- Super admin ----------------

  List<ShopOrder> all({OrderStatus? status}) {
    _b.requireRole(Backend.adminOnly);
    return _b.orders.where((o) => status == null || o.status == status)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Passe la commande à l'étape suivante et prévient le client.
  Future<ShopOrder> advance(String orderId) async {
    _b.requireRole(Backend.adminOnly);
    final o = _b.orders.byId(orderId) ?? (throw const NotFoundException());
    final next = switch (o.status) {
      OrderStatus.paid => OrderStatus.prepared,
      OrderStatus.prepared => OrderStatus.delivered,
      OrderStatus.delivered => throw const BusinessRuleException(
        'Commande déjà remise.',
      ),
    };
    final updated = await _b.orders.save(o.copyWith(status: next));
    await _b.notifications.notify(
      o.userId,
      NotificationType.order,
      next == OrderStatus.prepared
          ? 'Commande ${o.number} prête'
          : 'Commande ${o.number} remise',
      next == OrderStatus.prepared
          ? 'Votre commande vous attend à l\'accueil.'
          : 'Merci pour votre achat !',
      route: '/orders',
      refId: o.id,
    );
    await _b.audit.log(
      'Commande ${next.label.toLowerCase()}',
      o.number,
      targetId: o.id,
    );
    _b.bus.emit();
    return updated;
  }

  double revenue({DateTime? since}) => _b.orders
      .where((o) => since == null || !o.createdAt.isBefore(since))
      .fold(0, (s, o) => s + o.total);
}
