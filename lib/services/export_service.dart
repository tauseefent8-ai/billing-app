import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ExportService {
  static Future<void> exportToExcel(BuildContext context, List users, List bills, List collections) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetUsers = excel['Users'];
      sheetUsers.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Package'), TextCellValue('Amount'), TextCellValue('Pending Due'), TextCellValue('Expiry')]);
      for(var u in users){
        sheetUsers.appendRow([
          TextCellValue(u['name'].toString()),
          TextCellValue(u['phone'].toString()),
          TextCellValue(u['package'].toString()),
          TextCellValue(u['amount'].toString()),
          TextCellValue(u['pendingDue'].toString()),
          TextCellValue(u['expiryDate']!=null? DateTime.fromMillisecondsSinceEpoch(u['expiryDate']).toString().substring(0,10) : ''),
        ]);
      }
      Sheet sheetBills = excel['Bills'];
      sheetBills.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Amount'), TextCellValue('Month'), TextCellValue('Status')]);
      for(var b in bills){
        sheetBills.appendRow([TextCellValue(b['name'].toString()), TextCellValue(b['phone'].toString()), TextCellValue(b['amount'].toString()), TextCellValue(b['billMonth'].toString()), TextCellValue(b['isPaid']==true? 'Paid' : 'Pending')]);
      }
      Sheet sheetCol = excel['Collections'];
      sheetCol.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Amount'), TextCellValue('Month'), TextCellValue('Date')]);
      for(var c in collections){
        sheetCol.appendRow([TextCellValue(c['name'].toString()), TextCellValue(c['phone'].toString()), TextCellValue(c['amount'].toString()), TextCellValue(c['billMonth'].toString()), TextCellValue(c['date'].toString().substring(0,10))]);
      }

      var dir = await getApplicationDocumentsDirectory();
      String path = "${dir.path}/ISP_PENNEL_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      File file = File(path);
      await file.writeAsBytes(excel.encode()!);

      if(context.mounted){
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Excel Export ho gaya: $path"), backgroundColor: Colors.green, duration: Duration(seconds: 5)));
      }
    } catch(e){
      if(context.mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
      }
    }
  }
}