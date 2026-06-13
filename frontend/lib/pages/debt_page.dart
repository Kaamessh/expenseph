import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/debt.dart';
import '../services/api_service.dart';

class DebtPage extends StatefulWidget {
  const DebtPage({super.key});

  @override
  State<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends State<DebtPage> {
  List<Debt> _debts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDebts();
  }

  Future<void> _fetchDebts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      final data = await apiService.getDebts();
      setState(() {
        _debts = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load debts: ${e.toString().replaceAll('Exception:', '').trim()}';
      });
    }
  }

  void _showDebtFormModal({Debt? existingDebt}) {
    final isEditing = existingDebt != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existingDebt?.personName ?? '');
    final amountController = TextEditingController(text: existingDebt?.originalAmount.toString() ?? '');
    final rateController = TextEditingController(text: existingDebt?.interestRate.toString() ?? '');
    
    DateTime selectedDate = existingDebt?.createdAt ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20.0,
                right: 20.0,
                top: 20.0,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEditing ? 'Edit Debt Record' : 'Log New Debt',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.grey),
                          )
                        ],
                      ),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 12),
                      
                      // Person's Name Input
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _getInputDecoration(
                          label: 'Person\'s Name',
                          icon: Icons.person,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Person name is mandatory';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Debt Amount Input
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _getInputDecoration(
                          label: 'Debt Amount (\$)',
                          icon: Icons.attach_money,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Amount is mandatory';
                          if (double.tryParse(val) == null || double.parse(val) <= 0) {
                            return 'Enter a positive numeric amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Interest Rate Input
                      TextFormField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: _getInputDecoration(
                          label: 'Annual Interest Rate (%)',
                          icon: Icons.percent,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Interest rate is mandatory';
                          if (double.tryParse(val) == null || double.parse(val) < 0) {
                            return 'Enter a non-negative percentage';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Date Selector for interest calculation origin
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2101),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Colors.amber,
                                    onPrimary: Colors.black,
                                    surface: Color(0xFF1E1E2E),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12121F),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.date_range, color: Colors.amber, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accrual Start: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              const Text('Change', style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            final name = nameController.text.trim();
                            final amount = double.parse(amountController.text);
                            final rate = double.parse(rateController.text);
                            
                            Navigator.pop(context); // Close sheet
                            setState(() {
                              _isLoading = true;
                            });
                            
                            try {
                              final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
                              if (isEditing) {
                                await apiService.updateDebt(
                                  id: existingDebt.id,
                                  personName: name,
                                  originalAmount: amount,
                                  interestRate: rate,
                                  createdAt: selectedDate,
                                );
                              } else {
                                await apiService.createDebt(
                                  personName: name,
                                  originalAmount: amount,
                                  interestRate: rate,
                                  createdAt: selectedDate,
                                );
                              }
                              _fetchDebts();
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing ? 'Debt record updated' : 'New debt logged successfully',
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                    backgroundColor: Colors.amber,
                                  ),
                              );
                            } catch (e) {
                              setState(() {
                                _isLoading = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                          child: Text(
                            isEditing ? 'Update Record' : 'Save Debt',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDebt(String id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = ApiService(Provider.of<ApiConfig>(context, listen: false));
      await apiService.deleteDebt(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debt profile deleted')),
      );
      _fetchDebts();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  InputDecoration _getInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF12121F),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: Colors.amber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total outstanding debts per person
    final Map<String, double> personOutstandingMap = {};
    final Map<String, double> personInterestMap = {};
    double grandTotal = 0;

    for (var debt in _debts) {
      personOutstandingMap[debt.personName] = (personOutstandingMap[debt.personName] ?? 0) + debt.totalDebt;
      personInterestMap[debt.personName] = (personInterestMap[debt.personName] ?? 0) + debt.accruedInterest;
      grandTotal += debt.totalDebt;
    }

    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFF121218),
      body: RefreshIndicator(
        onRefresh: _fetchDebts,
        color: Colors.amber,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grand outstanding debt card
              Card(
                color: const Color(0xFF1E1E2E),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance, color: Colors.amber, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Total Outstanding Liabilities',
                        style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(grandTotal),
                        style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Aggregated Outstanding Debt per Person
              const Text(
                'Liabilities per Person',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              
              personOutstandingMap.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16.0),
                      alignment: Alignment.center,
                      child: const Text('No liabilities calculated.', style: TextStyle(color: Colors.grey)),
                    )
                  : SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: personOutstandingMap.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final person = personOutstandingMap.keys.elementAt(index);
                          final total = personOutstandingMap[person]!;
                          final interest = personInterestMap[person]!;
                          return Container(
                            width: 160,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E2E),
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  person,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  currencyFormat.format(total),
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Incl. \$${interest.toStringAsFixed(2)} int.',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 24),

              // Active Debts Details List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detailed Debt Records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _fetchDebts,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                  : _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                        )
                      : _debts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No active debt profiles logged.', style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _debts.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final debt = _debts[index];
                                return Card(
                                  color: const Color(0xFF1E1E2E),
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    debt.personName,
                                                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Interest Rate: ${debt.interestRate}% annual',
                                                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                                                  onPressed: () => _showDebtFormModal(existingDebt: debt),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                  onPressed: () => _deleteDebt(debt.id),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Divider(color: Colors.grey, height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildDebtSubValue('Original Principal', currencyFormat.format(debt.originalAmount)),
                                            _buildDebtSubValue('Interest Accrued', currencyFormat.format(debt.accruedInterest), isHighlight: true),
                                            _buildDebtSubValue('Total Outstanding', currencyFormat.format(debt.totalDebt), color: Colors.amber),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Accrued since: ${DateFormat('yyyy-MM-dd').format(debt.createdAt)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDebtFormModal(),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDebtSubValue(String title, String val, {Color? color, bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: color ?? (isHighlight ? Colors.amber[300] : Colors.white),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
