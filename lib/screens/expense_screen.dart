import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/expense_service.dart';
import '../services/firebase_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});
  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  List<dynamic> expenses = [];
  bool loading = true;
  String selectedMonth = "${DateTime.now().year}-${DateTime.now().month}";

  @override
  void initState(){ super.initState(); loadExpenses(); }

  Future<void> loadExpenses() async {
    setState(()=> loading=true);
    try{
      var snap = await ExpenseService.expenseCol.orderBy('timestamp', descending: true).get();
      setState(()=> expenses = snap.docs.map((d)=> d.data()).toList());
    }catch(e){}
    setState(()=> loading=false);
  }

  List<dynamic> get filtered => expenses.where((e)=> e['month']==selectedMonth).toList();
  int get totalExpense => filtered.fold(0, (sum, e)=> sum + FirebaseService.parseAmount(e['amount']));
  List<String> get last12Months { List<String> m=[]; DateTime now=DateTime.now(); for(int i=0;i<12;i++){ DateTime d=DateTime(now.year, now.month-i, 1); m.add("${d.year}-${d.month}"); } return m; }

  void addExpenseDialog(){
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();
    String category = "General";
    showDialog(context: context, builder: (ctx)=> AlertDialog(
      backgroundColor: Color(0xFF1E1E1E),
      title: Text("Kharcha Add Karo", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Kis Cheez Ka Kharcha?", filled: true, fillColor: Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        SizedBox(height: 10),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Amount Rs.", filled: true, fillColor: Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        SizedBox(height: 10),
        DropdownButtonFormField<String>(value: category, dropdownColor: Color(0xFF2A2A2A), style: TextStyle(color: Colors.white), decoration: InputDecoration(filled: true, fillColor: Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), items: ["General","Tower","Light Bill","Staff","Wire","Device","Other"].map((c)=> DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v){ if(v!=null) category=v; }),
      ]),
      actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text("Cancel")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF7C4DFF)), onPressed: () async { int amt = int.tryParse(amountCtrl.text)??0; if(titleCtrl.text.isEmpty|| amt<=0) return; await ExpenseService.addExpense(title: titleCtrl.text.trim(), amount: amt, category: category); Navigator.pop(ctx); loadExpenses(); if(mounted){ ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kharcha Rs.$amt add ho gaya"), backgroundColor: Colors.green, duration: Duration(seconds: 5))); } }, child: Text("Add"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(backgroundColor: Color(0xFF121212), title: Text("Kharcha - Rs.$totalExpense", style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)), actions: [DropdownButton<String>(value: selectedMonth, dropdownColor: Color(0xFF1E1E1E), style: TextStyle(color: Colors.white, fontSize: 11), underline: SizedBox(), items: last12Months.map((m)=> DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v){ if(v!=null) setState(()=> selectedMonth=v); }), IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: addExpenseDialog)]),
      body: loading? Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF))) : filtered.isEmpty? Center(child: Text("Is month koi kharcha nahi\nMonth: $selectedMonth", textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white54))) : ListView.builder(itemCount: filtered.length, itemBuilder: (c,i){ var e=filtered[i]; return Container(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.money_off, color: Colors.white, size: 18)), title: Text(e['title'].toString(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), subtitle: Text("${e['category']} - ${e['date'].toString().substring(0,10)}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("Rs.${e['amount']}", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)), IconButton(icon: Icon(Icons.delete, color: Colors.white38, size: 18), onPressed: () async { await ExpenseService.deleteExpense(e['id']); loadExpenses(); })]))); }),
      floatingActionButton: FloatingActionButton(backgroundColor: Color(0xFF7C4DFF), child: Icon(Icons.add, color: Colors.white), onPressed: addExpenseDialog),
    );
  }
}