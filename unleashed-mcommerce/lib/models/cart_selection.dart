import 'cart_item.dart';

/// Tracks which cart lines are checked for checkout.
///
/// The set stores *deselected* line ids, so lines added after the cart screen
/// first opened are selected by default and removed lines never leave a
/// dangling selection behind.
class CartSelection {
  final Set<String> _deselectedIds = <String>{};

  bool isSelected(CartItem item) => !_deselectedIds.contains(item.id);

  void setSelected(CartItem item, bool selected) {
    if (selected) {
      _deselectedIds.remove(item.id);
    } else {
      _deselectedIds.add(item.id);
    }
  }

  void selectAll(Iterable<CartItem> items) {
    for (final item in items) {
      _deselectedIds.remove(item.id);
    }
  }

  void clearAll(Iterable<CartItem> items) {
    for (final item in items) {
      _deselectedIds.add(item.id);
    }
  }

  void forget(String itemId) => _deselectedIds.remove(itemId);

  void reset() => _deselectedIds.clear();

  List<CartItem> selected(Iterable<CartItem> items) =>
      items.where(isSelected).toList(growable: false);

  int quantity(Iterable<CartItem> items) =>
      selected(items).fold<int>(0, (total, item) => total + item.quantity);

  int subtotal(Iterable<CartItem> items) =>
      selected(items).fold<int>(0, (total, item) => total + item.subtotal);
}
