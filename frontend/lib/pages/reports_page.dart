import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/translations.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _timeframe = 'monthly'; // 'weekly', 'monthly', 'yearly'
  Map<String, dynamic>? _reportsData;
  bool _isLoading = true;
  String? _errorMessage;

  // Visual filter configurations
  bool _showTransactions = true;
  bool _showInterest = true;
  bool get _showCombined => _showTransactions && _showInterest;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      final data = await apiService.getReports(_timeframe);
      setState(() {
        _reportsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load reports: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    
    final totalGain = _reportsData?['total_gain']?.toDouble() ?? 0.0;
    final totalSpend = _reportsData?['total_spend']?.toDouble() ?? 0.0;
    final totalInterest = _reportsData?['total_interest_accrued']?.toDouble() ?? 0.0;
    final List<dynamic> chartPoints = _reportsData?['chart_data'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: RefreshIndicator(
        onRefresh: _fetchReports,
        color: Colors.cyan,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeframe Filters
              Card(
                color: const Color(0xFF1E1E2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.t(context, 'monthly_summary'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      DropdownButton<String>(
                        value: _timeframe,
                        dropdownColor: const Color(0xFF1E1E2E),
                        style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _timeframe = val;
                            });
                            _fetchReports();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                  : _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Dual stats rows
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    title: AppTranslations.t(context, 'total_in'),
                                    value: currencyFormat.format(totalGain),
                                    color: const Color(0xFF09BC8A),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    title: AppTranslations.t(context, 'total_out'),
                                    value: currencyFormat.format(totalSpend),
                                    color: const Color(0xFFE05D5D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildStatCard(
                              title: AppTranslations.t(context, 'interest_accrued'),
                              value: currencyFormat.format(totalInterest),
                              color: Colors.amber,
                              isFullWidth: true,
                            ),
                            const SizedBox(height: 24),

                            // 2. Chart section
                            Text(
                              AppTranslations.t(context, 'financial_breakdown'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            _buildVisualChart(chartPoints),
                            const SizedBox(height: 24),

                            // 3. Detailed Table Breakdown
                            Text(
                              AppTranslations.t(context, 'transaction_history'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            _buildBreakdownTable(chartPoints),
                          ],
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required Color color, bool isFullWidth = false}) {
    return Card(
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
        child: Column(
          crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(color: color, fontSize: isFullWidth ? 26.0 : 18.0, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualChart(List<dynamic> chartPoints) {
    if (chartPoints.isEmpty) {
      return Card(
        color: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(AppTranslations.t(context, 'no_data_chart'), style: const TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    // Determine max value for chart scaling
    double maxVal = 100.0;
    for (var p in chartPoints) {
      final gain = p['gain']?.toDouble() ?? 0.0;
      final spend = p['spend']?.toDouble() ?? 0.0;
      final interest = p['interest']?.toDouble() ?? 0.0;
      if (gain > maxVal) maxVal = gain;
      if (spend > maxVal) maxVal = spend;
      if (interest > maxVal) maxVal = interest;
    }

    return Card(
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Filter checkboxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  value: _showTransactions,
                  activeColor: Colors.cyan,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _showTransactions = val;
                      });
                    }
                  },
                ),
                const Text('Cash Flow', style: TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(width: 12),
                Checkbox(
                  value: _showInterest,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _showInterest = val;
                      });
                    }
                  },
                ),
                const Text('Interest', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 16),

            // Bar Layout Chart
            Container(
              height: 180,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartPoints.map((p) {
                  final label = p['label'] as String;
                  final gain = p['gain']?.toDouble() ?? 0.0;
                  final spend = p['spend']?.toDouble() ?? 0.0;
                  final interest = p['interest']?.toDouble() ?? 0.0;

                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_showTransactions) ...[
                                _buildBar(gain, maxVal, const Color(0xFF09BC8A)),
                                const SizedBox(width: 2),
                                _buildBar(spend, maxVal, const Color(0xFFE05D5D)),
                              ],
                              if (_showInterest) ...[
                                const SizedBox(width: 2),
                                _buildBar(interest, maxVal, Colors.amber),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double val, double max, Color color) {
    final heightFactor = max > 0 ? (val / max).clamp(0.02, 1.0) : 0.02;
    return Expanded(
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4.0)),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownTable(List<dynamic> chartPoints) {
    if (chartPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Card(
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text('Period', style: TextStyle(color: Colors.grey[400]))),
            if (_showTransactions || _showCombined) ...[
              DataColumn(label: Text(AppTranslations.t(context, 'gain'), style: TextStyle(color: Colors.grey[400]))),
              DataColumn(label: Text(AppTranslations.t(context, 'spend'), style: TextStyle(color: Colors.grey[400]))),
            ],
            if (_showInterest || _showCombined)
              DataColumn(label: Text(AppTranslations.t(context, 'interest_payment_day'), style: TextStyle(color: Colors.grey[400]))),
          ],
          rows: chartPoints.reversed.map((p) {
            final label = p['label'] as String;
            final gain = p['gain']?.toDouble() ?? 0.0;
            final spend = p['spend']?.toDouble() ?? 0.0;
            final interest = p['interest']?.toDouble() ?? 0.0;

            return DataRow(
              cells: [
                DataCell(Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                if (_showTransactions || _showCombined) ...[
                  DataCell(Text(currencyFormat.format(gain), style: const TextStyle(color: Color(0xFF09BC8A)))),
                  DataCell(Text(currencyFormat.format(spend), style: const TextStyle(color: Color(0xFFE05D5D)))),
                ],
                if (_showInterest || _showCombined)
                  DataCell(Text(currencyFormat.format(interest), style: const TextStyle(color: Colors.amber))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
