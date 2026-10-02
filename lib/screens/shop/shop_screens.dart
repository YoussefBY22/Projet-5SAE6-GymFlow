import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/responsive.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/prefs.dart';
import '../../models/shop.dart';
import '../../services/backend.dart';
import '../../services/payment/payment_gateway.dart';
import '../../widgets/animations.dart';
import '../../widgets/bits.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../shell/main_shell.dart';

/// Achat direct depuis la fiche produit (sans passer par le panier).
class DirectPurchase {
  const DirectPurchase(this.productId, this.quantity);
  final String productId;
  final int quantity;
}

/// Catalogue de la boutique en grille (GridView.builder).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _listKey = 'shop';
  final _query = TextEditingController();
  late FilterValues _filters = Backend.I.library.savedFilters(_listKey);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setFilters(FilterValues f) {
    setState(() => _filters = f);
    Backend.I.library.saveFilters(_listKey, f);
  }

  List<Product> _results(FilterValues f) =>
      Backend.I.productService.search(query: _query.text, filters: f);

  static final _groups = [
    FilterGroup(
      id: 'category',
      title: 'Catégorie',
      icon: Icons.category_outlined,
      options: [
        for (final c in ProductCategory.values)
          FilterOption(c.name, c.label, icon: c.icon),
      ],
    ),
    const FilterGroup(
      id: 'price',
      title: 'Prix',
      icon: Icons.payments_outlined,
      options: [
        FilterOption('lt20', 'Moins de 20 DT'),
        FilterOption('20_50', '20 à 50 DT'),
        FilterOption('50_100', '50 à 100 DT'),
        FilterOption('gt100', 'Plus de 100 DT'),
      ],
    ),
    const FilterGroup(
      id: 'promo',
      title: 'Bons plans',
      icon: Icons.local_offer_outlined,
      options: [FilterOption('only', 'En promotion', icon: Icons.sell)],
    ),
    const FilterGroup(
      id: 'stock',
      title: 'Disponibilité',
      icon: Icons.inventory_2_outlined,
      options: [FilterOption('in', 'En stock', icon: Icons.check)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text('Boutique'),
        actions: [
          IconButton(
            tooltip: 'Mes commandes',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.pushNamed(context, Routes.orders),
          ),
          const CartButton(),
        ],
      ),
      body: ListenableBuilder(
        listenable: b.bus,
        builder: (context, _) {
          final products = _results(_filters);
          return Column(
            children: [
              FilterSearchBar(
                groups: _groups,
                values: _filters,
                onChanged: _setFilters,
                resultCount: (f) => _results(f).length,
                hint: 'Rechercher un produit',
                query: _query,
                onQuery: (_) => setState(() {}),
              ),
              Expanded(
                child: products.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'Aucun produit',
                        message:
                            'Essayez une autre recherche ou d\'autres filtres.',
                        action: _filters.activeCount > 0
                            ? 'Tout effacer'
                            : null,
                        onAction: () => _setFilters({}),
                      )
                    : GridView.builder(
                        padding: pagePadding(
                          context,
                          maxWidth: 1200,
                          top: Gap.s,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: Gap.m,
                              crossAxisSpacing: Gap.m,
                              childAspectRatio: 0.68,
                            ),
                        itemCount: products.length,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          child: ProductCard(product: products[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fiche produit : photos, description, stock, ajout panier / achat direct.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final p = b.productService.byId(widget.productId);
        if (p == null || (!p.active && !b.auth.currentUser!.isAdmin)) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Produit indisponible',
              message: 'Ce produit n\'est plus en vente.',
            ),
          );
        }
        final images = p.images.isEmpty ? <String?>[null] : p.images;
        final maxQty = p.stock.clamp(1, 10);
        if (_qty > maxQty) _qty = maxQty;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.category.label),
            actions: const [CartButton()],
          ),
          body: ListView(
            children: [
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    PageView.builder(
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) => i == 0
                          ? Hero(
                              tag: 'pr_${p.id}',
                              child: NetImage(
                                images[i],
                                width: double.infinity,
                                fallbackIcon: p.category.icon,
                              ),
                            )
                          : NetImage(images[i], width: double.infinity),
                    ),
                    if (images.length > 1)
                      Positioned(
                        bottom: Gap.s,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < images.length; i++)
                              AnimatedContainer(
                                duration: kAnim,
                                margin: const EdgeInsets.all(3),
                                width: i == _photo ? 18 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: i == _photo
                                      ? AppColors.gold
                                      : AppColors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.navy),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: AppText.title(size: 22)),
                    const SizedBox(height: Gap.s),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Fmt.money(p.effectivePrice),
                          style: AppText.display(
                            color: AppColors.red,
                            size: 26,
                          ),
                        ),
                        if (p.onPromo) ...[
                          const SizedBox(width: Gap.s),
                          Text(
                            Fmt.money(p.price),
                            style: AppText.label().copyWith(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: Gap.s),
                          Pill(
                            '-${p.discountPercent} %',
                            color: AppColors.gold,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: Gap.s),
                    p.inStock
                        ? Pill(
                            p.stock <= 5
                                ? 'Plus que ${p.stock} en stock'
                                : 'En stock',
                            color: p.stock <= 5
                                ? AppColors.gold
                                : AppColors.success,
                            icon: Icons.inventory_2_outlined,
                          )
                        : const Pill(
                            'Rupture de stock',
                            color: AppColors.red,
                            icon: Icons.block,
                          ),
                    const SizedBox(height: Gap.m),
                    Text(p.description, style: AppText.body()),
                    const SizedBox(height: Gap.l),
                    if (p.inStock) ...[
                      Row(
                        children: [
                          Text('Quantité', style: AppText.subtitle(size: 15)),
                          const Spacer(),
                          _QtyStepper(
                            value: _qty,
                            max: maxQty,
                            onChanged: (v) => setState(() => _qty = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.m),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('add_to_cart'),
                              onPressed: () async {
                                final ok = await runAction(
                                  context,
                                  () async => b.cart.add(p, _qty),
                                );
                                if (ok && context.mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Ajouté au panier ($_qty)',
                                        ),
                                        action: SnackBarAction(
                                          label: 'Voir',
                                          onPressed: () => Navigator.pushNamed(
                                            context,
                                            Routes.cart,
                                          ),
                                        ),
                                      ),
                                    );
                                }
                              },
                              icon: const Icon(Icons.add_shopping_cart),
                              label: const Text('Au panier'),
                            ),
                          ),
                          const SizedBox(width: Gap.s),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                Routes.checkout,
                                arguments: DirectPurchase(p.id, _qty),
                              ),
                              child: const Text('Acheter'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Gap.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuer',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: AppText.stat(size: 16),
            ),
          ),
          IconButton(
            tooltip: 'Augmenter',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Panier : quantités, total, passage au paiement.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Backend.I.cart;
    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final lines = cart.lines;
        return Scaffold(
          appBar: AppBar(title: const Text('Mon panier')),
          body: lines.isEmpty
              ? EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Panier vide',
                  message:
                      'Compléments, accessoires, vêtements… faites-vous plaisir !',
                  action: 'Voir la boutique',
                  onAction: () => Navigator.pop(context),
                )
              : ListView.separated(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                  itemBuilder: (_, i) {
                    final l = lines[i];
                    return Dismissible(
                      key: ValueKey(l.product.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: Gap.l),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(Gap.radius),
                        ),
                        child: const Icon(Icons.delete, color: AppColors.white),
                      ),
                      onDismissed: (_) => cart.remove(l.product.id),
                      child: GfCard(
                        padding: const EdgeInsets.all(Gap.s),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: NetImage(
                                l.product.images.isEmpty
                                    ? null
                                    : l.product.images.first,
                                width: 72,
                                height: 72,
                                cacheWidth: 220,
                              ),
                            ),
                            const SizedBox(width: Gap.s),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.subtitle(size: 14),
                                  ),
                                  Text(
                                    Fmt.money(l.product.effectivePrice),
                                    style: AppText.label(),
                                  ),
                                  Text(
                                    Fmt.money(l.total),
                                    style: AppText.stat(
                                      color: AppColors.red,
                                      size: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _QtyStepper(
                              value: l.quantity,
                              max: l.product.stock.clamp(1, 10),
                              onChanged: (v) => runAction(
                                context,
                                () async => cart.setQuantity(l.product.id, v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          bottomNavigationBar: lines.isEmpty
              ? null
              : _TotalBar(
                  total: cart.total,
                  label: 'Passer au paiement',
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.checkout),
                ),
        );
      },
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.total,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final double total;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(Gap.m),
        decoration: const BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14002855),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Total', style: AppText.subtitle()),
                const Spacer(),
                Text(
                  Fmt.money(total),
                  key: const Key('cart_total'),
                  style: AppText.display(color: AppColors.red, size: 24),
                ),
              ],
            ),
            const SizedBox(height: Gap.s),
            LoadingButton(
              key: const Key('checkout_button'),
              label: label,
              icon: Icons.lock_outline,
              loading: loading,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paiement : Stripe Checkout (mode test) si une clé est fournie,
/// sinon passerelle simulée avec formulaire carte.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, this.direct});
  final DirectPurchase? direct;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/30');
  final _cvc = TextEditingController(text: '123');
  final _holder = TextEditingController();
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _holder.text = Backend.I.auth.currentUser?.fullName ?? '';
  }

  @override
  void dispose() {
    for (final c in [_number, _expiry, _cvc, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  List<CartLine> get _lines {
    final b = Backend.I;
    final d = widget.direct;
    if (d != null) {
      final p = b.products.byId(d.productId);
      return p == null ? [] : [CartLine(product: p, quantity: d.quantity)];
    }
    return b.cart.lines;
  }

  Future<void> _pay() async {
    final b = Backend.I;
    final lines = _lines;
    final gateway = b.payment;
    if (gateway is SimulatedPaymentGateway &&
        !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _paying = true);
    try {
      b.orderService.checkStock(lines); // 1re vérification du stock
      final total = b.orderService.totalOf(lines);
      PaymentResult? result;
      if (gateway is StripeCheckoutGateway) {
        final session = await gateway.createSession(
          lines: lines,
          customerEmail: b.auth.currentUser!.email,
        );
        if (!mounted) return;
        final sessionId = await Navigator.push<String?>(
          context,
          gfRoute(StripeCheckoutPage(session: session)),
        );
        if (sessionId == null) {
          throw const BusinessRuleException('Paiement annulé.');
        }
        result = await gateway.verify(sessionId);
      } else if (gateway is SimulatedPaymentGateway) {
        result = await gateway.charge(
          cardNumber: _number.text,
          expiry: _expiry.text,
          cvc: _cvc.text,
          amount: total,
          now: b.now(),
        );
      }
      if (result == null || !result.success) {
        throw const BusinessRuleException('Paiement non finalisé.');
      }
      // Le stock est revérifié au moment d'enregistrer la commande.
      final order = await b.orderService.placeOrder(lines, result);
      if (widget.direct == null) b.cart.clear();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          Routes.orderConfirmation,
          arguments: order.id,
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    final lines = _lines;
    final total = b.orderService.totalOf(lines);
    final simulated = b.payment is SimulatedPaymentGateway;
    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: pagePadding(context, maxWidth: 760, bottom: Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Récapitulatif', style: AppText.title(size: 18)),
              const SizedBox(height: Gap.s),
              GfCard(
                child: Column(
                  children: [
                    for (final l in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${l.quantity} × ${l.product.name}',
                                style: AppText.body(size: 14),
                              ),
                            ),
                            Text(
                              Fmt.money(l.total),
                              style: AppText.subtitle(size: 14),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        Text('Total', style: AppText.subtitle()),
                        const Spacer(),
                        Text(
                          Fmt.money(total),
                          style: AppText.stat(color: AppColors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.l),
              Row(
                children: [
                  const Icon(Icons.lock, color: AppColors.success, size: 18),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      b.payment.label,
                      style: AppText.subtitle(size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              if (simulated) ...[
                const GfCard(
                  color: AppColors.cream,
                  child: InfoRow(
                    Icons.science_outlined,
                    'Mode test : carte 4242 4242 4242 4242 acceptée ; 4000 0000 0000 0002 refusée. Aucune donnée de carte n\'est enregistrée.',
                  ),
                ),
                const SizedBox(height: Gap.m),
                TextFormField(
                  controller: _holder,
                  decoration: const InputDecoration(
                    labelText: 'Titulaire de la carte',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v ?? '').trim().length < 3
                      ? 'Nom du titulaire requis.'
                      : null,
                ),
                const SizedBox(height: Gap.m),
                TextFormField(
                  key: const Key('card_number'),
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                    LengthLimitingTextInputFormatter(23),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Numéro de carte',
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  validator: (v) => SimulatedPaymentGateway.luhnValid(v ?? '')
                      ? null
                      : 'Numéro de carte invalide.',
                ),
                const SizedBox(height: Gap.m),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expiry,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Expiration (MM/AA)',
                        ),
                        validator: (v) =>
                            SimulatedPaymentGateway.validateExpiry(
                              v ?? '',
                              b.now(),
                            ),
                      ),
                    ),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: TextFormField(
                        controller: _cvc,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'CVC'),
                        validator: (v) =>
                            RegExp(r'^\d{3,4}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'CVC invalide.',
                      ),
                    ),
                  ],
                ),
              ] else
                const GfCard(
                  color: AppColors.cream,
                  child: InfoRow(
                    Icons.open_in_browser,
                    'Vous allez être redirigé vers la page sécurisée Stripe (mode test). Montant converti en euros pour Stripe.',
                  ),
                ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _TotalBar(
        total: total,
        label: 'Payer ${Fmt.money(total)}',
        loading: _paying,
        onPressed: lines.isEmpty ? null : _pay,
      ),
    );
  }
}

/// Page de paiement Stripe Checkout ouverte dans un WebView.
/// Renvoie l'identifiant de session si l'URL de succès est atteinte.
class StripeCheckoutPage extends StatefulWidget {
  const StripeCheckoutPage({super.key, required this.session});
  final StripeSession session;

  @override
  State<StripeCheckoutPage> createState() => _StripeCheckoutPageState();
}

class _StripeCheckoutPageState extends State<StripeCheckoutPage> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onNavigationRequest: (req) {
            if (req.url.startsWith(StripeCheckoutGateway.successUrl)) {
              Navigator.pop(context, widget.session.id);
              return NavigationDecision.prevent;
            }
            if (req.url.startsWith(StripeCheckoutGateway.cancelUrl)) {
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.session.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé Stripe'),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  color: AppColors.gold,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// Confirmation animée de commande.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final o = Backend.I.orderService.byId(orderId)!;
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Gap.l),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: const CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.success,
                      child: Icon(
                        Icons.check,
                        color: AppColors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.l),
                  Text(
                    'Merci pour votre achat !',
                    key: const Key('order_confirmed'),
                    textAlign: TextAlign.center,
                    style: AppText.title(size: 24),
                  ),
                  const SizedBox(height: Gap.s),
                  Text(
                    'Commande ${o.number} · ${Fmt.money(o.total)}\nÀ retirer à l\'accueil dès qu\'elle est préparée.',
                    textAlign: TextAlign.center,
                    style: AppText.body(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: Gap.xl),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      Routes.order,
                      arguments: o.id,
                    ),
                    child: const Text('Voir le reçu'),
                  ),
                  const SizedBox(height: Gap.s),
                  OutlinedButton(
                    onPressed: () => Navigator.popUntil(
                      context,
                      (r) => r.settings.name == Routes.home || r.isFirst,
                    ),
                    child: const Text('Continuer mes achats'),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(child: Confetti(pieces: 60)),
        ],
      ),
    );
  }
}

Color orderStatusColor(OrderStatus s) => switch (s) {
  OrderStatus.paid => AppColors.navy,
  OrderStatus.prepared => AppColors.gold,
  OrderStatus.delivered => AppColors.success,
};

/// Historique des commandes de l'utilisateur.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final orders = b.orderService.mine();
        return Scaffold(
          appBar: AppBar(title: const Text('Mes commandes')),
          body: orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucune commande',
                  message: 'Vos achats en boutique apparaîtront ici.',
                )
              : ListView.separated(
                  padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.s),
                  itemBuilder: (_, i) => FadeSlideIn(
                    index: i,
                    child: OrderTile(order: orders[i]),
                  ),
                ),
        );
      },
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    this.showClient = false,
    this.trailing,
  });
  final ShopOrder order;
  final bool showClient;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final client = showClient ? Backend.I.users.byId(o.userId)?.fullName : null;
    return GfCard(
      onTap: () => Navigator.pushNamed(context, Routes.order, arguments: o.id),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.cream,
            child: Text('${o.itemCount}', style: AppText.subtitle(size: 14)),
          ),
          const SizedBox(width: Gap.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.number, style: AppText.subtitle(size: 15)),
                Text(
                  [?client, Fmt.dateTime(o.createdAt)].join(' · '),
                  style: AppText.label(size: 12),
                ),
                const SizedBox(height: 4),
                Pill(o.status.label, color: orderStatusColor(o.status)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.money(o.total),
                style: AppText.stat(color: AppColors.red, size: 16),
              ),
              ?trailing,
            ],
          ),
        ],
      ),
    );
  }
}

/// Reçu détaillé d'une commande.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final b = Backend.I;
    return ListenableBuilder(
      listenable: b.bus,
      builder: (context, _) {
        final o = b.orderService.byId(orderId);
        if (o == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Commande introuvable',
              message: '',
            ),
          );
        }
        final client = b.users.byId(o.userId);
        return Scaffold(
          appBar: AppBar(title: Text('Reçu ${o.number}')),
          body: ListView(
            padding: pagePadding(context, maxWidth: 900, bottom: Gap.m),
            children: [
              GfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/logo.png', width: 44),
                        const SizedBox(width: Gap.s),
                        Expanded(
                          child: Text(
                            'GymFlow Club',
                            style: AppText.title(size: 18),
                          ),
                        ),
                        Pill(o.status.label, color: orderStatusColor(o.status)),
                      ],
                    ),
                    const Divider(height: Gap.l),
                    InfoRow(Icons.tag, 'Commande ${o.number}'),
                    InfoRow(Icons.event, Fmt.dateTime(o.createdAt)),
                    InfoRow(Icons.person_outline, client?.fullName ?? ''),
                    InfoRow(
                      Icons.credit_card,
                      '${o.paymentMethod == 'stripe_test' ? 'Stripe (test)' : 'Paiement test simulé'} · réf. ${o.paymentRef}',
                    ),
                    const Divider(height: Gap.l),
                    for (final l in o.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${l.quantity} × ${l.name}',
                                style: AppText.body(size: 14),
                              ),
                            ),
                            Text(
                              Fmt.money(l.total),
                              style: AppText.subtitle(size: 14),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: Gap.l),
                    Row(
                      children: [
                        Text('Total TTC', style: AppText.subtitle()),
                        const Spacer(),
                        Text(
                          Fmt.money(o.total),
                          style: AppText.stat(color: AppColors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.m),
              _OrderTimeline(status: o.status),
              if (b.auth.currentUser!.isAdmin &&
                  o.status != OrderStatus.delivered) ...[
                const SizedBox(height: Gap.l),
                ElevatedButton.icon(
                  onPressed: () => runAction(
                    context,
                    () => b.orderService.advance(o.id),
                    success: 'Statut mis à jour, client prévenu.',
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    o.status == OrderStatus.paid
                        ? 'Marquer « préparée »'
                        : 'Marquer « remise »',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return GfCard(
      child: Row(
        children: [
          for (final s in OrderStatus.values) ...[
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: kAnim,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: s.index <= status.index
                          ? AppColors.success
                          : AppColors.divider,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: s.index <= status.index
                          ? AppColors.white
                          : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(s.label, style: AppText.label(size: 12)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
