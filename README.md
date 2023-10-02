# Reliable File Upload Package.

Latest version is 0.0.1

# reliable_upload_pro
reliable_upload_pro is a Flutter package that provides support for reliable file uploads. It allows you to upload large files to a server and resume the upload from where it left off in case of interruptions or failures.

# Features
> Reliable file uploads.
> Support for large files.
> Easily handle upload interruptions.
> Configurable options for upload behavior.

# Installation
1. Add reliable_upload_pro to your pubspec.yaml file:
--------------------------------------------------
    dependencies:
        reliable_upload_pro: ^1.0.0

2. Usage
-------------------------------------------------
    Import the package:
    import 'package:reliable_upload_pro/reliable_upload_pro.dart';

3. Create an instance of ReliableUpload:
-------------------------------------------------
    client = UploadClient(
    file: file,
    cache: _localCache,
    blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
    );
    
4. Start the upload:
-----------------------------------------------
    client!.uploadBlob(
    onProgress: (count, total, response) {
        // Handle progress updates
    },
    onComplete: (path, response) {
        // Handle complete updates
    },
    onFailed: (e, {message}) => {
           // Handle upload failed
    });

# Configuration Options
@You can configure the behavior of the ReliableUpload by setting the following optional parameters:

> chunkSize: Set the size of each chunk to be uploaded. Default is 4 MB.
> timeout: Set the timeout duration for each upload request. Default is 60 seconds.

# Sample code:

-----------------------------------------------

    client = UploadClient(
        file: file,
        cache: _localCache,
        blobConfig: BlobConfig(blobUrl: blobUrl, sasToken: sasToken),
        );
    client!.uploadBlob(
        onProgress: (count, total, response) {
            // Handle progress updates
        },
        onComplete: (path, response) {
            // Handle complete updates
        },
        onFailed: (e, {message}) {
            // Handle upload failed
        },
    );

# Contributing
We welcome contributions to this package. Feel free to open issues and pull requests to suggest improvements or report bugs.

# License
This project is licensed under the MIT License.
