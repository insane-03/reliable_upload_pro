// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:reliable_upload_pro/src/blob_config.dart';
import 'package:reliable_upload_pro/src/cache.dart';
import 'package:reliable_upload_pro/src/metadata.dart';

typedef ProgressCallback = void Function(
    int count, int total, Response? response);

typedef CompleteCallback = void Function(String path, Response response);

typedef FailedCallback = void Function(Object? e, {String? message});

class UploadClient {
  final File file;
  BlobConfig? blobConfig;
  int fileSize = 0;
  final int chunkSize;
  late int chunkCount;
  Map<String, bool> blockIdMap = {};
  late MetaData metaData;
  int offset = 0;
  late String fingerPrint;
  ProgressCallback? _onProgress;
  CompleteCallback? _onComplete;
  FailedCallback? _onFailed;
  final UploadCache cache;
  final Duration timeout;
  int totalChunkCount = 0;

  UploadClient({
    required this.file,
    this.blobConfig,
    int? chunkSize,
    UploadCache? cache,
    Duration? timeout,
  })  : chunkSize = chunkSize ?? 4 * 1024 * 1024,
        cache = cache ?? MemoryCache(),
        chunkCount = 0,
        timeout = timeout ?? const Duration(seconds: 30) {
    fingerPrint = generateFingerprint();
  }

  uploadBlob({
    ProgressCallback? onProgress,
    CompleteCallback? onComplete,
    FailedCallback? onFailed,
  }) async {
    fileSize = await file.length();

    _onProgress = onProgress;
    _onComplete = onComplete;
    _onFailed = onFailed;

    if (blobConfig == null) {
      throw Exception('Blob config missing');
    }

    await _canResume();

    metaData.totalSize = fileSize;

    totalChunkCount = (fileSize / chunkSize).ceil();

    final commitUri = blobConfig!.getCommitUri();

    if (!metaData.isChucksUploadCompleted &&
        metaData.chunkCount < totalChunkCount) {
      await uploadChunk(blobConfig!.getBlockUri);
    }

    if (metaData.offset >= fileSize &&
        metaData.isChucksUploadCompleted &&
        totalChunkCount == metaData.chunkCount) {
      final blockListXml =
          '<BlockList>${metaData.blockIdMap.keys.map((id) => '<Latest>$id</Latest>').join()}</BlockList>';
      print(blockListXml);
      final response = await _commitUpload(commitUri, blockListXml);
      if (response?.statusCode == 201) {
        _onComplete?.call(response!.requestOptions.path, response);
        cache.delete(metaData.key);
      }
    }
  }

  Future<void> uploadChunk(Function(String) getUrl) async {
    while (metaData.offset < fileSize) {
      final blockId = generateBlockId(metaData.chunkCount + 1);

      print("${metaData.chunkCount + 1}  $blockId");

      final url = getUrl(blockId);

      final List<int> data = await file.readAsBytes();

      final size =
          offset + chunkSize > data.length ? data.length : offset + chunkSize;

      final List<int> chunkData = data.sublist(offset, size);
      print(chunkData.length);
      try {
        Response? response = await Dio().put(
          url,
          data: Stream.fromIterable(chunkData.map((e) => [e])),
          options: Options(headers: {
            'x-ms-blob-type': 'BlockBlob',
            'Content-Length': chunkData.length,
          }, contentType: 'video/mp4'),
          onSendProgress: (count, total) {
            _onProgress?.call(count, total, null);
          },
        );
        print(response.statusCode);
        if (response.statusCode == 201) {
          metaData.blockIdMap[blockId] = true;
          offset += chunkData.length;
          metaData.offset = offset;
          metaData.chunkCount++;
          _onProgress?.call(offset, fileSize, response);
          if (offset >= fileSize) {
            metaData.isChucksUploadCompleted = true;
            break;
          }
        }
        cache.set(metaData);
      } catch (error) {
        cache.set(metaData);
        _onFailed?.call(error, message: 'failed');
        break;
      }
    }
  }

  void cancelClient() {
    cache.delete(fingerPrint);
  }

  Future<Response?> _commitUpload(commitUri, dynamic body) async {
    try {
      Response commitResponse = await Dio().put(commitUri, data: body);
      if (commitResponse.statusCode == 201) {
        cache.delete(fingerPrint);
        return commitResponse;
      }
      _onFailed?.call(null, message: 'failed to commit');
      return commitResponse;
    } catch (error) {
      _onFailed?.call(error, message: 'failed');
      return null;
    }
  }

  Future<void> _canResume() async {
    final fileData = await cache.get(fingerPrint);
    if (fileData == null) {
      metaData = MetaData(fingerPrint, offset);
      return;
    }
    offset = fileData.offset;
    blockIdMap = fileData.blockIdMap;
    chunkCount = fileData.chunkCount;
    metaData = fileData;
    _onProgress?.call(offset, fileSize, null);
  }

  void saveMetaData() {
    cache.set(metaData);
  }

  void deleteMetaData() {
    cache.delete(fingerPrint);
  }

  String generateFingerprint() =>
      file.path.split('/').last.replaceAll(RegExp(r'\W+'), '');

  String generateBlockId(int index) {
    final String blockId = 'kyn-${index.toString()}-${const Uuid().v4()}';
    return base64.encode(utf8.encode(blockId));
  }
}
