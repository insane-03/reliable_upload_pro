import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reliable_upload_pro/reliable_upload_pro.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resumable upload Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Resumable upload Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String process = '0%';
  late UploadClient? client;
  final LocalCache _localCache = LocalCache();

  uploadFunc() async {
    final filePath = await filePathPicker();
    final File file = File(filePath!);
    final String blobName = file.path.split('/').last;
    final String blobUrl =
        'https://worksamplestorageaccount.blob.core.windows.net/kyn-blob-video/$blobName';
    const String sasToken =
        'sv=2022-11-02&ss=bf&srt=co&se=2023-10-04T18%3A38%3A59Z&sp=rwl&sig=ZJ%2Bb7mD3M6eBtZDMcctwgD0DTaHqg%2FLYmsjiHzcUyvc%3D';

    try {
      client = UploadClient(
          file: file,
          blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
          cancelTokenDio: CancelToken(),
          cache: _localCache);
      client!.uploadBlob(
          onProgress: (count, total, response) {
            final num = ((count / total) * 100).toInt().toString();
            setState(() {
              process = '$num%';
            });
          },
          onComplete: (path, response) {
            setState(() {
              process = 'Completed';
            });
            log(path);
            return path;
          },
          onFailed: (e, {message}) => {
                setState(() {
                  process = message ?? e.toString();
                })
              });
    } catch (e) {
      setState(() {
        process = e.toString();
      });
    }
  }

  Future<String?> filePathPicker() async {
    File? file;

    try {
      final XFile? galleryFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
      );

      if (galleryFile == null) {
        return null;
      }

      file = File(galleryFile.path);
    } catch (e) {
      return null;
    }

    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              process,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(
              height: 20.0,
            ),
            InkWell(
              onTap: () {
                setState(() {
                  process = 'Cancelled';
                });
              },
              child: Container(
                color: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 16.0),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                onPressed: () => {
                      _localCache.clearAll(),
                      setState(() {
                        process = '0%';
                      })
                    },
                icon: const Icon(Icons.cancel),
                label: const Text('clear cache')),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                onPressed: () => {
                      _localCache.getAll(),
                    },
                icon: const Icon(Icons.show_chart),
                label: const Text('show cached'))
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: uploadFunc,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
