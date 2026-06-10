import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/supplier.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';

class CompareSuppliersScreen extends StatefulWidget {
  final List<Supplier> suppliers;

  const CompareSuppliersScreen({super.key, required this.suppliers});

  @override
  State<CompareSuppliersScreen> createState() => _CompareSuppliersScreenState();
}

class _CompareSuppliersScreenState extends State<CompareSuppliersScreen> {
  final ApiService apiService = ApiService();
  String _aiSummary = '...';
  int? _winnerId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComparison();
  }

  Future<void> _loadComparison() async {
    try {
      final ids = widget.suppliers.map((s) => s.id).toList();
      final result = await apiService.getComparisonData(ids);
      setState(() {
        _aiSummary = result['explanation'];
        _winnerId = result['winner_id'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiSummary = 'Ошибка анализа данных';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('compare_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Column(
        children: [
          if (!_isLoading && _winnerId != null) _buildWinnerBanner(theme),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildAiReportCard(theme, loc),
                  _buildComparisonTable(theme, loc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinnerBanner(ThemeData theme) {
    final winner = widget.suppliers.firstWhere((s) => s.id == _winnerId);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondary,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            'РЕКОМЕНДАЦИЯ: ${winner.name}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ],
      ),
    );
  }

  Widget _buildAiReportCard(ThemeData theme, LocalizationService loc) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: theme.colorScheme.primary.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1))),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(loc.translate('ai_report_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Divider(height: 32),
              _isLoading ? const LinearProgressIndicator() : Text(_aiSummary, style: const TextStyle(fontSize: 15, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonTable(ThemeData theme, LocalizationService loc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 32,
        headingRowColor: MaterialStateProperty.all(theme.colorScheme.primary.withOpacity(0.05)),
        columns: [
          DataColumn(label: Text(loc.translate('parameter'), style: const TextStyle(fontWeight: FontWeight.bold))),
          ...widget.suppliers.map((s) => DataColumn(
            label: Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: s.id == _winnerId ? theme.colorScheme.secondary : null)),
          )),
        ],
        rows: [
          _buildScoredRow(loc.translate('rating'), (s) => s.rating, (v) => '$v/5', theme),
          _buildStatusRow(loc.translate('status'), (s) => s.status, theme),
          _buildRow(loc.translate('inn'), (s) => s.inn),
          _buildBooleanRow(loc.translate('certificates'), (s) => s.hasCertificates, theme),
          _buildRow(loc.translate('min_order'), (s) => s.minOrder),
          _buildRow(loc.translate('delivery'), (s) => s.deliveryTerms),
        ],
      ),
    );
  }

  DataRow _buildRow(String label, String Function(Supplier) getValue) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        ...widget.suppliers.map((s) => DataCell(Text(getValue(s)))),
      ],
    );
  }

  DataRow _buildScoredRow(String label, int Function(Supplier) getVal, String Function(int) format, ThemeData theme) {
    final values = widget.suppliers.map(getVal).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);

    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        ...widget.suppliers.map((s) {
          final v = getVal(s);
          Color? bgColor;
          if (v == maxV && maxV != minV) bgColor = Colors.green.withOpacity(0.2);
          if (v == minV && maxV != minV) bgColor = Colors.red.withOpacity(0.1);
          return DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: bgColor,
            child: Text(format(v), style: TextStyle(fontWeight: v == maxV ? FontWeight.bold : null)),
          ));
        }),
      ],
    );
  }

  DataRow _buildStatusRow(String label, String Function(Supplier) getVal, ThemeData theme) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        ...widget.suppliers.map((s) {
          final status = getVal(s);
          final isOk = status.contains('Действующая');
          return DataCell(Text(status, style: TextStyle(color: isOk ? Colors.green : Colors.red, fontWeight: FontWeight.bold)));
        }),
      ],
    );
  }

  DataRow _buildBooleanRow(String label, bool Function(Supplier) getVal, ThemeData theme) {
    return DataRow(
      cells: [
        DataCell(Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
        ...widget.suppliers.map((s) {
          final v = getVal(s);
          return DataCell(Icon(v ? Icons.check_circle : Icons.cancel, color: v ? Colors.green : Colors.red, size: 20));
        }),
      ],
    );
  }
}
