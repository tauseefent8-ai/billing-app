import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';

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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
        if (b['billMonth']!= null) return b['billMonth'].toString() == "${selectedMonth.year}-${selectedMonth.month}";
        if (b['date']!= null) { DateTime d = DateTime.parse(b['date'].toString()); return d.year == selectedMonth.year && d.month == selectedMonth.month; }
        return true;
      } catch (e) { return true; }
    }).toList();
  }

  List<dynamic> get filteredCollections {
    return widget.collections.where((c) {
      try {
        if (c['billMonth']!= null) return c['billMonth'].toString() == "${selectedMonth.year}-${selectedMonth.month}";
        if (c['date']!= null) { DateTime d = DateTime.parse(c['date'].toString()); return d.year == selectedMonth.year && d.month == selectedMonth.month; }
        return true;
      } catch (e) { return true; }
    }).toList();
  }

  bool _isActiveWithoutPayBill(Map<String, dynamic> b){
    String pt = (b['paymentType']?.toString()?? '').toLowerCase();
    String status = (b['status']?.toString()?? '').toLowerCase();
    if(pt.contains('without pay') || status.contains('without_pay') || status.contains('active_without')) return true;
    if(b['isPartial']==true) return false;
    if(b['isPaid']==true) return false;
    if(b['activeWithoutPay']==true || b['isActiveWithoutPay']==true) return true;
    return false;
  }

  bool _isBillCollection(Map<String, dynamic> c){
    if(c['billId']!=null) return true;
    String type = (c['type']?.toString()?? '').toLowerCase();
    if(type.contains('bill')) return true;
    if(c['dueAmount']!=null || c['monthlyAmount']!=null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    double totalCollectionFromBills = 0;
    List<dynamic> billCollectionsOnly = [];
    for(var c in filteredCollections){
      if(_isBillCollection(c)){
        totalCollectionFromBills += FirebaseService.parseAmount(c['amount']).toDouble();
        billCollectionsOnly.add(c);
      }
    }

    List<dynamic> activeWithoutPayBills = filteredBills.where((b) => _isActiveWithoutPayBill(b)).toList();
    double pendingActiveWithoutPayAmount = 0;
    for(var b in activeWithoutPayBills){
      pendingActiveWithoutPayAmount += FirebaseService.parseAmount(b['remainingDue']?? b['totalAmount']?? b['amount']).toDouble();
    }

    double totalPendingDue = 0;
    int dueUsersCount = 0;
    List<dynamic> dueUsersList = [];
    for(var u in widget.users){
      double due = double.tryParse(u['pendingDue']?.toString()?? '0')?? 0;
      if(due > 0){
        totalPendingDue += due;
        dueUsersCount++;
        dueUsersList.add(u);
      }
    }

    int activeCount = 0, disabledCount = 0, expiredCount = 0;
    DateTime now = DateTime.now();
    for(var u in widget.users){
      String status = u['status']?.toString()?? 'disabled';
      if(status=='active') activeCount++; else disabledCount++;
      if(u['expiryDate']!=null){
        try{ DateTime exp = DateTime.fromMillisecondsSinceEpoch(u['expiryDate']); if(now.isAfter(exp)) expiredCount++; }catch(_){}
      }
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
              _animatedItem(0, InkWell(onTap: () => _showUsersList(context, "Total Collection - Bill se - ${getMonthYearText(selectedMonth)}", billCollectionsOnly), borderRadius: BorderRadius.circular(20), child: _card("Total Collection - Bill se", totalCollectionFromBills, "${billCollectionsOnly.length} bills se collect • Sirf bill wali raqam (STEP 6)", Colors.green, Icons.check_circle))),
              const SizedBox(height: 12),
              _animatedItem(1, InkWell(onTap: () => _showUsersList(context, "Pending Bills - Active Without Pay - ${getMonthYearText(selectedMonth)}", activeWithoutPayBills), borderRadius: BorderRadius.circular(20), child: _card("Pending Bills - Active Without Pay", pendingActiveWithoutPayAmount, "${activeWithoutPayBills.length} Users • Jo Active Without Pay kiye (STEP 6)", Colors.orange, Icons.wifi_off))),
              const SizedBox(height: 12),
              _animatedItem(2, InkWell(onTap: () => _showUsersList(context, "Pending Due - Users ki Dues - All Time", dueUsersList), borderRadius: BorderRadius.circular(20), child: _card("Pending Due - Users ki Dues", totalPendingDue, "$dueUsersCount Users Ka Baqaya • Sirf users ki dues (STEP 6)", Colors.redAccent, Icons.warning_rounded))),
              const SizedBox(height: 16),
              Container(padding: EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(children: [
                Text("STEP 6 Dashboard Logic", style: GoogleFonts.poppins(color: Color(0xFF7C4DFF), fontSize: 11, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                _rowDetail("Total Collection (Bill se)", "Rs.${totalCollectionFromBills.toStringAsFixed(0)}", color: Colors.greenAccent),
                _rowDetail("Pending Bills (Active Without Pay)", "Rs.${pendingActiveWithoutPayAmount.toStringAsFixed(0)} - ${activeWithoutPayBills.length} bills", color: Colors.orangeAccent),
                _rowDetail("Pending Due (Users dues)", "Rs.${totalPendingDue.toStringAsFixed(0)} - $dueUsersCount users", color: Colors.redAccent),
              ])),
              const SizedBox(height: 20),
              _animatedItem(5, Align(alignment: Alignment.centerLeft, child: Text("Recent Bill Collections - ${getMonthYearText(selectedMonth)} (${billCollectionsOnly.length})", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 10),
              if (billCollectionsOnly.isEmpty) const Padding(padding: EdgeInsets.only(top: 20), child: Text("Is month bill se koi collection nahi", style: TextStyle(color: Colors.white38))),
              ...billCollectionsOnly.take(20).map((e) => _animatedItem(6, Padding(padding: const EdgeInsets.only(bottom: 8), child: ListTile(tileColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), title: Text(e['name']?? 'User', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), subtitle: Text("${e['type']?? 'bill'} • ${e['paymentType']?? ''} • ${e['date']!= null? e['date'].toString().split('T')[0] : ""} • Baqaya: Rs.${e['remaining']??0}", style: const TextStyle(color: Colors.white30, fontSize: 9)), trailing: Text("Rs. ${e['amount']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)))))).toList(),
              SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _animatedItem(int index, Widget child){
    return TweenAnimationBuilder(duration: Duration(milliseconds: 250 + (index * 50)), tween: Tween<double>(begin: 0, end: 1), curve: Curves.easeOut, builder: (context, double val, childWidget){ return Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 10 * (1-val)), child: childWidget)); }, child: child);
  }

  Widget _card(String title, double amount, String subtitle, Color color, IconData icon){
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: color, width: 4))),
      child: Row(children: [
        Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          SizedBox(height: 2),
          Text("Rs. ${amount.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9)),
        ])),
      ]),
    );
  }

  Widget _rowDetail(String label, String value, {Color? color}){
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)),
          Text(value, style: GoogleFonts.poppins(color: color?? Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showUsersList(BuildContext context, String title, List<dynamic> list){
    showModalBottomSheet(context: context, backgroundColor: Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))), builder: (c){
      return Container(padding: EdgeInsets.all(16), height: 500, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c,i){
          var e = list[i];
          return ListTile(title: Text(e['name']?.toString()?? '-', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)), subtitle: Text("${e['phone']?? ''} • Rs.${e['amount']?? e['pendingDue']?? ''} • ${e['type']?? e['package']?? ''}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)));
        })),
      ]));
    });
  }
}