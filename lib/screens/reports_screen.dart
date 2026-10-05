import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ReportsScreen extends StatefulWidget {
  final List<dynamic> bills;
  final List<dynamic> collections;
  final List<dynamic> users; // POINT 5 ke liye add
  const ReportsScreen({super.key, required this.bills, required this.collections, required this.users});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  Map<String, double> costPrice = {
    "10 MB": 680, "20 MB": 950, "30 MB": 1350, "50 MB": 1800,
    "10 Mbps": 680, "20 Mbps": 950, "30 Mbps": 1350, "50 Mbps": 1800,
    "5 Mbps": 500,
  };
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _controller.forward();
    loadCost();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> loadCost() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('pkg_cost');
    if (data!= null) {
      try{
        Map<String, dynamic> decoded = jsonDecode(data);
        setState(() { costPrice = decoded.map((k, v) => MapEntry(k, (v as num).toDouble())); });
      }catch(_){}
    }
  }
  Future<void> saveCost() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('pkg_cost', jsonEncode(costPrice));
  }
  void showCostEditDialog() {
    Map<String, TextEditingController> ctrls = {};
    costPrice.forEach((k, v) { ctrls[k] = TextEditingController(text: v.toString()); });
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Package Cost", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: costPrice.keys.map((pkg) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: ctrls[pkg], style: const TextStyle(color: Colors.white), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: pkg, labelStyle: const TextStyle(color: Colors.white54), border: const OutlineInputBorder())))).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () { setState(() { ctrls.forEach((key, ctrl) { costPrice[key] = double.tryParse(ctrl.text)?? costPrice[key]!; }); }); saveCost(); Navigator.pop(c); }, child: const Text("Save"))],
    ));
  }
  double getAmount(dynamic val){
    if(val == null) return 0;
    if(val is num) return val.toDouble();
    return double.tryParse(val.toString())?? 0;
  }
  bool isUserExpired(Map<String, dynamic> user){
    if(user['expiryDate']==null) return false;
    try{ return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(user['expiryDate'])); }catch(e){ return false; }
  }

  @override
  Widget build(BuildContext context) {
    double paidSale = 0;
    for (var b in widget.collections) { paidSale += getAmount(b['amount']); }

    // POINT 5: Total Sale sirf active users ke package rate se
    double totalSaleActive = 0;
    for(var u in widget.users){
      if(!isUserExpired(Map<String,dynamic>.from(u))){
        totalSaleActive += getAmount(u['amount']);
      }
    }

    double pendingSale = 0;
    for (var b in widget.bills) { if (b['isPaid']!= true) pendingSale += getAmount(b['amount']); }

    double totalCost = 0;
    Set<String> alreadyCosted = {};
    for (var b in widget.collections) {
      if(b['type'] == 'due_collection') continue; // POINT 2: Due ka kharcha dubara nahi
      String pkg = b['package']?.toString()?? "10 MB";
      String billMonth = b['billMonth']?.toString()?? "";
      String phone = b['phone']?.toString()?? "";
      String key = "${phone}_$billMonth";
      if (!alreadyCosted.contains(key)) {
        alreadyCosted.add(key);
        totalCost += costPrice[pkg]?? costPrice[ pkg.replaceAll(' MB',' Mbps') ]?? 680;
      }
    }
    double totalProfit = paidSale - totalCost; // POINT 4
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: Text("Monthly Reports", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.settings, color: Colors.white70), onPressed: showCostEditDialog)]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        _animatedRow(0, [_box("Total Sale (Active)", totalSaleActive, Colors.purple, 0), const SizedBox(width: 10), _box("Collected", paidSale, Colors.green, 100)]),
        const SizedBox(height: 10),
        _animatedRow(1, [_box("Pending Bills", pendingSale, Colors.orange, 200), const SizedBox(width: 10), _box("Kharcha", totalCost, Colors.redAccent, 300)]),
        const SizedBox(height: 15),
        _animatedRow(2, [Expanded(child: ScaleTransition(scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut), child: Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF4A00E0)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Text("Kul Khalis Bachat", style: TextStyle(color: Colors.white70)), const SizedBox(height: 5), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: totalProfit), duration: const Duration(milliseconds: 2000), curve: Curves.easeOutCubic, builder: (c, v, ch) => Text("Rs. ${v.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))), Text("${widget.collections.length} collections | $paidSale - $totalCost", style: const TextStyle(color: Colors.white70, fontSize: 11))]))))]),
      ])),
    );
  }
  Widget _animatedRow(int index, List<Widget> children) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) { double delay = index * 0.2; double animValue = ((_controller.value - delay).clamp(0.0, 1.0) / (1.0 - delay)).clamp(0.0, 1.0); return Opacity(opacity: animValue, child: Transform.translate(offset: Offset(0, 30 * (1 - animValue)), child: Row(children: children))); });
  }
  Widget _box(String title, double amount, Color c, int delay) {
    return Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.4))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.currency_rupee, color: c, size: 18), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(height: 4), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: amount), duration: Duration(milliseconds: 1500 + delay), curve: Curves.easeOutCubic, builder: (c, v, ch) => Text("Rs. ${v.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))])));
  }
}