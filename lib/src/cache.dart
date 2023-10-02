import 'dart:convert';
import 'dart:developer';
import 'package:reliable_upload_pro/src/metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class UploadCache {
  Future<void> set(MetaData data);

  Future<MetaData?> get(String fingerPrint);

  Future<void> delete(String fingerPrint);

  Future<void> clearAll();
}

class MemoryCache implements UploadCache {
  final _cache = <String, MetaData>{};

  @override
  Future<void> set(MetaData data) async {
    _cache[data.key] = data;
  }

  @override
  Future<MetaData?> get(String key) async {
    return _cache[key];
  }

  @override
  Future<void> delete(String fingerprint) async {
    _cache.remove(fingerprint);
  }

  @override
  Future<void> clearAll() async {
    _cache.clear();
  }
}

class LocalCache implements UploadCache {
  @override
  Future<void> set(MetaData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.setString(data.key, data.toString());
  }

  @override
  Future<MetaData?> get(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    String? data = prefs.getString(key);
    if (data == null) return null;
    return MetaData.fromJson(jsonDecode(data));
  }

  Future<void> getAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    Set<String> keys = prefs.getKeys();
    if (keys.isEmpty) {
      log("No Cache found in SharedPreferences");
    } else {
      for (String key in keys) {
        log("Key: $key");
      }
    }
  }

  @override
  Future<void> delete(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.remove(key);
  }

  @override
  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.clear();
  }
}
