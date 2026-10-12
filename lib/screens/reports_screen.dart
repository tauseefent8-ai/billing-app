import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
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
  Map<String, double> pkgCost = {
    "5 Mbps": 400,
    "10 Mbps": 680,
    "20 Mbps": 950,
    "30 Mbps": 1350,
    "50 Mbps": 1800,
    "100 Mbps": 2500,
  };

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
    loadPkgCost();
  }

  Future<void> loadPkgCost() async {
    try {
      final p = await SharedPreferences.getInstance();
      String? saved = p.getString('pkg_cost');
      if (saved!= null) {
        Map<String, dynamic> map = jsonDecode(saved);
        setState(() {
          pkgCost = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
        });
      }
    } catch (_) {}
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

  double _getPkgCost(String pkg) {
    if (pkgCost.containsKey(pkg)) return pkgCost[pkg]!;
    String normalized = pkg.replaceAll(" Mbps", " MB").replaceAll("Mbps", " MB");
    if (pkgCost.containsKey(normalized)) return pkgCost[normalized]!;
    for (var k in pkgCost.keys) {
      if (pkg.contains(k.split(" ")[0])) return pkgCost[k]!;
    }
    return 700;
  }

  @override
  Widget build(BuildContext context) {
    int monthlyCollection = widget.collections
        .where((c) => c['billMonth'] == selectedMonth)
        .fold(0, (sum, c) => sum + FirebaseService.parseAmount(c['amount']));

    int monthlyPendingFull = widget.bills
        .where((b) => b['billMonth'] == selectedMonth && b['isPaid']!= true && b['isPartial']!= true)
        .fold(0, (sum, b) => sum + FirebaseService.parseAmount(b['remainingDue']?? b['totalAmount']?? b['amount']));

    int monthlyPendingPartial = widget.bills
        .where((b) => b['billMonth'] == selectedMonth && b['isPartial'] == true)
        .fold(0, (sum, b) => sum + FirebaseService.parseAmount(b['remainingDue']?? 0));

    int monthlyPendingTotal = monthlyPendingFull + monthlyPendingPartial;

    int monthlyDuePart = widget.bills
        .where((b) => b['billMonth'] == selectedMonth)
        .fold(0, (sum, b) => sum + FirebaseService.parseAmount(b['dueAmount']?? 0));

    int monthlyMonthlyPart = widget.bills
        .where((b) => b['billMonth'] == selectedMonth)
        .fold(0, (sum, b) => sum + FirebaseService.parseAmount(b['amount']));

    int monthlyExpense = expenses.fold(0, (sum, e) => sum + FirebaseService.parseAmount(e['amount']));
    int profit = monthlyCollection - monthlyExpense;

    double totalPackageCost = 0;
    for (var u in widget.users) {
      String pkg = u['package']?.toString()?? '10 Mbps';
      totalPackageCost += _getPkgCost(pkg);
    }
    double profitAfterCost = monthlyCollection - monthlyExpense - totalPackageCost;

    double allTimePendingDue = 0;
    for (var u in widget.users) {
      allTimePendingDue += double.tryParse(u['pendingDue']?.toString()?? '0')?? 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: Text("Reports & Profit - Due System", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: selectedMonth,
            dropdownColor: const Color(0xFF1E1E1E),
            style: const TextStyle(color: Colors.white, fontSize: 11),
            underline: const SizedBox(),
            items: last12Months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) {
              if (v!= null) {
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
              Expanded(child: _card("Wasooli (Full+Partial)", "Rs.$monthlyCollection", Colors.green, Icons.arrow_downward)),
              const SizedBox(width: 10),
              Expanded(child: _card("Kharcha", "Rs.$monthlyExpense", Colors.red, Icons.arrow_upward)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _card("Pending Full", "Rs.$monthlyPendingFull", Colors.orange, Icons.pending)),
              const SizedBox(width: 10),
              Expanded(child: _card("Partial Baqaya", "Rs.$monthlyPendingPartial", Colors.amber, Icons.payments)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _card("Total Pending (Full+Partial)", "Rs.$monthlyPendingTotal", Colors.deepOrange, Icons.warning)),
              const SizedBox(width: 10),
              Expanded(child: _card("PROFIT (Wasooli-Kharcha)", "Rs.$profit", profit >= 0? Colors.greenAccent : Colors.redAccent, Icons.account_balance_wallet)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("STEP 9: Due Breakdown - $selectedMonth", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _rowDetail("Monthly Amount (Is month ka)", "Rs.$monthlyMonthlyPart"),
                _rowDetail("Previous Due (Pichla baqaya)", "Rs.$monthlyDuePart", color: Colors.orangeAccent),
                _rowDetail("Total Bills (Monthly+Due)", "Rs.${monthlyMonthlyPart + monthlyDuePart}", isBold: true),
                Divider(color: Colors.white12),
                _rowDetail("All Time User Pending Due", "Rs.${allTimePendingDue.toStringAsFixed(0)}", color: Colors.redAccent),
                SizedBox(height: 6),
                Text("Note: Agar user ne kam paise diye to baqaya Due me gaya, agle month Monthly+Due = Total banta hai. Full pay par next sirf Monthly.", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Profit After Package Cost", style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _rowDetail("Package Cost (All Users)", "Rs.${totalPackageCost.toStringAsFixed(0)}", color: Colors.white70),
                _rowDetail("Wasooli", "Rs.$monthlyCollection", color: Colors.greenAccent),
                _rowDetail("Kharcha", "Rs.$monthlyExpense", color: Colors.redAccent),
                Divider(color: Colors.white12),
                _rowDetail("Net Profit (Wasooli - Kharcha - PkgCost)", "Rs.${profitAfterCost.toStringAsFixed(0)}", isBold: true, color: profitAfterCost >= 0? Colors.greenAccent : Colors.redAccent),
                SizedBox(height: 4),
                Text("Package cost Settings > Package Cost me set hota hai. STEP 9 me profit sahi nikalta hai.", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 8)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Monthly Wasooli vs Baqaya Chart (6 Months)", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      barGroups: List.generate(6, (i) {
                        DateTime d = DateTime(DateTime.now().year, DateTime.now().month - i, 1);
                        String mk = "${d.year}-${d.month}";
                        int col = widget.collections.where((c) => c['billMonth'] == mk).fold(0, (s, c) => s + FirebaseService.parseAmount(c['amount']));
                        int pend = widget.bills.where((b) => b['billMonth'] == mk && b['isPaid']!= true).fold(0, (s, b) => s + FirebaseService.parseAmount(b['remainingDue']?? b['totalAmount']?? b['amount']));
                        return BarChartGroupData(
                          x: 5 - i,
                          barRods: [
                            BarChartRodData(toY: col.toDouble() / 1000, color: const Color(0xFF00C853), width: 8, borderRadius: BorderRadius.circular(4)),
                            BarChartRodData(toY: pend.toDouble() / 1000, color: const Color(0xFFFF1744), width: 8, borderRadius: BorderRadius.circular(4)),
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
                SizedBox(height: 8),
                Row(children: [
                  _legendDot(Colors.green, "Wasooli"),
                  SizedBox(width: 12),
                  _legendDot(Colors.redAccent, "Baqaya (Due+Monthly pending)"),
                ]),
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
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String t) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      SizedBox(width: 4),
      Text(t, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9)),
    ]);
  }

  Widget _rowDetail(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
          Text(value, style: GoogleFonts.poppins(color: color?? Colors.white, fontSize: isBold? 12 : 10, fontWeight: isBold? FontWeight.bold : FontWeight.w600)),
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
          Row(children: [Icon(icon, color: col, size: 16), const SizedBox(width: 6), Expanded(child: Text(title, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9), overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}