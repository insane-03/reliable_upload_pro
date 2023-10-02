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

typedef CompleteCallback = String Function(String path, Response response);

typedef FailedCallback = Object Function(Object? e, {String? message});

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
  CancelToken? cancelTokenDio;
  // DateTime? startTime;

  UploadClient(
      {required this.file,
      this.blobConfig,
      int? chunkSize,
      UploadCache? cache,
      Duration? timeout,
      CancelToken? cancelTokenDio})
      : chunkSize = chunkSize ?? 4 * 1024 * 1024,
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
        metaData.chunkCount != totalChunkCount) {
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
        _onComplete?.call(
            response!.realUri.origin + response.realUri.path, response);
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
          options: Options(
            headers: {
              'x-ms-blob-type': 'BlockBlob',
              'Content-Length': chunkData.length,
            },
            contentType: getContentType(file.path),
          ),
          onSendProgress: (count, total) {
            // Calculate progress for the current chunk
            final chunkProgress =
                ((metaData.chunkCount * chunkSize + count) / fileSize * 100)
                    .toDouble();
            final limitedProgress =
                chunkProgress.clamp(0, 100); // Limit progress to 100
            _onProgress?.call(limitedProgress.toInt(), 100, null);
          },
          cancelToken: cancelTokenDio,
        );
        print(response.statusCode);
        if (response.statusCode == 201) {
          metaData.blockIdMap[blockId] = true;
          offset += chunkData.length;
          metaData.offset = offset;
          metaData.chunkCount++;
          // Calculate total progress for all chunks
          final totalProgress =
              (metaData.chunkCount * chunkSize / fileSize * 100).toDouble();
          final limitedTotalProgress =
              totalProgress.clamp(0, 100); // Limit total progress to 100
          _onProgress?.call(limitedTotalProgress.toInt(), 100, response);
          if (offset >= fileSize) {
            metaData.isChucksUploadCompleted = true;
            break;
          }
        }
        cache.set(metaData);
      } catch (error) {
        cache.set(metaData);
        _onFailed?.call(error, message: 'failed');
        cancelTokenDio?.cancel();
        break;
      }
    }
  }

  void cancelClient() {
    cache.delete(fingerPrint);
  }

  Future<Response?> _commitUpload(commitUri, dynamic body) async {
    try {
      Response commitResponse = await Dio().put(
        commitUri,
        data: body,
        options: Options(
          contentType: getContentType(file.path),
        ),
        cancelToken: cancelTokenDio,
      );
      if (commitResponse.statusCode == 201) {
        cache.delete(fingerPrint);
        return commitResponse;
      }
      _onFailed?.call(null, message: 'failed to commit');
      return commitResponse;
    } catch (error) {
      _onFailed?.call(error, message: 'failed');
      cancelTokenDio?.cancel();
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
    final String blockId =
        'kyn-${index.toString()}-${const Uuid().v4().replaceAll('-', '')}';
    final String encodedBlockId = base64.encode(utf8.encode(blockId));
    if (encodedBlockId.length > 88) {
      return encodedBlockId.substring(0, 88);
    } else {
      return encodedBlockId;
    }
  }

  // Function to determine content type based on file extension
  String getContentType(String filePath) {
    final fileExtension = filePath.split('.').last.toLowerCase();
    switch (fileExtension) {
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/avi';
      case 'mkv':
        return 'video/x-matroska';
      case 'png':
        return 'video/png';
      // Add more file extensions and content types as needed
      default:
        return 'application/octet-stream'; // Default content type
    }
  }

  // void timeLeftToUpload(int count, int total, Response? response) {
  //   if (startTime == null) {
  //     startTime = DateTime.now();
  //     return;
  //   }

  //   final currentTime = DateTime.now();
  //   final elapsedTime = currentTime.difference(startTime!);

  //   if (count > 0 && total > 0) {
  //     final bytesUploaded = metaData.chunkCount * chunkSize + count;
  //     final bytesRemaining = fileSize - bytesUploaded;

  //     final uploadSpeed =
  //         bytesUploaded / elapsedTime.inSeconds; // Bytes per second
  //     final timeLeftInSeconds = bytesRemaining / uploadSpeed;

  //     final formattedTimeLeft = _formatTimeLeft(timeLeftInSeconds);

  //     print('Time left to upload: $formattedTimeLeft');
  //   }
  // }

  // String _formatTimeLeft(double seconds) {
  //   final int hours = (seconds / 3600).floor();
  //   final int minutes = ((seconds % 3600) / 60).floor();
  //   final int remainingSeconds = (seconds % 60).floor();

  //   final List<String> parts = [];

  //   if (hours > 0) {
  //     parts.add('$hours h');
  //   }

  //   if (minutes > 0) {
  //     parts.add('$minutes min');
  //   }

  //   if (remainingSeconds > 0) {
  //     parts.add('$remainingSeconds sec');
  //   }

  //   return parts.join(' ');
  // }
}
