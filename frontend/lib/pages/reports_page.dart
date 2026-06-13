import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _timeframe = 'monthly'; // 'monthly' or 'yearly'
  
  // Toggles corresponding to Filter Views
  bool _showTransactions = true; // Filter View A: Regular transactions (Gain & Spend)
  bool _showInterest = true;     // Filter View B: Interest Liabilities exclusively
  bool _showCombined = true;     // Filter View C: Combined overlay match (both)

  Map<String, dynamic>? _reportsData;
  bool _isLoading = true;
  String? _errorMessage;

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
        _errorMessage = 'Could not load reports. Please check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    
    // Parse response statistics
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
              // 1. Timeframe Selection
              _buildTimeframeSelector(),
              const SizedBox(height: 20.0),

              // 2. Interactive Filter View Toggles (Checkbox System)
              _buildFilterTogglesCard(),
              const SizedBox(height: 20.0),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
                  : _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3. Dynamic Summary Stats Row
                            Row(
                              children: [
                                if (_showTransactions || _showCombined) ...[
                                  Expanded(
                                    child: _buildStatTile(
                                      title: 'Gain Stream',
                                      val: currencyFormat.format(totalGain),
                                      color: const Color(0xFF09BC8A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildStatTile(
                                      title: 'Spend Stream',
                                      val: currencyFormat.format(totalSpend),
                                      color: const Color(0xFFE05D5D),
                                    ),
                                  ),
                                ],
                                if ((_showInterest || _showCombined) && (_showTransactions || _showCombined))
                                  const SizedBox(width: 8),
                                if (_showInterest || _showCombined)
                                  Expanded(
                                    child: _buildStatTile(
                                      title: 'Interest Accruals',
                                      val: currencyFormat.format(totalInterest),
                                      color: Colors.amber,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24.0),

                            // 4. Custom Responsive Visual Chart
                            const Text(
                              'Visual Analytics',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            _buildCustomChart(chartPoints),
                            const SizedBox(height: 24.0),

                            // 5. Data Details breakdown table
                            const Text(
                              'Historical Breakdown',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildTimeframeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(4.0),
      child: Row(
        children: [
          Expanded(
            child: _buildTimeframeTab('Monthly Report', 'monthly'),
          ),
          Expanded(
            child: _buildTimeframeTab('Yearly Report', 'yearly'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeTab(String label, String value) {
    final isSelected = _timeframe == value;
    return InkWell(
      onTap: () {
        setState(() {
          _timeframe = value;
        });
        _fetchReports();
      },
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2C2C3E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.cyanAccent : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTogglesCard() {
    return Card(
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Views',
              style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8.0),
            
            // Checkbox for View A
            CheckboxListTile(
              value: _showTransactions,
              activeColor: Colors.cyan,
              title: const Text('View A: Transactions Exclusively', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Shows regular earn (gain) & spending transactions', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onChanged: (val) {
                setState(() {
                  _showTransactions = val ?? false;
                  // If both A and B are active, C is implied
                  if (_showTransactions && _showInterest) {
                    _showCombined = true;
                  } else {
                    _showCombined = false;
                  }
                });
              },
            ),
            
            // Checkbox for View B
            CheckboxListTile(
              value: _showInterest,
              activeColor: Colors.cyan,
              title: const Text('View B: Interest Exclusively', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Shows accumulated interest liabilities from debts page', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onChanged: (val) {
                setState(() {
                  _showInterest = val ?? false;
                  if (_showTransactions && _showInterest) {
                    _showCombined = true;
                  } else {
                    _showCombined = false;
                  }
                });
              },
            ),

            // Checkbox for View C
            CheckboxListTile(
              value: _showCombined,
              activeColor: Colors.cyan,
              title: const Text('View C: Combined Match Overlay', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Displays transactions and interest side-by-side simultaneously', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onChanged: (val) {
                setState(() {
                  _showCombined = val ?? false;
                  if (_showCombined) {
                    _showTransactions = true;
                    _showInterest = true;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({required String title, required String val, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChart(List<dynamic> chartPoints) {
    if (chartPoints.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(16)),
        child: const Text('No history to chart', style: TextStyle(color: Colors.grey)),
      );
    }

    // Determine maximum value to scale heights correctly
    double maxVal = 0.1;
    for (var p in chartPoints) {
      final gain = p['gain']?.toDouble() ?? 0.0;
      final spend = p['spend']?.toDouble() ?? 0.0;
      final interest = p['interest']?.toDouble() ?? 0.0;
      
      if (_showTransactions || _showCombined) {
        if (gain > maxVal) maxVal = gain;
        if (spend > maxVal) maxVal = spend;
      }
      if (_showInterest || _showCombined) {
        if (interest > maxVal) maxVal = interest;
      }
    }

    // Render bars
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chartPoints.map((point) {
          final label = point['label'] as String;
          final gain = point['gain']?.toDouble() ?? 0.0;
          final spend = point['spend']?.toDouble() ?? 0.0;
          final interest = point['interest']?.toDouble() ?? 0.0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Gain Bar (Emerald)
                      if (_showTransactions || _showCombined)
                        _buildBarSegment(gain, maxVal, const Color(0xFF09BC8A)),
                      const SizedBox(width: 2),
                      
                      // Spend Bar (Crimson)
                      if (_showTransactions || _showCombined)
                        _buildBarSegment(spend, maxVal, const Color(0xFFE05D5D)),
                      const SizedBox(width: 2),
                      
                      // Interest Bar (Amber)
                      if (_showInterest || _showCombined)
                        _buildBarSegment(interest, maxVal, Colors.amber),
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  label.split(' ')[0], // Short label, e.g. "Jun" from "Jun 2026"
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarSegment(double val, double maxVal, Color color) {
    final heightFactor = (val / maxVal).clamp(0.02, 1.0);
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

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Card(
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            const DataColumn(label: Text('Period', style: TextStyle(color: Colors.grey))),
            if (_showTransactions || _showCombined) ...[
              const DataColumn(label: Text('Gain', style: TextStyle(color: Colors.grey))),
              const DataColumn(label: Text('Spend', style: TextStyle(color: Colors.grey))),
            ],
            if (_showInterest || _showCombined)
              const DataColumn(label: Text('Interest Liability', style: TextStyle(color: Colors.grey))),
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
