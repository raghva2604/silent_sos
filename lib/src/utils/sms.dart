import 'package:url_launcher/url_launcher.dart';

Future<void> openSmsCompose(String phoneNumber, String message) async {
  final uri = Uri(
    scheme: 'sms',
    path: phoneNumber,
    queryParameters: {'body': message},
  );
  final launched = await launchUrl(uri);
  if (!launched) {
    throw 'Could not open SMS app';
  }
}
