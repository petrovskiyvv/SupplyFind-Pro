class Product {
  final int id;
  final String name;
  final String price;
  final String unit;

  Product({required this.id, required this.name, required this.price, required this.unit});

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price: json['price']?.toString() ?? '',
      unit: json['unit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'price': price, 'unit': unit};
  }
}

/// Represents a parsed price item from an uploaded price list file.
class PriceItem {
  final int id;
  final String productName;
  final double price;
  final String unit;
  final String? parsedAt;

  PriceItem({
    required this.id,
    required this.productName,
    required this.price,
    required this.unit,
    this.parsedAt,
  });

  factory PriceItem.fromJson(Map<String, dynamic> json) {
    return PriceItem(
      id: json['id'] ?? 0,
      productName: json['product_name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      unit: json['unit'] ?? 'кг',
      parsedAt: json['parsed_at'],
    );
  }
}

class Supplier {
  final int id;
  final String name;
  final String description;
  final String website;
  final String contactEmail;
  final String contactPhone;
  final String category;
  final String city;
  final String inn;
  final String ogrn;
  final String legalAddress;
  final String minOrder;
  final String priceRange;
  final bool hasCertificates;
  final bool isVerified;
  final String deliveryTerms;
  final String notes;
  final int rating;
  final bool isManual;
  final bool isHidden;
  final String revenue;
  final String status;
  final List<Product> products;
  final List<PriceItem> priceItems;
  final List<String> priceListUrls;

  Supplier({
    required this.id,
    required this.name,
    required this.description,
    required this.website,
    required this.contactEmail,
    required this.contactPhone,
    required this.category,
    required this.city,
    required this.inn,
    required this.ogrn,
    required this.legalAddress,
    required this.minOrder,
    required this.priceRange,
    required this.hasCertificates,
    required this.isVerified,
    required this.deliveryTerms,
    required this.notes,
    required this.rating,
    required this.isManual,
    required this.isHidden,
    required this.revenue,
    required this.status,
    this.products = const [],
    this.priceItems = const [],
    this.priceListUrls = const [],
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final productList = (json['products'] as List?)
            ?.map((i) => Product.fromJson(i))
            .toList() ??
        [];
    final priceItemList = (json['price_items'] as List?)
            ?.map((i) => PriceItem.fromJson(i))
            .toList() ??
        [];
    final priceUrls = (json['price_list_urls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Supplier(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      website: json['website'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      category: json['category'] ?? '',
      city: json['city'] ?? '',
      inn: json['inn'] ?? '',
      ogrn: json['ogrn'] ?? '',
      legalAddress: json['legal_address'] ?? '',
      minOrder: json['min_order'] ?? '',
      priceRange: json['price_range'] ?? '',
      hasCertificates: json['has_certificate'] ?? false,
      isVerified: json['is_verified'] ?? false,
      deliveryTerms: json['delivery_terms'] ?? '',
      notes: json['notes'] ?? '',
      rating: json['rating'] ?? 0,
      isManual: json['is_manual'] ?? false,
      isHidden: json['is_hidden'] ?? false,
      revenue: json['revenue'] ?? 'Н/Д',
      status: json['status'] ?? 'Действующая',
      products: productList,
      priceItems: priceItemList,
      priceListUrls: priceUrls,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'website': website,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'category': category,
      'city': city,
      'inn': inn,
      'ogrn': ogrn,
      'legal_address': legalAddress,
      'min_order': minOrder,
      'price_range': priceRange,
      'has_certificate': hasCertificates,
      'is_verified': isVerified,
      'delivery_terms': deliveryTerms,
      'notes': notes,
      'rating': rating,
      'is_manual': isManual,
      'is_hidden': isHidden,
      'revenue': revenue,
      'status': status,
      'products': products.map((p) => p.toJson()).toList(),
    };
  }
}
