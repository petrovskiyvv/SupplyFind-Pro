import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/supplier.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL', 
    defaultValue: 'http://localhost:8000'
  );

  Future<Supplier> getSupplierById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/suppliers/$id'));
    if (response.statusCode == 200) {
      return Supplier.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load supplier $id');
  }

  Future<List<Supplier>> getSuppliers({String? category, String? city, bool verifiedOnly = false, bool hasCertificate = false}) async {
    final queryParameters = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'All') {
      queryParameters['category'] = category;
    }
    if (city != null && city.isNotEmpty && city != 'All') {
      queryParameters['city'] = city;
    }

    if (category != null && category != 'All' && city != null && city != 'All') {
        final uri = Uri.parse('$baseUrl/api/suppliers/search').replace(queryParameters: {
            'category': category,
            'city': city,
            'verified_only': verifiedOnly.toString(),
            'has_certificate': hasCertificate.toString(),
        });
        final response = await http.post(uri);
        if (response.statusCode == 200) {
          List<dynamic> body = jsonDecode(response.body);
          return body.map((dynamic item) => Supplier.fromJson(item)).toList();
        } else {
          throw Exception('Failed to load suppliers');
        }
    } else {
        final uri = Uri.parse('$baseUrl/suppliers').replace(queryParameters: queryParameters);
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          List<dynamic> body = jsonDecode(response.body);
          return body.map((dynamic item) => Supplier.fromJson(item)).toList();
        } else {
          throw Exception('Failed to load suppliers');
        }
    }
  }

  Future<List<Supplier>> discoverSuppliers(String category, String city) async {
    final uri = Uri.parse('$baseUrl/api/suppliers/search').replace(queryParameters: {
        'category': category,
        'city': city,
    });
    final response = await http.post(uri);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Supplier.fromJson(item)).toList();
    } else {
      throw Exception('Failed to discover suppliers');
    }
  }

  Future<List<Supplier>> discoverAllSuppliers() async {
    final response = await http.post(
      Uri.parse('$baseUrl/suppliers/discover/all'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Supplier.fromJson(item)).toList();
    } else {
      throw Exception('Failed to discover all suppliers');
    }
  }

  Future<Supplier> createSupplier(Supplier supplier) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suppliers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(supplier.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Supplier.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create supplier');
    }
  }

  Future<void> hideSupplier(int id) async {
    await http.post(Uri.parse('$baseUrl/suppliers/$id/hide'));
  }

  Future<void> unhideSupplier(int id) async {
    await http.post(Uri.parse('$baseUrl/suppliers/$id/unhide'));
  }

  Future<Map<String, dynamic>> getComparisonData(List<int> ids) async {
    final response = await http.post(
      Uri.parse('$baseUrl/suppliers/compare'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(ids),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to compare suppliers');
  }

  Future<Supplier> updateSupplier(int id, Map<String, dynamic> updateData) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/suppliers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updateData),
    );

    if (response.statusCode == 200) {
      return Supplier.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update supplier');
    }
  }

  Future<Map<String, dynamic>> uploadPriceList(int supplierId, String filename, List<int> bytes) async {
    final uri = Uri.parse('$baseUrl/api/suppliers/$supplierId/upload-price');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      )
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final detail = jsonDecode(response.body)['detail'] ?? 'Failed to upload price list';
      throw Exception(detail);
    }
  }

  Future<Map<String, dynamic>> sendRFQ(int supplierId, String requestText, {String? emailSentTo}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rfq/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'supplier_id': supplierId,
        'request_text': requestText,
        if (emailSentTo != null) 'email_sent_to': emailSentTo,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final detail = jsonDecode(response.body)['detail'] ?? 'Failed to send RFQ';
      throw Exception(detail);
    }
  }

  /// Send an RFQ email with an optional file attachment.
  Future<Map<String, dynamic>> sendRFQWithFile({
    required int supplierId,
    required String requestText,
    String? emailSentTo,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final uri = Uri.parse('$baseUrl/api/rfq/send-with-file');
    final request = http.MultipartRequest('POST', uri);
    request.fields['supplier_id'] = supplierId.toString();
    request.fields['request_text'] = requestText;
    if (emailSentTo != null) {
      request.fields['email_sent_to'] = emailSentTo;
    }

    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final detail = jsonDecode(response.body)['detail'] ?? 'Failed to send RFQ';
      throw Exception(detail);
    }
  }

  Future<List<dynamic>> getRFQHistory(int supplierId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/rfq/history?supplier_id=$supplierId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get RFQ history');
    }
  }

  /// Get SMTP configuration status.
  Future<Map<String, dynamic>> getSmtpStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/api/smtp/status'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get SMTP status');
  }

  /// Configure SMTP server settings.
  Future<Map<String, dynamic>> configureSmtp({
    required String smtpHost,
    required int smtpPort,
    required String smtpUser,
    required String smtpPassword,
    String? smtpFrom,
  }) async {
    final uri = Uri.parse('$baseUrl/api/smtp/configure').replace(queryParameters: {
      'smtp_host': smtpHost,
      'smtp_port': smtpPort.toString(),
      'smtp_user': smtpUser,
      'smtp_password': smtpPassword,
      if (smtpFrom != null) 'smtp_from': smtpFrom,
    });
    final response = await http.post(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final detail = jsonDecode(response.body)['detail'] ?? 'Failed to configure SMTP';
    throw Exception(detail);
  }

  Future<Map<String, dynamic>> getDiscoveryStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/api/discovery/status'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get discovery status');
  }
}
