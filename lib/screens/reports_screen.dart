import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../services/expense_service.dart';

class ReportsScreen extends StatefulWidget {
  final List<dynamic> bills;
  final List<dynamic> collections;
  final List<dynamic> users;
  const ReportsScreen({super.key, required this.bills, required this.collections, required this.users});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String selectedMonth = "${DateTime.now().year}-${DateTime.now().month}";
  List<dynamic> expenses = [];
  bool loadingExpense = false;

  List<String> get last12Months {
    List<String> m = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime d = DateTime(now.year, now.month - i, 1);
      m.add("${d.year}-${d.month}");
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    loadExpense();
  }

  Future<void> loadExpense() async {
    setState(() => loadingExpense = true);
    try {
      var snap = await ExpenseService.expenseCol.where('month', isEqualTo: selectedMonth).get();
      setState(() => expenses = snap.docs.map((d) => d.data()).toList());
    } catch (e) {
      setState(() => expenses = []);
    }
    setState(() => loadingExpense = false);
  }

  @override
  Widget build(BuildContext context) {
    int monthlyCollection = widget.collections
        .where((c) => c['billMonth'] == selectedMonth)
        .fold(0, (sum, c) => sum + FirebaseService.parseAmount(c['amount']));

    int monthlyPending = widget.bills
        .where((b) => b['billMonth'] == selectedMonth)
        .fold(0, (sum, b) => sum + FirebaseService.parseAmount(b['amount']));

    int monthlyExpense = expenses.fold(0, (sum, e) => sum + FirebaseService.parseAmount(e['amount']));
    int profit = monthlyCollection - monthlyExpense;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text("Reports & Profit", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: selectedMonth,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 11),
            underline: const SizedBox(),
            items: last12Months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => selectedMonth = v);
                loadExpense();
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _card("Wasooli", "Rs.$monthlyCollection", Colors.green, Icons.arrow_downward)),
              const SizedBox(width: 10),
              Expanded(child: _card("Kharcha", "Rs.$monthlyExpense", Colors.red, Icons.arrow_upward)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _card("Pending", "Rs.$monthlyPending", Colors.orange, Icons.pending)),
              const SizedBox(width: 10),
              Expanded(child: _card("PROFIT", "Rs.$profit", profit >= 0 ? Colors.greenAccent : Colors.redAccent, Icons.account_balance_wallet)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Monthly Wasooli Chart (6 Months)", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: List.generate(6, (i) {
                        DateTime d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
                        String mk = "${d.year}-${d.month}";
                        int col = widget.collections.where((c) => c['billMonth'] == mk).fold(0, (s, c) => s + FirebaseService.parseAmount(c['amount']));
                        return BarChartGroupData(
                          x: 5 - i,
                          barRods: [
                            BarChartRodData(toY: col.toDouble() / 1000, color: const Color(0xFF7C4DFF), width: 14, borderRadius: BorderRadius.circular(4)),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              int idx = v.toInt();
                              if (idx < 0 || idx > 5) return const SizedBox();
                              DateTime d = DateTime(DateTime.now().year, DateTime.now().month - (5 - idx), 1);
                              return Text("${d.month}", style: const TextStyle(color: Colors.white54, fontSize: 10));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (v, meta) => Text("${v.toInt()}k", style: const TextStyle(color: Colors.white54, fontSize: 9)),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("Is Month Ka Kharcha - $selectedMonth", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          if (loadingExpense) const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))),
          if (!loadingExpense && expenses.isEmpty)
            Padding(padding: const EdgeInsets.all(10), child: Text("Koi kharcha nahi is month", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11))),
          if (!loadingExpense)
            ...expenses.map((e) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.money_off, color: Colors.redAccent, size: 16),
                title: Text(e['title'].toString(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 11)),
                subtitle: Text(e['category'].toString(), style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9)),
                trailing: Text("Rs.${e['amount']}", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            )),
        ],
      ),
    );
  }

  Widget _card(String title, String value, Color col, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: col, size: 16), const SizedBox(width: 6), Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11))]),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}