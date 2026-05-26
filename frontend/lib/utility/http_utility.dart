import 'dart:io';
import 'package:http/http.dart' as http;

void verifyResponse(http.Response response) {
  if (response.statusCode != 200) {
    throw HttpException("Non-2XX status code: ${response.statusCode}\n${response.body}");
  }
}
