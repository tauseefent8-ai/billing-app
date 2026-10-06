import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatefulWidget {
  final List<dynamic> bills;
  final List<dynamic> collections;
  final List<dynamic> users;
  const DashboardScreen({super.key, required this.bills, required this.collections, required this.users});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  DateTime selectedMonth = DateTime.now();
  final List<String> monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState(){
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250)); // POINT 2 FIX - pehle 1200 tha
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut); // POINT 2 FIX - pehle easeIn tha
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); // POINT 2 FIX - pehle 0.3 tha
    _controller.forward();
  }
  @override
  void dispose(){ _controller.dispose(); super.dispose(); }
  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget){ super.didUpdateWidget(oldWidget); _controller.forward(from: 0); }

  String getMonthYearText(DateTime d) => "${monthNames[d.month - 1]} ${d.year}";
  void changeMonth(int add) => setState(()=> selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + add, 1));
  Future<void> pickMonth() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: selectedMonth, firstDate: DateTime(2023), lastDate: DateTime(2030));
    if (picked!= null) setState(()=> selectedMonth = DateTime(picked.year, picked.month, 1));
  }

  List<dynamic> get filteredBills {
    return widget.bills.where((b) {
      try {
        if (b['date']!= null) { DateTime d = DateTime.parse(b['date'].toString()); return d.year == selectedMonth.year && d.month == selectedMonth.month; }
        if (b['billMonth']!= null) return b['billMonth'].toString() == "${selectedMonth.year}-${selectedMonth.month}";
        return true;
      } catch (e) { return true; }
    }).toList();
  }

  List<dynamic> get filteredCollections {
    return widget.collections.where((c) {
      try {
        if (c['date']!= null) { DateTime d = DateTime.parse(c['date'].toString()); return d.year == selectedMonth.year && d.month == selectedMonth.month; }
        if (c['billMonth']!= null) return c['billMonth'].toString() == "${selectedMonth.year}-${selectedMonth.month}";
        return true;
      } catch (e) { return true; }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    double pendingAmount = 0; int pendingUsers = 0;
    for (var b in filteredBills) { if (b['isPaid']!= true) { pendingAmount += (b['amount'] as num).toDouble(); pendingUsers++; } }
    double totalCollection = 0;
    for (var c in filteredCollections) { totalCollection += (c['amount'] as num).toDouble(); }
    int paidUsers = filteredCollections.length;
    double totalPendingDue = 0;
    int dueUsersCount = 0;
    for(var u in widget.users){
      double due = double.tryParse(u['pendingDue']?.toString()?? '0')?? 0;
      if(due > 0){ totalPendingDue += due; dueUsersCount++; }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(onPressed: () => changeMonth(-1), icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18)),
                  InkWell(onTap: pickMonth, child: Row(children: [const Icon(Icons.calendar_month, color: Color(0xFF7C4DFF), size: 20), const SizedBox(width: 8), Text(getMonthYearText(selectedMonth), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), const Icon(Icons.arrow_drop_down, color: Colors.white54)])),
                  IconButton(onPressed: () => changeMonth(1), icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18)),
                ]),
              ),
              const SizedBox(height: 16),
              _animatedItem(0, InkWell(onTap: () => _showUsersList(context, "Fee Jama - ${getMonthYearText(selectedMonth)}", filteredCollections), borderRadius: BorderRadius.circular(20), child: _card("Total Collection - ${monthNames[selectedMonth.month - 1]}", totalCollection, "$paidUsers dafa collection", Colors.green, Icons.check_circle))),
              const SizedBox(height: 12),
              _animatedItem(1, InkWell(onTap: () => _showUsersList(context, "Pending - ${getMonthYearText(selectedMonth)}", filteredBills.where((b) => b['isPaid']!= true).toList()), borderRadius: BorderRadius.circular(20), child: _card("Pending Bills - ${monthNames[selectedMonth.month - 1]}", pendingAmount, "$pendingUsers Users Pending", Colors.orange, Icons.pending))),
              const SizedBox(height: 12),
              _animatedItem(2, InkWell(onTap: () => _showUsersList(context, "Pending Due Users", widget.users.where((u) => (double.tryParse(u['pendingDue']?.toString()?? '0')??0) > 0).toList()), borderRadius: BorderRadius.circular(20), child: _card("Total Pending Due - All Time", totalPendingDue, "$dueUsersCount Users Ka Baqaya", Colors.redAccent, Icons.warning_rounded))),
              const SizedBox(height: 12),
              _animatedItem(3, Row(children: [Expanded(child: _smallCard("Total Pending", "${filteredBills.length}", Icons.people, 0)), const SizedBox(width: 12), Expanded(child: _smallCard("Collected Times", "$paidUsers", Icons.wifi, 150))])),
              const SizedBox(height: 20),
              _animatedItem(4, Align(alignment: Alignment.centerLeft, child: Text("Recent Collections - ${getMonthYearText(selectedMonth)} (${filteredCollections.length})", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 10),
              if (filteredCollections.isEmpty && filteredBills.isEmpty) const Padding(padding: EdgeInsets.only(top: 20), child: Text("Is month ka koi data nahi", style: TextStyle(color: Colors.white38))),
              ...filteredCollections.map((e) => _animatedItem(5, Padding(padding: const EdgeInsets.only(bottom: 8), child: ListTile(tileColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), title: Text(e['name']?? 'User', style: const TextStyle(color: Colors.white, fontSize: 14)), subtitle: Text("${e['type']?? 'bill'} - ${e['date']!= null? e['date'].toString().split('T')[0] : ""} | ${e['package']?? ''}", style: const TextStyle(color: Colors.white30, fontSize: 10)), trailing: Text("Rs. ${e['amount']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))))).toList(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _animatedItem(int index, Widget child){
    return TweenAnimationBuilder(duration: Duration(milliseconds: 250 + (index * 50)), tween: Tween<double>(begin: 0, end: 1), curve: Curves.easeOut, builder: (context, double val, childWidget){ return Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 10 * (1-val)), child: childWidget)); }, child: child);
  }

  void _showUsersList(BuildContext context, String title, List<dynamic> list) {
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (c) => Container(padding: const EdgeInsets.all(16), height: 400, child: Column(children: [Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const Divider(color: Colors.white24), Expanded(child: list.isEmpty? const Center(child: Text("Koi user nahi", style: TextStyle(color: Colors.white54))) : ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFF7C4DFF), child: Text(list[i]['name'].toString().isNotEmpty? list[i]['name'][0].toString() : "U")), title: Text(list[i]['name']?? '-', style: const TextStyle(color: Colors.white)), subtitle: Text("Rs. ${list[i]['amount']?? list[i]['pendingDue']?? ''}", style: const TextStyle(color: Colors.white54)), trailing: Icon(list[i]['isPaid']==false? Icons.close : Icons.check, color: list[i]['isPaid']==false? Colors.red : Colors.green))))])));
  }

  Widget _card(String title, double amount, String subtitle, Color color, IconData icon) => Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border(left: BorderSide(color: color, width: 5)), boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))]), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)), const SizedBox(width: 15), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)), AnimatedCount(amount: amount), Text(subtitle, style: TextStyle(color: color, fontSize: 11))]), const Spacer(), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38)]));
  Widget _smallCard(String t, String v, IconData ic, int delay) => TweenAnimationBuilder<double>(tween: Tween(begin: 0.8, end: 1), duration: Duration(milliseconds: 250), curve: Curves.easeOut, builder: (c, val, child) => Transform.scale(scale: val, child: child), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15)), child: Column(children: [Icon(ic, color: Colors.white70), const SizedBox(height: 8), Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text(t, style: const TextStyle(color: Colors.white54, fontSize: 11))])));

}

class AnimatedCount extends StatelessWidget {
  final double amount;
  const AnimatedCount({super.key, required this.amount});
  @override
  Widget build(BuildContext context){
    return TweenAnimationBuilder<double>(tween: Tween<double>(begin: 0, end: amount), duration: const Duration(milliseconds: 250), curve: Curves.easeOut, builder: (context, value, child){ return Text("Rs. ${value.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)); });
  }
}