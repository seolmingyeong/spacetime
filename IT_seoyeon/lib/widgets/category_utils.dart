import 'package:flutter/material.dart';

class CategoryInfo {
  final IconData icon;
  final Color color;
  CategoryInfo(this.icon, this.color);
}

CategoryInfo getCategoryInfo(String? type) {
  if (type == null) return CategoryInfo(Icons.place, Colors.grey);

  final t = type.toLowerCase();
  if (t.contains('restaurant') || t.contains('food') || t.contains('cafe') || t.contains('bakery')) {
    if (t.contains('cafe') || t.contains('bakery')) {
      return CategoryInfo(Icons.local_cafe, Colors.brown);
    }
    return CategoryInfo(Icons.restaurant, Colors.orange);
  }
  if (t.contains('hotel') || t.contains('hostel') || t.contains('apartment') || t.contains('guest_house') || t.contains('motel')) {
    return CategoryInfo(Icons.hotel, Colors.blue);
  }
  if (t.contains('attraction') || t.contains('museum') || t.contains('park') || t.contains('historic') || t.contains('tourism')) {
    return CategoryInfo(Icons.attractions, Colors.green);
  }
  if (t.contains('shop') || t.contains('mall') || t.contains('supermarket')) {
    return CategoryInfo(Icons.shopping_bag, Colors.pink);
  }
  if (t.contains('station') || t.contains('bus') || t.contains('airport') || t.contains('subway')) {
    return CategoryInfo(Icons.directions_bus, Colors.indigo);
  }

  return CategoryInfo(Icons.place, Colors.grey);
}
