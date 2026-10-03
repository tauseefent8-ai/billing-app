import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  String bizName = "";
  String dueDate = "10";
  String waTemplate = "";

  @override
  void initState(){
    super.initState();
    _loadInfo();
  }

  _loadInfo() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      bizName = p.getString('biz_name') ?? "My Wifi Business";
      dueDate = p.getString('bill_due_date') ?? "10";
      waTemplate = p.getString('wa_template') ?? "Salam {name}, aapka {package} ka bill Rs.{amount} hai.";
    });
  }

  void _showCostDialog() {
    showDialog(context: context, builder: (ctx) => const PackageCostDialog());
  }

  void _showBusinessDialog() {
    showDialog(context: context, builder: (ctx) => const BusinessInfoDialog()).then((_)=> _loadInfo());
  }

  void _showDueDateDialog() {
    TextEditingController c = TextEditingController(text: dueDate);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Bill Due Date", style: TextStyle(color: Colors.white)),
      content: TextField(controller: c, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Har mahine kis tareekh ko bill due ho? (1-28)", labelStyle: TextStyle(color: Colors.white54))),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setString('bill_due_date', c.text); _loadInfo(); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))
      ],
    ));
  }

  void _showWADialog() {
    TextEditingController c = TextEditingController(text: waTemplate);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("WhatsApp Template", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Message...", hintStyle: TextStyle(color: Colors.white38))),
        const SizedBox(height: 10),
        const Text("{name}, {amount}, {package} use kar sakte hain", style: TextStyle(color: Colors.white54, fontSize: 11)),
      ]),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setString('wa_template', c.text); _loadInfo(); if(mounted) Navigator.pop(ctx); }, child: const Text("Save"))
      ],
    ));
  }

  void _showBackupDialog() async {
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic> allData = {};
    allData['bills'] = p.getString('bills');
    allData['collections'] = p.getString('collections');
    allData['pkg_cost'] = p.getString('pkg_cost');
    allData['biz_name'] = p.getString('biz_name');
    allData['biz_phone'] = p.getString('biz_phone');
    allData['customers'] = p.getString('customers');

    String jsonStr = jsonEncode(allData);

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Backup & Restore", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ElevatedButton.icon(icon: const Icon(Icons.copy), label: const Text("Backup Copy Karo"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)), onPressed: () { Clipboard.setData(ClipboardData(text: jsonStr)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Backup Copy Ho Gaya! WhatsApp par save kar lo"))); }),
        const SizedBox(height: 15),
        const Text("Restore karne ke liye neeche backup paste karein:", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 10),
        TextField(maxLines: 5, style: const TextStyle(color: Colors.white, fontSize: 10), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Backup JSON yahan paste karein", hintStyle: TextStyle(color: Colors.white38)), onChanged: (val) async { if(val.length > 100){ try{ Map<String, dynamic> data = jsonDecode(val); final pref = await SharedPreferences.getInstance(); if(data['bills']!=null) await pref.setString('bills', data['bills']); if(data['collections']!=null) await pref.setString('collections', data['collections']); if(data['pkg_cost']!=null) await pref.setString('pkg_cost', data['pkg_cost']); if(data['biz_name']!=null) await pref.setString('biz_name', data['biz_name']); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restore Ho Gaya! App restart karein"))); } catch(e){} } }),
      ])),
      actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text("Close"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text("Settings", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: const Color(0xFF121212), iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildTitle("BUSINESS"),
          _buildTile(Icons.store, "Business Info", bizName, _showBusinessDialog),
          _buildTile(Icons.attach_money, "Package Cost (Kharid Rate)", "Profit sahi nikalne ke liye", _showCostDialog, color: Colors.green),
          const Divider(color: Colors.white12),
          _buildTitle("BILLING"),
          _buildTile(Icons.calendar_today, "Bill Due Date", "Har mah $dueDate tareekh ko due", _showDueDateDialog),
          _buildTile(Icons.message, "WhatsApp Template", waTemplate.isEmpty? "Default message" : waTemplate.substring(0, waTemplate.length>30?30:waTemplate.length), _showWADialog),
          const Divider(color: Colors.white12),
          _buildTitle("APP"),
          _buildTile(Icons.backup, "Backup & Restore", "Data mehfooz rakhein", _showBackupDialog),
          _buildTile(Icons.info, "App Version", "v1.0 - Bilal Wifi Manager", (){}),
        ],
      ),
    );
  }

  Widget _buildTitle(String t) => Padding(padding: const EdgeInsets.only(left: 15, top: 10, bottom: 5), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white38, fontSize: 12)));

  Widget _buildTile(IconData icon, String title, String subtitle, VoidCallback onTap, {Color color = const Color(0xFF7C4DFF)}) {
    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}

// --- Business Info Dialog ---
class BusinessInfoDialog extends StatefulWidget {
  const BusinessInfoDialog({super.key});
  @override
  State<BusinessInfoDialog> createState() => _BusinessInfoDialogState();
}
class _BusinessInfoDialogState extends State<BusinessInfoDialog> {
  final nameC = TextEditingController(); final phoneC = TextEditingController();
  @override
  void initState(){ super.initState(); _load(); }
  _load() async { final p = await SharedPreferences.getInstance(); setState((){ nameC.text = p.getString('biz_name') ?? ''; phoneC.text = p.getString('biz_phone') ?? '';});}
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Business Info", style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Dukan ka Naam", labelStyle: TextStyle(color: Colors.white54))),
        const SizedBox(height: 10),
        TextField(controller: phoneC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "WhatsApp Number", labelStyle: TextStyle(color: Colors.white54))),
      ]),
      actions: [TextButton(onPressed: () async { final p = await SharedPreferences.getInstance(); await p.setString('biz_name', nameC.text); await p.setString('biz_phone', phoneC.text); if(context.mounted) Navigator.pop(context);}, child: const Text("Save"))],
    );
  }
}

// --- Package Cost Dialog - FIXED (pkg_cost se connect) ---
class PackageCostDialog extends StatefulWidget {
  const PackageCostDialog({super.key});
  @override
  State<PackageCostDialog> createState() => _PackageCostDialogState();
}
class _PackageCostDialogState extends State<PackageCostDialog> {
  Map<String, TextEditingController> controllers = {};
  Map<String, double> defaultCost = {
    "10 MB": 680,
    "20 MB": 950,
    "30 MB": 1350,
    "50 MB": 1800,
  };

  @override
  void initState(){ super.initState(); _load(); }

  _load() async {
    final p = await SharedPreferences.getInstance();
    String? saved = p.getString('pkg_cost');
    Map<String, double> savedMap = {};
    if(saved!=null){
      try{ savedMap = (jsonDecode(saved) as Map).map((k,v)=> MapEntry(k, (v as num).toDouble())); } catch(e){}
    }
    setState((){
      defaultCost.forEach((k, v){
        controllers[k] = TextEditingController(text: (savedMap[k]?? v).toString());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text("Package Kharid Rate (Cost)", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: controllers.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: e.value,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "${e.key} ka Cost",
                labelStyle: const TextStyle(color: Colors.white54),
                border: const OutlineInputBorder(),
                prefixText: "Rs. ",
                prefixStyle: const TextStyle(color: Colors.white54),
              ),
            ),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF)),
          onPressed: () async {
            final p = await SharedPreferences.getInstance();
            Map<String, double> toSave = {};
            for(var e in controllers.entries){
              toSave[e.key] = double.tryParse(e.value.text)?? defaultCost[e.key]!;
            }
            await p.setString('pkg_cost', jsonEncode(toSave));
            // purani keys bhi save kar dete hain compatibility ke liye
            for(var e in toSave.entries){
              await p.setString('cost_${e.key}', e.value.toString());
            }
            if(context.mounted){
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cost Save! Ab Reports me profit sahi aayega"), backgroundColor: Colors.green));
            }
          },
          child: const Text("Save All"),
        ),
      ],
    );
  }
}