import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class BillsScreen extends StatefulWidget {
  final List<dynamic> bills;
  final List<dynamic> users;
  final VoidCallback onUpdate;
  final VoidCallback onUsersUpdate;
  final Function(Map<String, dynamic>) onCollectionAdd;

  const BillsScreen({super.key, required this.bills, required this.users, required this.onUpdate, required this.onUsersUpdate, required this.onCollectionAdd});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String filter = "All";
  String search = "";
  final TextEditingController searchCtrl = TextEditingController();

  List<dynamic> get filteredBills => widget.bills.where((b) {
    bool matchFilter = filter == "All" || (filter == "Paid" && b['isPaid'] == true) || (filter == "Pending" && b['isPaid']!= true);
    bool matchSearch = search.isEmpty || b['name'].toString().toLowerCase().contains(search.toLowerCase());
    return matchFilter && matchSearch;
  }).toList();

  void extendUserExpiry(String phone) {
    for (var u in widget.users) {
      if (u['phone'] == phone) {
        try {
          DateTime currentExpiry = DateTime.parse(u['expiry']);
          DateTime now = DateTime.now();
          DateTime baseDate = currentExpiry.isBefore(now)? now : currentExpiry;
          DateTime newExpiry = baseDate.add(Duration(days: 30));
          u['expiry'] = newExpiry.toIso8601String().split('T')[0];
          u['isActive'] = true;
        } catch (e) {
          DateTime newExpiry = DateTime.now().add(Duration(days: 30));
          u['expiry'] = newExpiry.toIso8601String().split('T')[0];
          u['isActive'] = true;
        }
        break;
      }
    }
    widget.onUsersUpdate();
  }

  void showPaymentDialog(var bill, int realIndex) {
    TextEditingController paidCtrl = TextEditingController(text: bill['amount'].toString());
    showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("${bill['name']} - Fee Jama", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text("Total Bill: Rs. ${bill['amount']}", style: TextStyle(color: Colors.white70)),
        SizedBox(height: 12),
        TextField(controller: paidCtrl, keyboardType: TextInputType.number, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Kitni Fee Di? Rs.", labelStyle: TextStyle(color: Colors.white54), filled: true, fillColor: Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
      ]),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(c), child: Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: (){
          double total = double.tryParse(bill['amount'].toString())??0;
          double paid = double.tryParse(paidCtrl.text)??0;
          final now = DateTime.now();
          if(paid >= total) {
            // Collection me add karo
            widget.onCollectionAdd({"name": bill['name'], "phone": bill['phone'], "amount": paid, "package": bill['package'], "date": now.toIso8601String(), "billMonth": "${now.year}-${now.month}", "type": "full"});
            extendUserExpiry(bill['phone']);
            setState(()=> widget.bills.removeAt(realIndex));
            widget.onUpdate();
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${bill['name']} Paid! Collection me jama ho gaya"), backgroundColor: Colors.green));
          } else if(paid > 0) {
            double remaining = total - paid;
            widget.onCollectionAdd({"name": bill['name'], "phone": bill['phone'], "amount": paid, "package": bill['package'], "date": now.toIso8601String(), "billMonth": "${now.year}-${now.month}", "type": "partial"});
            setState((){
              widget.bills[realIndex]['amount'] = remaining;
              widget.bills[realIndex]['partialPaid'] = paid;
            });
            widget.onUpdate();
            Navigator.pop(c);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rs. $paid collection me, Rs. $remaining pending"), backgroundColor: Colors.orange));
            sendWhatsApp(bill['name'], bill['phone'], remaining, paidAmount: paid);
          }
        }, child: Text("Jama Karo"))
      ],
    ));
  }

  void sendWhatsApp(String name, String phone, dynamic amount, {double? paidAmount}) async {
    String msg = paidAmount!= null? "As-salamu Alaikum $name bhai, aapne Rs. $paidAmount jama karwaya, abhi Rs. $amount pending hai. Shukria - Bilal Internet" : "As-salamu Alaikum $name bhai, aapka bill Rs. $amount pending hai. Please jama karwa dein. Shukria - Bilal Internet";
    String num = phone.isEmpty? "923000000000" : phone;
    final uri = Uri.parse("https://wa.me/$num?text=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: const Color(0xFF121212), title: Text("Bills - ${filteredBills.length}", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: searchCtrl, style: const TextStyle(color: Colors.white), onChanged: (v)=>setState(()=>search=v), decoration: InputDecoration(hintText: "Search user...", hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: Colors.white38), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        Row(children: [const SizedBox(width: 12), _filterChip("All"), _filterChip("Pending")]),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: filteredBills.length, itemBuilder: (c, i) {
          var b = filteredBills[i];
          int realIndex = widget.bills.indexOf(b);
          bool isPartial = b['partialPaid']!= null;
          return Container(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: isPartial? Colors.orange.withOpacity(0.6) : Colors.transparent)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.pending, color: Colors.white)), title: Text(b['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(isPartial? "${b['package']??''} - Rs. ${b['amount']} Pending | Rs.${b['partialPaid']} jama" : "${b['package']??''} - Rs. ${b['amount']}", style: TextStyle(color: isPartial? Colors.orangeAccent : Colors.white54, fontSize: 11)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.message, color: Colors.green, size: 20), onPressed: ()=>sendWhatsApp(b['name'], b['phone']??"", b['amount'], paidAmount: b['partialPaid']?.toDouble())), IconButton(icon: const Icon(Icons.payments, color: Colors.greenAccent, size: 22), onPressed: ()=>showPaymentDialog(b, realIndex))]))); })),
      ]),
    );
  }
  Widget _filterChip(String label) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: filter == label, selectedColor: const Color(0xFF7C4DFF), backgroundColor: const Color(0xFF2A2A2A), labelStyle: const TextStyle(color: Colors.white), onSelected: (v)=>setState(()=>filter=label)));
}