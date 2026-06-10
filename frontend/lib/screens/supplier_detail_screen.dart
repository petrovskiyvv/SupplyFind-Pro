import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class SupplierDetailScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  final ApiService apiService = ApiService();
  late Supplier _currentSupplier;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _smtpConfigured = false;

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _innController;
  late TextEditingController _webController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _minOrderController;
  late TextEditingController _deliveryController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _currentSupplier = widget.supplier;
    _initControllers();
    _checkSmtpStatus();
  }

  Future<void> _checkSmtpStatus() async {
    try {
      final status = await apiService.getSmtpStatus();
      if (mounted) {
        setState(() => _smtpConfigured = status['configured'] == true);
      }
    } catch (_) {}
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _currentSupplier.name);
    _descController = TextEditingController(text: _currentSupplier.description);
    _innController = TextEditingController(text: _currentSupplier.inn);
    _webController = TextEditingController(text: _currentSupplier.website);
    _emailController = TextEditingController(text: _currentSupplier.contactEmail);
    _phoneController = TextEditingController(text: _currentSupplier.contactPhone);
    _minOrderController = TextEditingController(text: _currentSupplier.minOrder);
    _deliveryController = TextEditingController(text: _currentSupplier.deliveryTerms);
    _notesController = TextEditingController(text: _currentSupplier.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _innController.dispose();
    _webController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _minOrderController.dispose();
    _deliveryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    setState(() => _isSaving = true);
    try {
      final updateData = {
        'name': _nameController.text,
        'description': _descController.text,
        'inn': _innController.text,
        'website': _webController.text,
        'contact_email': _emailController.text,
        'contact_phone': _phoneController.text,
        'min_order': _minOrderController.text,
        'delivery_terms': _deliveryController.text,
        'notes': _notesController.text,
      };
      final updated = await apiService.updateSupplier(_currentSupplier.id, updateData);
      setState(() {
        _currentSupplier = updated;
        _isEditing = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.translate('save_success'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.translate('error')}: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _pickAndUploadPriceList(ThemeData theme, LocalizationService loc) {
    final html.FileUploadInputElement input = html.FileUploadInputElement()..accept = '.pdf,.xlsx,.xls';
    input.click();
    input.onChange.listen((event) {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((loadEvent) async {
          final bytes = reader.result as List<int>;
          
          setState(() {
            _isSaving = true;
          });
          
          try {
            final res = await apiService.uploadPriceList(_currentSupplier.id, file.name, bytes);
            
            // Reload supplier details to get new products
            final updatedSupplier = await apiService.getSuppliers(
              category: _currentSupplier.category,
              city: _currentSupplier.city,
            ).then((list) => list.firstWhere((s) => s.id == _currentSupplier.id));
            
            setState(() {
              _currentSupplier = updatedSupplier;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Успешно загружено: ${res['message']}"))
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Ошибка загрузки: $e"))
              );
            }
          } finally {
            if (mounted) {
              setState(() {
                _isSaving = false;
              });
            }
          }
        });
      }
    });
  }

  /// Show SMTP configuration dialog
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
              Icon(Icons.mail_lock_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Настройка SMTP'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Укажите параметры SMTP-сервера для отправки писем поставщикам.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: hostCtrl,
                          decoration: const InputDecoration(
                            labelText: 'SMTP хост',
                            hintText: 'smtp.gmail.com',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Порт',
                            hintText: '587',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Логин / Email отправителя',
                      hintText: 'your@gmail.com',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Пароль / App Password',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fromCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Имя отправителя (необязательно)',
                      hintText: 'ООО Жизнь Март — Отдел снабжения',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Для Gmail используйте App Password. Для Яндекс — пароль приложения из настроек безопасности.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
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
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Укажите логин и пароль SMTP'), backgroundColor: Colors.red),
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
                      const SnackBar(
                        content: Text('SMTP настроен успешно ✓'),
                        backgroundColor: Colors.green,
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

  /// Show RFQ dialog with file attachment support
  void _showRFQDialog(LocalizationService loc, ThemeData theme) {
    final String email = _currentSupplier.contactEmail.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ошибка: у поставщика не указан адрес электронной почты."),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    final textController = TextEditingController();
    String selectedRequestType = 'Коммерческое предложение';
    Uint8List? attachmentBytes;
    String? attachmentName;

    final requestTypes = [
      'Коммерческое предложение',
      'Прайс-лист на текущий период',
      'Ассортимент продукции',
      'Условия сотрудничества',
      'Сертификаты качества',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _currentSupplier.name.isNotEmpty ? _currentSupplier.name[0] : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentSupplier.name, style: const TextStyle(fontSize: 15)),
                        Text(
                          email,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  // SMTP status badge
                  Tooltip(
                    message: _smtpConfigured ? 'SMTP настроен' : 'SMTP не настроен — письмо будет симулировано',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _smtpConfigured ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _smtpConfigured ? Colors.green : Colors.orange,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _smtpConfigured ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                            size: 12,
                            color: _smtpConfigured ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _smtpConfigured ? 'SMTP' : 'Без SMTP',
                            style: TextStyle(
                              fontSize: 11,
                              color: _smtpConfigured ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Request type selector
                  const Text('Тип запроса:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: requestTypes.map((type) {
                      final isSelected = selectedRequestType == type;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedRequestType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : null,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Text area
                  const Text('Дополнительные требования / спецификация:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: "Например: Нам требуется 500 кг картофеля и 200 кг моркови еженедельно с доставкой до склада на ул. Ленина, 5...",
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // File attachment section
                  const Text('Прикрепить файл (необязательно):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (attachmentName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attachmentName!,
                              style: const TextStyle(fontSize: 13, color: Colors.green),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setDialogState(() {
                              attachmentBytes = null;
                              attachmentName = null;
                            }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file_outlined, size: 16),
                      label: const Text('Выбрать файл (PDF, Excel, Word)', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () {
                        final input = html.FileUploadInputElement()
                          ..accept = '.pdf,.xlsx,.xls,.doc,.docx';
                        input.click();
                        input.onChange.listen((e) {
                          final files = input.files;
                          if (files != null && files.isNotEmpty) {
                            final file = files[0];
                            final reader = html.FileReader();
                            reader.readAsArrayBuffer(file);
                            reader.onLoadEnd.listen((_) {
                              final result = reader.result as List<int>;
                              setDialogState(() {
                                attachmentBytes = Uint8List.fromList(result);
                                attachmentName = file.name;
                              });
                            });
                          }
                        });
                      },
                    ),
                  ],
                  if (!_smtpConfigured) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showSmtpDialog(theme);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SMTP не настроен. Нажмите, чтобы настроить — иначе письмо будет записано без отправки.',
                                style: TextStyle(fontSize: 12, color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Отправить письмо'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final fullText = '[$selectedRequestType]\n\n${textController.text.trim()}';
                Navigator.pop(ctx);
                setState(() => _isSaving = true);
                try {
                  final res = await apiService.sendRFQWithFile(
                    supplierId: _currentSupplier.id,
                    requestText: fullText,
                    fileBytes: attachmentBytes,
                    fileName: attachmentName,
                  );
                  if (mounted) {
                    final bool simulated = res['simulated'] == true;
                    final bool hasAttachment = res['has_attachment'] == true;
                    final String attachMsg = hasAttachment ? ' + вложение' : '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(simulated
                            ? "Запрос записан (SMTP не настроен): ${res['recipient']}$attachMsg"
                            : "✓ Письмо отправлено на: ${res['recipient']}$attachMsg"),
                        backgroundColor: simulated ? Colors.orange : Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Ошибка отправки: $e"), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final theme = Theme.of(context);
    
    final hasEmail = _currentSupplier.contactEmail.trim().isNotEmpty;

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentSupplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            // SMTP configuration button
            Tooltip(
              message: _smtpConfigured ? 'SMTP настроен' : 'Настроить SMTP для отправки писем',
              child: IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.mail_lock_outlined),
                    if (!_smtpConfigured)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (_smtpConfigured)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _showSmtpDialog(theme),
              ),
            ),
            IconButton(
              icon: Icon(_isEditing ? Icons.close_outlined : Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernHeader(theme),
              const SizedBox(height: 32),
              if (_isEditing) _buildEditForm(loc, theme) else _buildB2BInfoGrid(loc, theme),
              const SizedBox(height: 24),
              
              if (!_isEditing) ...[
                // Price list upload section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: theme.colorScheme.primary, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Загрузка прайс-листа", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                "Поддерживаются файлы PDF и Excel (XLSX). Товары будут автоматически распарсены и добавлены в каталог.",
                                style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _pickAndUploadPriceList(theme, loc),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text("Выбрать файл"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                _buildProductCatalog(theme),
                
                const SizedBox(height: 32),
                Text(loc.translate('notes'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1))),
                  child: Text(_currentSupplier.notes.isEmpty ? '...' : _currentSupplier.notes, style: const TextStyle(height: 1.5)),
                ),
                const SizedBox(height: 24),

                // Email send button — only shows if supplier has email
                if (hasEmail) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.3)),
                    ),
                    color: theme.colorScheme.secondary.withOpacity(0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.forward_to_inbox_outlined, color: theme.colorScheme.secondary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Запрос коммерческого предложения',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Отправить письмо с запросом прайс-листа, ассортимента или КП. Можно прикрепить файл.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 12, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentSupplier.contactEmail,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      _smtpConfigured ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                                      size: 12,
                                      color: _smtpConfigured ? Colors.green : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _smtpConfigured ? 'SMTP настроен' : 'SMTP не настроен',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _smtpConfigured ? Colors.green : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _isSaving ? null : () => _showRFQDialog(loc, theme),
                            icon: const Icon(Icons.send_outlined, size: 18),
                            label: const Text('Написать', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Legacy full-width RFQ button (fallback if no email displayed above)
                if (!hasEmail)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('НЕЛЬЗЯ ОТПРАВИТЬ — НЕТ EMAIL'),
                    ),
                  ),
              ],
              if (_isEditing)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                    label: Text(loc.translate('save').toUpperCase()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(16)),
          child: Center(child: Text(_currentSupplier.name.isNotEmpty ? _currentSupplier.name[0] : '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_currentSupplier.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (_currentSupplier.isVerified) const Icon(Icons.verified, color: Colors.blue, size: 24),
                ],
              ),
              Text('${_currentSupplier.category} • ${_currentSupplier.city}', style: TextStyle(fontSize: 16, color: theme.colorScheme.primary.withOpacity(0.6))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 18, color: i < _currentSupplier.rating ? theme.colorScheme.secondary : Colors.grey.withOpacity(0.3))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildB2BInfoGrid(LocalizationService loc, ThemeData theme) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildInfoCard(loc.translate('inn'), _currentSupplier.inn, Icons.fingerprint, theme, onTap: () => _launchURL('https://focus.kontur.ru/search?query=${_currentSupplier.inn}')),
        _buildInfoCard(loc.translate('website'), _currentSupplier.website, Icons.language, theme, onTap: () => _launchURL(_currentSupplier.website)),
        _buildInfoCard(loc.translate('email'), _currentSupplier.contactEmail, Icons.email_outlined, theme, onTap: () => _launchURL('mailto:${_currentSupplier.contactEmail}')),
        _buildInfoCard(loc.translate('phone'), _currentSupplier.contactPhone, Icons.phone_outlined, theme, onTap: () => _launchURL('tel:${_currentSupplier.contactPhone}')),
        _buildInfoCard(loc.translate('min_order'), _currentSupplier.minOrder, Icons.shopping_basket_outlined, theme),
        _buildInfoCard(loc.translate('delivery'), _currentSupplier.deliveryTerms, Icons.local_shipping_outlined, theme),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, ThemeData theme, {VoidCallback? onTap}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1))),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
            const SizedBox(height: 8),
            Text(value.isEmpty ? 'N/A' : value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCatalog(ThemeData theme) {
    if (_currentSupplier.products.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Text(
          "Каталог товаров / Прайс-лист",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _currentSupplier.products.length,
          itemBuilder: (context, index) {
            final product = _currentSupplier.products[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  "${product.price} руб. / ${product.unit}",
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditForm(LocalizationService loc, ThemeData theme) {
    return Column(
      children: [
        _buildB2BTextField(_nameController, "Название организации", theme),
        _buildB2BTextField(_innController, loc.translate('inn'), theme),
        _buildB2BTextField(_webController, loc.translate('website'), theme),
        _buildB2BTextField(_emailController, loc.translate('email'), theme),
        _buildB2BTextField(_phoneController, loc.translate('phone'), theme),
        _buildB2BTextField(_minOrderController, loc.translate('min_order'), theme),
        _buildB2BTextField(_deliveryController, loc.translate('delivery'), theme),
        _buildB2BTextField(_notesController, loc.translate('notes'), theme, maxLines: 4),
      ],
    );
  }

  Widget _buildB2BTextField(TextEditingController controller, String label, ThemeData theme, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: theme.colorScheme.primary.withOpacity(0.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
          filled: true,
          fillColor: theme.colorScheme.surface,
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'http://$urlString');
    try { if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) { debugPrint('Could not launch $urlString'); }
  }
}
