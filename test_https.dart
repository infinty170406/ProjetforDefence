import 'dart:io';

void main() async {
  try {
    var client = HttpClient();
    var request = await client.getUrl(Uri.parse('https://pub.dev/api/packages/flutter_dotenv'));
    var response = await request.close();
    print('Response: ${response.statusCode}');
  } catch (e) {
    print('Error: $e');
  }
}
