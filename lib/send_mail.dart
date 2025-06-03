import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

Future<void> sendPasswordEmail(String toEmail, String password) async {
  String username = 'monish2210858@ssn.edu.in';
  String appPassword = 'OECpsWYv@_2005'; // Not your normal password

  final smtpServer = gmail(username, appPassword);

  final message = Message()
    ..from = Address(username, 'Admin Team')
    ..recipients.add(toEmail)
    ..subject = 'Your Account Password'
    ..text = 'Hello,\n\nYour account password is: $password\n\nPlease keep it safe.';

  try {
    final sendReport = await send(message, smtpServer);
    print('Email sent: $sendReport');
  } on MailerException catch (e) {
    print('Email not sent. ${e.toString()}');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}

void main() async {
  await sendPasswordEmail('monishnandakumar@gmail.com', 'testPassword123');
}
