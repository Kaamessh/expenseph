import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/translations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _transactionType = 'spend'; // 'gain' or 'spend'
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      final txs = await apiService.getTransactions();
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load transactions: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _transactionType == 'gain' ? Colors.green : Colors.redAccent,
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _transactionType == 'gain' ? Colors.green : Colors.redAccent,
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid positive amount.')),
      );
      return;
    }

    final txDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      await apiService.createTransaction(
        type: _transactionType,
        amount: amount,
        description: _descriptionController.text.trim(),
        timestamp: txDateTime,
      );

      // Clean Form
      _amountController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _fetchData(); // Reload
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $e')),
      );
    }
  }

  Future<void> _deleteTransaction(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      await apiService.deleteTransaction(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
      _fetchData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete transaction: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compute total gain / spend
    double totalGain = 0;
    double totalSpend = 0;
    for (var tx in _transactions) {
      if (tx.type == 'gain') {
        totalGain += tx.amount;
      } else {
        totalSpend += tx.amount;
      }
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: Colors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Dual real-time display cards
              Row(
                children: [
                  Expanded(
                    child: _buildBalanceCard(
                      title: AppTranslations.t(context, 'total_earnings'),
                      amount: totalGain,
                      color: const Color(0xFF09BC8A),
                      icon: Icons.trending_up,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildBalanceCard(
                      title: AppTranslations.t(context, 'total_spendings'),
                      amount: totalSpend,
                      color: const Color(0xFFE05D5D),
                      icon: Icons.trending_down,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),
              
              // 2. Add Transaction Form Card
              Card(
                color: const Color(0xFF1E1E2E),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.t(context, 'record_transaction'),
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        
                        // Dual Type Selector Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeButton(
                                label: AppTranslations.t(context, 'gain'),
                                type: 'gain',
                                activeColor: const Color(0xFF09BC8A),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: _buildTypeButton(
                                label: AppTranslations.t(context, 'spend'),
                                type: 'spend',
                                activeColor: const Color(0xFFE05D5D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20.0),
                        
                        // Amount text field
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppTranslations.t(context, 'amount') + ' (₹)',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF12121F),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: _transactionType == 'gain' ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D),
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Amount is mandatory';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        
                        // Description text field
                        TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppTranslations.t(context, 'description'),
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.description, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF12121F),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: BorderSide(
                                color: _transactionType == 'gain' ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        
                        // Date and Time selectors
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF12121F),
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF12121F),
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedTime.format(context),
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24.0),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submitTransaction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _transactionType == 'gain' ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              elevation: 2,
                            ),
                            child: Text(
                              AppTranslations.t(context, 'record'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
              
              // 3. Transactions List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.t(context, 'recent_transactions'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _fetchData,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                  )
                ],
              ),
              const SizedBox(height: 12.0),
              
              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  : _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        )
                      : _transactions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  AppTranslations.t(context, 'no_transactions'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final tx = _transactions[index];
                                final isGain = tx.type == 'gain';
                                return Dismissible(
                                  key: Key(tx.id),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (dir) => _deleteTransaction(tx.id),
                                  child: Card(
                                    color: const Color(0xFF1E1E2E),
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: (isGain ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D)).withOpacity(0.15),
                                        child: Icon(
                                          isGain ? Icons.add : Icons.remove,
                                          color: isGain ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D),
                                        ),
                                      ),
                                      title: Text(
                                        tx.description.isNotEmpty ? tx.description : (isGain ? 'Received money' : 'Spent money'),
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        DateFormat('MMM dd, yyyy - hh:mm a').format(tx.timestamp),
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                      trailing: Text(
                                        '${isGain ? '+' : '-'}${currencyFormat.format(tx.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16.0,
                                          color: isGain ? const Color(0xFF09BC8A) : const Color(0xFFE05D5D),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return Card(
      color: const Color(0xFF1E1E2E),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14.0, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12.0),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormat.format(amount),
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required String type,
    required Color activeColor,
  }) {
    final isActive = _transactionType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _transactionType = type;
        });
      },
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.withOpacity(0.3),
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 15.0,
          ),
        ),
      ),
    );
  }
}
