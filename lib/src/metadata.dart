import 'dart:convert';

class MetaData {
  late String key;

  late int offset;

  late int totalSize;

  late int chunkCount;

  late Map<String, bool> blockIdMap;

  late bool isChucksUploadCompleted;

  MetaData(this.key, this.offset)
      : totalSize = 0,
        chunkCount = 0,
        blockIdMap = {},
        isChucksUploadCompleted = false;

  @override
  String toString() {
    Map<String, dynamic> data = {
      'key': key,
      'offset': offset,
      'totalSize': totalSize,
      'chunkCount': chunkCount,
      'blockIdMap': blockIdMap,
      'isChucksUploadCompleted': isChucksUploadCompleted
    };
    return jsonEncode(data);
  }

  MetaData.fromJson(Map<String, dynamic> data) {
    key = data['key'];
    offset = data['offset'];
    totalSize = data['totalSize'];
    chunkCount = data['chunkCount'];
    if (data['blockIdMap'] != null) {
      blockIdMap = Map<String, bool>.from(data['blockIdMap']);
    } else {
      blockIdMap = {};
    }
    isChucksUploadCompleted = data['isChucksUploadCompleted'];
  }
}
