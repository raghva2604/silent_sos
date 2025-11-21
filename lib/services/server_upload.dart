import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Uploads files to the local server /upload endpoint and returns array of short URLs.
/// `serverBase` should be like `http://10.0.2.2:3000` for emulator or `http://your-host:3000` for a device-accessible host.
Future<List<String>> uploadFilesToServer(List<File> files, {required String serverBase}) async {
  final uri = Uri.parse('$serverBase/upload');
  final req = http.MultipartRequest('POST', uri);

  for (final f in files) {
    final stream = http.ByteStream(f.openRead());
    final length = await f.length();
    final filename = f.path.split(Platform.pathSeparator).last;
    final multipart = http.MultipartFile('files', stream, length, filename: filename);
    req.files.add(multipart);
  }

  final resp = await req.send();
  if (resp.statusCode != 200) {
    final body = await resp.stream.bytesToString();
    throw HttpException('upload failed: ${resp.statusCode} ${resp.reasonPhrase} - $body');
  }

  final body = await resp.stream.bytesToString();
  // response JSON has structure { ok: true, uploads: [{id,url,filename}] }
  final parsed = http.Response(body, resp.statusCode);
  final json = parsedToJson(parsed.body);
  if (json == null || json['ok'] != true) throw HttpException('upload did not return ok: $body');
  final uploads = json['uploads'] as List<dynamic>? ?? [];
  return uploads.map((u) => (u['url'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
}

Map<String, dynamic>? parsedToJson(String body) {
  try {
    final m = json.decode(body);
    if (m is Map<String, dynamic>) return m;
    return null;
  } catch (e) {
    return null;
  }
}
