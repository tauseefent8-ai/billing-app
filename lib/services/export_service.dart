import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportService {
  static Future<void> exportToExcel(BuildContext context, List users, List bills, List collections) async {
    try {
      var excel = Excel.createExcel();

      // Sheet 1: Users
      Sheet sheetUsers = excel['Users'];
      sheetUsers.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Package'), TextCellValue('Amount'), TextCellValue('Pending Due'), TextCellValue('Expiry'), TextCellValue('Address')]);
      for(var u in users){
        sheetUsers.appendRow([
          TextCellValue(u['name'].toString()),
          TextCellValue(u['phone'].toString()),
          TextCellValue(u['package'].toString()),
          TextCellValue(u['amount'].toString()),
          TextCellValue(u['pendingDue'].toString()),
          TextCellValue(u['expiryDate']!=null? DateTime.fromMillisecondsSinceEpoch(u['expiryDate']).toString().substring(0,10) : ''),
          TextCellValue(u['address']?.toString()?? ''),
        ]);
      }

      // Sheet 2: Bills
      Sheet sheetBills = excel['Bills'];
      sheetBills.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Amount'), TextCellValue('Month'), TextCellValue('Status'), TextCellValue('Date')]);
      for(var b in bills){
        sheetBills.appendRow([
          TextCellValue(b['name'].toString()),
          TextCellValue(b['phone'].toString()),
          TextCellValue(b['amount'].toString()),
          TextCellValue(b['billMonth'].toString()),
          TextCellValue(b['isPaid']==true? 'Paid' : 'Pending'),
          TextCellValue(b['date']?.toString().substring(0,10)?? ''),
        ]);
      }

      // Sheet 3: Collections
      Sheet sheetCol = excel['Collections'];
      sheetCol.appendRow([TextCellValue('Name'), TextCellValue('Phone'), TextCellValue('Amount'), TextCellValue('Month'), TextCellValue('Date')]);
      for(var c in collections){
        sheetCol.appendRow([
          TextCellValue(c['name'].toString()),
          TextCellValue(c['phone'].toString()),
          TextCellValue(c['amount'].toString()),
          TextCellValue(c['billMonth'].toString()),
          TextCellValue(c['date']?.toString().substring(0,10)?? ''),
        ]);
      }

      // FIXED: Downloads folder me save + Share option
      Directory? dir;
      String path;

      if(Platform.isAndroid){
        // Android Downloads folder
        dir = Directory('/storage/emulated/0/Download');
        if(!await dir.exists()){
          dir = await getExternalStorageDirectory();
        }
      }else{
        dir = await getApplicationDocumentsDirectory();
      }

      String fileName = "ISP_PENNEL_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      path = "${dir!.path}/$fileName";
      File file = File(path);
      await file.writeAsBytes(excel.encode()!);

      // Share bhi karo taake user ko mile
      try{
        await Share.shareXFiles([XFile(path)], text: "ISP PENNEL Export - $fileName");
      }catch(_){}

      if(context.mounted){
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Excel Export ho gaya: $fileName\nLocation: ${dir.path}"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 6),
          action: SnackBarAction(label: "OK", textColor: Colors.white, onPressed: (){}),
        ));
      }
    } catch(e){
      if(context.mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Error: $e"), backgroundColor: Colors.red, duration: Duration(seconds: 5)));
      }
    }
  }
}