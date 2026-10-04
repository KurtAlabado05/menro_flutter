import 'dart:convert';
import 'package:http/http.dart' as http;


class LocationService {
  // Use the flat base URL as per documentation
  final String _baseUrl = "https://psgc.cloud/api";

  Future<List<dynamic>> getRegions() async {
    final response = await http.get(Uri.parse('$_baseUrl/regions'));
    return json.decode(response.body);
  }

  Future<List<dynamic>> getProvinces() async {
    final response = await http.get(Uri.parse('$_baseUrl/provinces'));
    return json.decode(response.body);
  }

  Future<List<dynamic>> getCities() async {
    final response = await http.get(Uri.parse('$_baseUrl/cities'));
    return json.decode(response.body);
  }

  Future<List<dynamic>> getMunicipalities() async {
    final response = await http.get(Uri.parse('$_baseUrl/municipalities'));
    return json.decode(response.body);
  }

  Future<List<dynamic>> getBarangays() async {
    final response = await http.get(Uri.parse('$_baseUrl/barangays'));
    return json.decode(response.body);
  }
}
