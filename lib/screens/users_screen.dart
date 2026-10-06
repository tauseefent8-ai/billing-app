import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';
import '../services/sms_reminder_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class UsersScreen extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> bills;
  final List<dynamic> collections;
  final VoidCallback onUsersUpdate;
  final VoidCallback onBillsUpdate;
  final VoidCallback onCollectionsUpdate;
  const UsersScreen({super.key, required this.users, required this.bills, required this.collections, required this.onUsersUpdate, required this.onBillsUpdate, required this.onCollectionsUpdate});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String search = "";
  TextEditingController searchCtrl = TextEditingController();

  List<dynamic> get filtered {
    return widget.users.where((u){
      if(search.isEmpty) return true;
      return u['name'].toString().toLowerCase().contains(search.toLowerCase()) || u['phone'].toString().contains(search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<AppProvider>(context);
    var displayList = filtered.skip(provider.currentPage * provider.pageSize).take(provider.pageSize).toList();

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(backgroundColor: Color(0xFF121212), title: Text("Customers ${widget.users.length}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16))),
      body: Column(children: [
        Padding(padding: EdgeInsets.all(12), child: TextField(controller: searchCtrl, style: TextStyle(color: Colors.white), onChanged: (v)=> setState(()=> search=v), decoration: InputDecoration(hintText: "Search customer...", prefixIcon: Icon(Icons.search, color: Colors.white54), filled: true, fillColor: Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Page ${provider.currentPage+1}/${provider.totalPages==0?1:provider.totalPages}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
          Row(children: [IconButton(icon: Icon(Icons.arrow_back, color: Colors.white70, size: 20), onPressed: provider.prevPage), IconButton(icon: Icon(Icons.arrow_forward, color: Colors.white70, size: 20), onPressed: provider.nextPage)]),
        ])),
        Expanded(child: ListView.builder(itemCount: displayList.length, itemBuilder: (c,i){
          var u = displayList[i];
          bool isExpired = false;
          if(u['expiryDate']!=null){ try{ if(DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(u['expiryDate']))) isExpired=true; }catch(e){} }
          return Container(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: isExpired? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3))), child: ListTile(leading: CircleAvatar(backgroundColor: isExpired? Colors.red : Colors.green, child: Icon(isExpired? Icons.warning : Icons.person, color: Colors.white, size: 18)), title: Text(u['name'].toString(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), subtitle: Text("${u['phone']} | Rs.${u['amount']} | Due Rs.${u['pendingDue']??0}", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(Icons.message, color: Colors.greenAccent, size: 18), onPressed: ()=> SmsReminderService.sendWhatsAppReminder(u['phone'].toString(), u['name'].toString(), FirebaseService.parseAmount(u['amount']))),
            IconButton(icon: Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () async {
              bool confirm = await showDialog(context: context, builder: (ctx)=> AlertDialog(backgroundColor: Color(0xFF1E1E1E), title: Text("User Delete?", style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)), content: Text("${u['name']} ko delete karna hai? Bill undo me rahega, delete nahi hoga.", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: Text("Nahi")), TextButton(onPressed: ()=> Navigator.pop(ctx,true), child: Text("Haan", style: TextStyle(color: Colors.red)))]))?? false;
              if(!confirm) return;
              try{ await FirebaseService.usersCol.doc(u['phone'].toString()).delete(); provider.removeUserLocal(u['phone'].toString()); widget.onUsersUpdate(); if(mounted){ ScaffoldMessenger.of(context).clearSnackBars(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${u['name']} delete ho gaya, bill undo me hai"), backgroundColor: Colors.orange, duration: Duration(seconds: 5))); } }catch(e){}
            }),
          ])));
        })),
      ]),
    );
  }
}