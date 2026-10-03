import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerDashboard extends StatelessWidget {
  final String phone;
  final String ispId;
  CustomerDashboard({required this.phone, required this.ispId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Bill - $ispId")),
      body: StreamBuilder(
          stream: FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: phone).where('isp_id', isEqualTo: ispId).snapshots(),
          builder: (context, snapshot){
            if(!snapshot.hasData) return Center(child: CircularProgressIndicator());
            if(snapshot.data!.docs.isEmpty) return Center(child: Text("No Data Found"));
            var user = snapshot.data!.docs.first.data();
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Name: ${user['name']}", style: TextStyle(fontSize: 20)),
              Text("Package: ${user['package']}"),
              Text("Expiry: ${user['expiry']}"),
              Text("ISP: $ispId"),
            ]));
          }
      ),
    );
  }
}