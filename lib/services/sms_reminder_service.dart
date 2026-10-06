import 'package:url_launcher/url_launcher.dart';

class SmsReminderService {
  // WhatsApp par auto reminder - customer ko
  static Future<void> sendWhatsAppReminder(String phone, String name, int amount) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if(cleanPhone.startsWith('0')) cleanPhone = '92${cleanPhone.substring(1)}';
    if(!cleanPhone.startsWith('92')) cleanPhone = '92$cleanPhone';

    String msg = "Assalam-o-Alaikum $name, Aapka ${amount} Rs Internet Bill ISP PENNEL ka pending hai. Baraye meherbani jald jama karwa dein. Shukria!";
    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(msg)}");
    if(await canLaunchUrl(url)){
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}