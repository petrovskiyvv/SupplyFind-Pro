import 'package:flutter/material.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService();

  String name = '';
  String category = 'Dairy';
  String city = 'Москва';
  String inn = '';
  String description = '';
  String website = '';
  String email = '';
  String phone = '';
  String minOrder = '';
  String priceRange = '';
  bool hasCertificates = false;
  String deliveryTerms = '';

  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить поставщика')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Название компании'),
                validator: (value) => value!.isEmpty ? 'Введите название' : null,
                onSaved: (value) => name = value!,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Категория'),
                value: category,
                items: ['Dairy', 'Vegetables', 'Meat', 'Bakery'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Город'),
                value: city,
                items: ['Москва', 'Санкт-Петербург', 'Краснодар', 'Екатеринбург'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => city = v!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'ИНН'),
                onSaved: (value) => inn = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
                onSaved: (value) => description = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Сайт'),
                onSaved: (value) => website = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                onSaved: (value) => email = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Телефон'),
                onSaved: (value) => phone = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Мин. заказ'),
                onSaved: (value) => minOrder = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Ценовой диапазон'),
                onSaved: (value) => priceRange = value!,
              ),
              SwitchListTile(
                title: const Text('Есть сертификаты'),
                value: hasCertificates,
                onChanged: (v) => setState(() => hasCertificates = v),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Условия доставки'),
                onSaved: (value) => deliveryTerms = value!,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving ? const CircularProgressIndicator() : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);
      try {
        final newSupplier = Supplier(
          id: 0,
          name: name,
          description: description,
          website: website,
          contactEmail: email,
          contactPhone: phone,
          category: category,
          city: city,
          inn: inn,
          ogrn: '',
          legalAddress: '',
          minOrder: minOrder,
          priceRange: priceRange,
          hasCertificates: hasCertificates,
          isVerified: false,
          deliveryTerms: deliveryTerms,
          notes: '',
          rating: 0,
          isManual: true,
          isHidden: false,
          revenue: 'Н/Д',
          status: 'Действующая',
        );
        await apiService.createSupplier(newSupplier);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }
}
