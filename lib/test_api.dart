import 'package:dio/dio.dart';

void testApi() async {
  final dio = Dio();
  try {
    final response = await dio.get('http://192.168.1.7:8000/status');
    print(response.data); 
  } catch (e) {
    print('Error: $e');
  }
}
