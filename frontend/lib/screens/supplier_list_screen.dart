import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../services/theme_service.dart';
import '../widgets/dino_game.dart';
import 'supplier_detail_screen.dart';
import 'add_supplier_screen.dart';
import 'compare_suppliers_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final ApiService apiService = ApiService();
  late Future<List<Supplier>> futureSuppliers;
  String? selectedCategory;
  String? selectedCity;
  
  bool onlyVerified = false;
  bool hasCertificates = false;
  bool _smtpConfigured = false;
  
  final Set<int> selectedSupplierIds = {};
  List<Supplier> currentSuppliers = [];

  final List<String> categories = ['All', 'Dairy', 'Vegetables', 'Meat', 'Bakery'];
  final List<String> cities = ['All', 'Москва', 'Санкт-Петербург', 'Краснодар', 'Екатеринбург'];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _checkSmtpStatus();
  }

  Future<void> _checkSmtpStatus() async {
    try {
      final status = await apiService.getSmtpStatus();
      if (mounted) setState(() => _smtpConfigured = status['configured'] == true);
    } catch (_) {}
  }

  void _showSmtpDialog(ThemeData theme) {
    final hostCtrl = TextEditingController(text: 'smtp.gmail.com');
    final portCtrl = TextEditingController(text: '587');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final fromCtrl = TextEditingController();
    bool obscurePass = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.mail_lock_outlined, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Настройка SMTP почты'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Настройте SMTP один раз для отправки запросов КП поставщикам напрямую из приложения.',
                            style: TextStyle(fontSize: 13, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: hostCtrl,
                          decoration: InputDecoration(
                            labelText: 'SMTP сервер',
                            hintText: 'smtp.gmail.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            prefixIcon: const Icon(Icons.dns_outlined, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Порт',
                            hintText: '587',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: InputDecoration(
                      labelText: 'Email-адрес отправителя',
                      hintText: 'your@gmail.com',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Пароль / App Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromCtrl,
                    decoration: InputDecoration(
                      labelText: 'Имя отправителя (необязательно)',
                      hintText: 'ООО Жизнь Март — Отдел снабжения',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💡 Подсказка:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('Gmail: включите двухфакторную аутентификацию → Безопасность → Пароли приложений', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 2),
                        Text('Яндекс: Настройки → Безопасность → Пароли приложений', style: TextStyle(fontSize: 12)),
                        SizedBox(height: 2),
                        Text('Mail.ru: smtp.mail.ru, порт 587', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Сохранить и применить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Укажите email и пароль'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await apiService.configureSmtp(
                    smtpHost: hostCtrl.text.trim(),
                    smtpPort: int.tryParse(portCtrl.text.trim()) ?? 587,
                    smtpUser: userCtrl.text.trim(),
                    smtpPassword: passCtrl.text,
                    smtpFrom: fromCtrl.text.trim().isEmpty ? null : fromCtrl.text.trim(),
                  );
                  if (mounted) {
                    setState(() => _smtpConfigured = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('SMTP настроен — письма будут отправляться реально'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _loadSuppliers() {
    setState(() {
      futureSuppliers = apiService.getSuppliers(
        category: selectedCategory,
        city: selectedCity,
        verifiedOnly: onlyVerified,
        hasCertificate: hasCertificates,
      );
    });
  }

  Future<void> _runDiscovery(bool isBatch) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    if (!isBatch && (selectedCategory == null || selectedCategory == 'All' || selectedCity == null || selectedCity == 'All')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('select_filters'))));
      return;
    }

    _showAdvancedLoadingOverlay(isBatch);

    try {
      if (isBatch) {
        await apiService.discoverAllSuppliers();
      } else {
        await apiService.discoverSuppliers(selectedCategory!, selectedCity!);
      }
      if (mounted) Navigator.pop(context);
      _loadSuppliers();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.translate('error')}: $e')));
      }
    }
  }

  void _showAdvancedLoadingOverlay(bool isBatch) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final List<String> messages = [
      "Запрашиваю базы данных...",
      "Парсю сайты поставщиков...",
      "Верифицирую ИНН...",
      "Формирую рейтинг..."
    ];
    int messageIndex = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Timer.periodic(const Duration(seconds: 2), (t) {
            if (!mounted) { t.cancel(); return; }
            setDialogState(() { messageIndex = (messageIndex + 1) % messages.length; });
          });

          return Dialog.fullscreen(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const DinoGame(),
                const SizedBox(height: 40),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  messages[messageIndex],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(loc.translate('discovery_in_progress'), style: const TextStyle(color: Colors.grey)),
                const Spacer(),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(loc, theme),
            _buildAdvancedSearchBar(loc, theme),
            Expanded(
              child: FutureBuilder<List<Supplier>>(
                future: futureSuppliers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(loc.translate('no_suppliers')));

                  currentSuppliers = snapshot.data!;
                  var filtered = currentSuppliers.where((s) {
                    if (onlyVerified && !s.isVerified) return false;
                    if (hasCertificates && !s.hasCertificates) return false;
                    return true;
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildSupplierCard(filtered[index], loc, theme),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddSupplierScreen())).then((_) => _loadSuppliers()),
        backgroundColor: theme.colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCustomAppBar(LocalizationService loc, ThemeData theme) {
    final themeService = Provider.of<ThemeService>(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Text(
            'SupplyFind',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            'Найдено: ${currentSuppliers.length}',
            style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7), fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          // SMTP configuration button
          Tooltip(
            message: _smtpConfigured
                ? 'SMTP настроен — нажмите для изменения'
                : 'Настроить SMTP для отправки писем поставщикам',
            child: InkWell(
              onTap: () => _showSmtpDialog(theme),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _smtpConfigured
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _smtpConfigured ? Colors.green : Colors.orange,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _smtpConfigured
                          ? Icons.mark_email_read_outlined
                          : Icons.mail_lock_outlined,
                      size: 16,
                      color: _smtpConfigured ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _smtpConfigured ? 'SMTP ✓' : 'Настроить SMTP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _smtpConfigured ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(themeService.themeMode == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
            onPressed: themeService.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.language_outlined),
            onPressed: loc.toggleLocale,
          ),
          if (selectedSupplierIds.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final selected = currentSuppliers.where((s) => selectedSupplierIds.contains(s.id)).toList();
                Navigator.push(context, MaterialPageRoute(builder: (context) => CompareSuppliersScreen(suppliers: selected)));
              },
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: Text(loc.translate('compare')),
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.secondary, foregroundColor: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSearchBar(LocalizationService loc, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: loc.translate('category'),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  value: selectedCategory ?? 'All',
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(_translateCategory(c, loc)))).toList(),
                  onChanged: (v) => setState(() => selectedCategory = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _runDiscovery(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.search),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _runDiscovery(true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.travel_explore),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: loc.translate('city'),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  value: selectedCity ?? 'All',
                  items: cities.map((c) => DropdownMenuItem(value: c, child: Text(_translateCity(c, loc)))).toList(),
                  onChanged: (v) => setState(() => selectedCity = v),
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterChip("Верифицированные", onlyVerified, (v) => setState(() => onlyVerified = v), theme),
              const SizedBox(width: 8),
              _buildFilterChip("Сертификаты", hasCertificates, (v) => setState(() => hasCertificates = v), theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool active, Function(bool) onToggle, ThemeData theme) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : theme.colorScheme.primary)),
      selected: active,
      onSelected: onToggle,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSupplierCard(Supplier s, LocalizationService loc, ThemeData theme) {
    final bool isSelected = selectedSupplierIds.contains(s.id);
    int score = s.rating * 20; 
    Color scoreColor = score >= 70 ? Colors.green : (score >= 40 ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SupplierDetailScreen(supplier: s)),
        ).then((_) => _loadSuppliers()),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: scoreColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (s.isVerified) const Icon(Icons.verified, color: Colors.blue, size: 20),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withOpacity(0.1)),
                            child: Text('$score', style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold)),
                          ),
                          Checkbox(
                            value: isSelected,
                            onChanged: (v) => setState(() => v! ? selectedSupplierIds.add(s.id) : selectedSupplierIds.remove(s.id)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildContactRow(Icons.phone_outlined, s.contactPhone, theme),
                      _buildContactRow(Icons.email_outlined, s.contactEmail, theme),
                      _buildContactRow(Icons.language_outlined, s.website, theme),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              if (s.hasCertificates) _buildTag("ГОСТ/ISO", theme.colorScheme.secondary),
                              _buildTag(s.city, theme.colorScheme.primary),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility_off_outlined, size: 20, color: Colors.grey),
                            tooltip: loc.translate('hide'),
                            onPressed: () async {
                              final supplierId = s.id;
                              try {
                                await apiService.hideSupplier(supplierId);
                                _loadSuppliers();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(loc.translate('supplier_hidden')),
                                      duration: const Duration(seconds: 5),
                                      action: SnackBarAction(
                                        label: loc.translate('undo'),
                                        onPressed: () async {
                                          await apiService.unhideSupplier(supplierId);
                                          _loadSuppliers();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.translate('error')}: $e')));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(child: Text(text.isEmpty ? "N/A" : text, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _translateCategory(String category, LocalizationService loc) {
    switch (category) {
      case 'All': return loc.translate('all');
      case 'Dairy': return loc.translate('cat_dairy');
      case 'Vegetables': return loc.translate('cat_vegetables');
      case 'Meat': return loc.translate('cat_meat');
      case 'Bakery': return loc.translate('cat_bakery');
      default: return category;
    }
  }

  String _translateCity(String city, LocalizationService loc) {
    switch (city) {
      case 'All': return loc.translate('city_all');
      case 'Москва': return loc.translate('city_moscow');
      case 'Санкт-Петербург': return loc.translate('city_spb');
      case 'Краснодар': return loc.translate('city_krasnodar');
      case 'Екатеринбург': return loc.translate('city_ekb');
      default: return city;
    }
  }
}
