import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class Config {
  String botToken;
  String guildId;
  String categoryId;

  Config({required this.botToken, required this.guildId, required this.categoryId});

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      botToken: json['BOT_TOKEN'] ?? 'bot token',
      guildId: json['guild_id'] ?? 'your guild id',
      categoryId: json['category_id'] ?? 'your storage category id',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'BOT_TOKEN': botToken,
      'guild_id': guildId,
      'category_id': categoryId,
    };
  }
}

class Link {
  int partNumber;
  String channelId;
  String messageId;

  Link({required this.partNumber, required this.channelId, required this.messageId});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      partNumber: json['partNo'],
      channelId: json['channelId'],
      messageId: json['messageId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partNo': partNumber,
      'channelId': channelId,
      'messageId': messageId,
    };
  }
}

class DiscordStorage {
  static const int partSize = 10475274; // ~10MB
  late Config config;
  String? createdWebhook;
  String? lastChannelId;
  String? lastMessageId;

  DiscordStorage() {
    config = _loadConfig();
  }

  Config _loadConfig() {
    final configFile = File('config.json');
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final json = jsonDecode(content);
        return Config.fromJson(json);
      } catch (e) {
        print('Error reading config.json: $e');
        return _createDefaultConfig();
      }
    } else {
      return _createDefaultConfig();
    }
  }

  Config _createDefaultConfig() {
    final defaultConfig = Config(
      botToken: 'bot token',
      guildId: 'your guild id',
      categoryId: 'your storage category id',
    );

    try {
      final configFile = File('config.json');
      configFile.writeAsStringSync(jsonEncode(defaultConfig.toJson()));
      print('config.json file not found, created: config.json');
    } catch (e) {
      print('Error creating config.json: $e');
    }

    return defaultConfig;
  }

  Future<bool> checkToken() async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {
          'Authorization': 'Bot ${config.botToken}',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error checking token: $e');
      return false;
    }
  }

  Future<String> createChannel(String channelName) async {
    try {
      final channelData = {
        'name': channelName,
        'type': 0, // Text channel
        if (config.categoryId != 'your storage category id') 'parent_id': config.categoryId,
      };

      final response = await http.post(
        Uri.parse('https://discord.com/api/v10/guilds/${config.guildId}/channels'),
        headers: {
          'Authorization': 'Bot ${config.botToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(channelData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final channelId = data['id'];
        print('Channel created: $channelName (ID: $channelId)');
        
        // Create webhook
        final webhookUrl = await createWebhook(channelId, 'File Uploader');
        createdWebhook = webhookUrl;
        return channelId;
      } else {
        throw Exception('Failed to create channel: ${response.body}');
      }
    } catch (e) {
      print('Error creating channel: $e');
      rethrow;
    }
  }

  Future<String> createWebhook(String channelId, String name) async {
    try {
      final webhookData = {
        'name': name,
      };

      final response = await http.post(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/webhooks'),
        headers: {
          'Authorization': 'Bot ${config.botToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(webhookData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final webhookUrl = 'https://discord.com/api/webhooks/${data['id']}/${data['token']}';
        print('Webhook created: $name');
        print('Webhook URL: $webhookUrl');
        return webhookUrl;
      } else {
        throw Exception('Failed to create webhook: ${response.body}');
      }
    } catch (e) {
      print('Error creating webhook: $e');
      rethrow;
    }
  }

  Future<void> uploadFile(String webhookUrl, String filePath, int partNumber, String message, {bool deleteAfter = false}) async {
    try {
      final file = File(filePath);
      final fileName = path.basename(filePath);
      
      final request = http.MultipartRequest('POST', Uri.parse(webhookUrl));
      request.fields['content'] = message;
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        print('Successfully uploaded: $fileName');
        
        if (deleteAfter) {
          try {
            await file.delete();
          } catch (e) {
            print('Error deleting file: $e');
          }
        }

        // Log response
        final logFile = File('postlog.txt');
        await logFile.writeAsString('Webhook Response: $responseBody\n', mode: FileMode.append);

        // Extract channel and message IDs
        final responseData = jsonDecode(responseBody);
        final channelId = responseData['channel_id'];
        final messageId = responseData['id'];
        
        if (channelId != null && messageId != null) {
          lastChannelId = channelId;
          lastMessageId = messageId;
        }
      } else {
        throw Exception('Failed to upload file: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      print('Error uploading file: $e');
      rethrow;
    }
  }

  Future<String> getFileUrl(String channelId, String messageId) async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages/$messageId'),
        headers: {
          'Authorization': 'Bot ${config.botToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attachments = data['attachments'] as List;
        
        if (attachments.isNotEmpty) {
          return attachments[0]['url'];
        } else {
          throw Exception('No attachments found in message');
        }
      } else {
        throw Exception('Failed to get message: ${response.body}');
      }
    } catch (e) {
      print('Error getting file URL: $e');
      rethrow;
    }
  }

  Future<void> downloadFile(String url, String outputPath) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final file = File(outputPath);
        await file.writeAsBytes(response.bodyBytes);
        print('Downloaded: $outputPath');
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading file: $e');
      rethrow;
    }
  }

  String calculateFileHash(String filePath) {
    try {
      final file = File(filePath);
      final bytes = file.readAsBytesSync();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Error calculating hash: $e');
      return '';
    }
  }

  void printProgressBar(int current, int total, {int barWidth = 50}) {
    final progress = current / total;
    final pos = (barWidth * progress).round();
    
    final bar = StringBuffer('[');
    for (int i = 0; i < barWidth; i++) {
      if (i < pos) {
        bar.write('=');
      } else if (i == pos) {
        bar.write('>');
      } else {
        bar.write(' ');
      }
    }
    bar.write(']');
    
    final percentage = (progress * 100).round();
    stdout.write('\r$bar $percentage% ($current/$total)');
    
    if (current == total) {
      print('');
    }
  }

  Future<void> backupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print('Error: File not found: $filePath');
        return;
      }

      final fileName = path.basename(filePath);
      final linksFile = File('${filePath}_links.txt');
      final tempDir = Directory('temp');
      
      if (!tempDir.existsSync()) {
        tempDir.createSync();
      }

      final fileSize = file.lengthSync();
      final totalParts = ((fileSize + partSize - 1) ~/ partSize);
      
      int startPart = 0;
      String? existingHash;
      String? existingWebhook;

      // Check if backup already exists
      if (linksFile.existsSync()) {
        final lines = linksFile.readAsLinesSync();
        if (lines.length >= 4) {
          existingHash = lines[2];
          existingWebhook = lines[3];
          final currentHash = calculateFileHash(filePath);
          
          if (existingHash == currentHash) {
            createdWebhook = existingWebhook;
            // Find last uploaded part
            for (int i = 4; i < lines.length; i++) {
              try {
                final linkData = jsonDecode(lines[i]);
                startPart = max(startPart, linkData['partNo'] as int);
              } catch (e) {
                // Skip invalid lines
              }
            }
            print('Resuming upload from part ${startPart + 1}');
          } else {
            print('Error: Different file with same name detected. Please remove or rename the other file.');
            return;
          }
        }
      } else {
        // Create new backup
        await createChannel(fileName);
        
        final linksContent = StringBuffer();
        linksContent.writeln(totalParts);
        linksContent.writeln(fileName);
        linksContent.writeln(calculateFileHash(filePath));
        linksContent.writeln(createdWebhook);
        
        linksFile.writeAsStringSync(linksContent.toString());
      }

      // Split and upload file
      final bytes = file.readAsBytesSync();
      
      for (int i = startPart; i < totalParts; i++) {
        final start = i * partSize;
        final end = min(start + partSize, bytes.length);
        final partBytes = bytes.sublist(start, end);
        
        final partFile = File('temp/${fileName}.part${i + 1}');
        partFile.writeAsBytesSync(partBytes);
        
        final message = 'File part: ${i + 1}';
        await uploadFile(createdWebhook!, partFile.path, i + 1, message, deleteAfter: true);
        
        // Save link info
        final linkData = Link(
          partNumber: i + 1,
          channelId: lastChannelId!,
          messageId: lastMessageId!,
        );
        
        linksFile.writeAsStringSync('${jsonEncode(linkData.toJson())}\n', mode: FileMode.append);
        
        printProgressBar(i + 1, totalParts);
      }

      await uploadFile(createdWebhook!, linksFile.path, 0, "");
      
      // Send final message
      final finalMessage = {
        'channelId': lastChannelId,
        'fileName': fileName,
        'messageId': lastMessageId,
      };
      
      final finalResponse = await http.post(
        Uri.parse(createdWebhook!),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': jsonEncode(finalMessage)}),
      );

      print('\n✅ Backup completed successfully!');
      print('📝 Important notes:');
      print('• Don\'t write messages in the created channel');
      print('• This should be used as an alternative backup, not the only one');
      print('• As they say: If your data is not in three places, it does not exist');
      
    } catch (e) {
      print('Error during backup: $e');
    }
  }

  Future<void> downloadBackup(String linksFilePath) async {
    try {
      final linksFile = File(linksFilePath);
      if (!linksFile.existsSync()) {
        print('Error: Links file not found: $linksFilePath');
        return;
      }

      final lines = linksFile.readAsLinesSync();
      if (lines.length < 4) {
        print('Error: Invalid links file format');
        return;
      }

      final totalParts = int.parse(lines[0]);
      final fileName = lines[1];
      final expectedHash = lines[2];
      final webhook = lines[3];

      final links = <Link>[];
      for (int i = 4; i < lines.length; i++) {
        try {
          final linkData = jsonDecode(lines[i]);
          links.add(Link.fromJson(linkData));
        } catch (e) {
          print('Error parsing link at line ${i + 1}: $e');
        }
      }

      if (links.length != totalParts) {
        print('Error: Number of links (${links.length}) does not match total parts ($totalParts)');
        return;
      }

      // Sort links by part number
      links.sort((a, b) => a.partNumber.compareTo(b.partNumber));

      // Download parts
      print('Downloading parts...');
      final partFiles = <String>[];
      
      for (int i = 0; i < links.length; i++) {
        final link = links[i];
        final partFileName = 'part${link.partNumber}.tmp';
        final url = await getFileUrl(link.channelId, link.messageId);
        
        await downloadFile(url, partFileName);
        partFiles.add(partFileName);
        
        printProgressBar(i + 1, totalParts);
      }

      // Merge parts
      print('Merging parts...');
      final outputFile = File(fileName);
      final sink = outputFile.openWrite();
      
      for (int i = 0; i < partFiles.length; i++) {
        final partFile = File(partFiles[i]);
        final bytes = partFile.readAsBytesSync();
        sink.add(bytes);
        
        // Clean up part file
        partFile.deleteSync();
        
        printProgressBar(i + 1, partFiles.length);
      }
      
      await sink.close();

      // Verify hash
      final downloadedHash = calculateFileHash(fileName);
      if (downloadedHash == expectedHash) {
        print('\n✅ File downloaded and verified successfully: $fileName');
      } else {
        print('\n❌ Warning: File hash mismatch! The downloaded file may be corrupted.');
        print('Expected: $expectedHash');
        print('Got: $downloadedHash');
      }
      
    } catch (e) {
      print('Error during download: $e');
    }
  }

  Future<List<String>> getCloudFiles() async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${config.guildId}/channels'),
        headers: {
          'Authorization': 'Bot ${config.botToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final channels = jsonDecode(response.body) as List;
        final cloudFiles = <String>[];
        
        for (final channel in channels) {
          if (channel['parent_id'] == config.categoryId) {
            // Get last message from channel
            final messagesResponse = await http.get(
              Uri.parse('https://discord.com/api/v10/channels/${channel['id']}/messages?limit=1'),
              headers: {
                'Authorization': 'Bot ${config.botToken}',
                'Content-Type': 'application/json',
              },
            );
            
            if (messagesResponse.statusCode == 200) {
              final messages = jsonDecode(messagesResponse.body) as List;
              if (messages.isNotEmpty) {
                try {
                  final content = messages[0]['content'];
                  final fileData = jsonDecode(content);
                  cloudFiles.add(fileData['fileName']);
                } catch (e) {
                  // Skip invalid messages
                }
              }
            }
          }
        }
        
        return cloudFiles;
      } else {
        throw Exception('Failed to get channels: ${response.body}');
      }
    } catch (e) {
      print('Error getting cloud files: $e');
      return [];
    }
  }

  Future<void> listCloudFiles() async {
    print('Getting cloud files, please wait...');
    final cloudFiles = await getCloudFiles();
    
    if (cloudFiles.isEmpty) {
      print('No files found in cloud storage.');
      return;
    }
    
    print('\n--- Cloud Storage Files ---');
    for (final fileName in cloudFiles) {
      print('• $fileName');
    }
    print('---------------------------\n');
  }

  static void showHelp() {
    print('''
Discord Storage CLI - Dart Version
A tool for storing large files on Discord using a bot.

USAGE:
  discordStorage.exe [COMMAND] [OPTIONS]

COMMANDS:
  backup <file_path>     Backup a file to Discord cloud storage
  download <links_file>  Download and restore a file from cloud storage
  upload-error <webhook> <file>  Upload a problematic file using webhook
  list                   List all files in cloud storage
  help                   Show this help message
  interactive            Start interactive mode (default)

EXAMPLES:
  discordStorage.exe backup "C:\\Users\\user\\file.zip"
  discordStorage.exe download "backup_links.txt"
  discordStorage.exe upload-error "https://discord.com/api/webhooks/..." "error_file.txt"
  discordStorage.exe list
  discordStorage.exe help

INTERACTIVE MODE:
  If no command is provided, the program will start in interactive mode
  where you can select operations from a menu.

CONFIGURATION:
  The program uses config.json file for Discord bot configuration.
  Edit this file to set your bot token, guild ID, and category ID.

NOTES:
  • Make sure your bot has proper permissions in the Discord server
  • Large files are split into parts (~10MB each) for upload
  • Always keep multiple backups of important files
  • Don't write messages in the created storage channels
''');
  }

  Future<void> runInteractive() async {
    while (true) {
      print('\n' + '=' * 60);
      print('Discord Storage CLI - Interactive Mode');
      print('=' * 60);
      print('1. Backup a file');
      print('2. Download a file');
      print('3. Upload error file');
      print('4. List cloud files');
      print('5. Show help');
      print('6. Exit');
      print('=' * 60);
      
      stdout.write('Please select an option (1-6): ');
      final input = stdin.readLineSync()?.trim();
      
      switch (input) {
        case '1':
          await _interactiveBackup();
          break;
        case '2':
          await _interactiveDownload();
          break;
        case '3':
          await _interactiveUploadError();
          break;
        case '4':
          await listCloudFiles();
          break;
        case '5':
          showHelp();
          break;
        case '6':
          print('Goodbye!');
          return;
        default:
          print('Invalid option. Please try again.');
      }
    }
  }

  Future<void> _interactiveBackup() async {
    print('\n📦 File Backup');
    print('Please encrypt sensitive data before uploading for security.');
    
    stdout.write('Enter file path to backup: ');
    final filePath = stdin.readLineSync()?.trim();
    
    if (filePath == null || filePath.isEmpty) {
      print('No file path provided.');
      return;
    }
    
    final file = File(filePath);
    if (!file.existsSync()) {
      print('File not found: $filePath');
      return;
    }
    
    print('Starting backup for: $filePath');
    await backupFile(filePath);
  }

  Future<void> _interactiveDownload() async {
    print('\n📥 File Download');
    print('1. From cloud storage');
    print('2. From local links file');
    
    stdout.write('Select source (1-2): ');
    final choice = stdin.readLineSync()?.trim();
    
    switch (choice) {
      case '1':
        await _selectCloudFile();
        break;
      case '2':
        stdout.write('Enter links file path: ');
        final filePath = stdin.readLineSync()?.trim();
        if (filePath != null && filePath.isNotEmpty) {
          await downloadBackup(filePath);
        } else {
          print('No file path provided.');
        }
        break;
      default:
        print('Invalid choice.');
    }
  }

  Future<void> _selectCloudFile() async {
    final cloudFiles = await getCloudFiles();
    
    if (cloudFiles.isEmpty) {
      print('No files found in cloud storage.');
      return;
    }
    
    print('\nAvailable files in cloud storage:');
    for (int i = 0; i < cloudFiles.length; i++) {
      print('${i + 1}. ${cloudFiles[i]}');
    }
    
    stdout.write('Select file number: ');
    final input = stdin.readLineSync()?.trim();
    final index = int.tryParse(input ?? '');
    
    if (index == null || index < 1 || index > cloudFiles.length) {
      print('Invalid selection.');
      return;
    }
    
    final selectedFile = cloudFiles[index - 1];
    final linksFile = '${selectedFile}_links.txt';
    
    print('Selected: $selectedFile');
    print('Note: This feature requires the links file to be available locally.');
    print('Please ensure you have the links file: $linksFile');
    
    stdout.write('Do you have the links file? (y/n): ');
    final hasLinks = stdin.readLineSync()?.trim().toLowerCase();
    
    if (hasLinks == 'y' || hasLinks == 'yes') {
      await downloadBackup(linksFile);
    } else {
      print('Links file is required for download. Please locate it first.');
    }
  }

  Future<void> _interactiveUploadError() async {
    print('\n🔧 Upload Error File');
    
    stdout.write('Enter webhook URL: ');
    final webhookUrl = stdin.readLineSync()?.trim();
    
    if (webhookUrl == null || webhookUrl.isEmpty) {
      print('No webhook URL provided.');
      return;
    }
    
    stdout.write('Enter file path to upload: ');
    final filePath = stdin.readLineSync()?.trim();
    
    if (filePath == null || filePath.isEmpty) {
      print('No file path provided.');
      return;
    }
    
    final file = File(filePath);
    if (!file.existsSync()) {
      print('File not found: $filePath');
      return;
    }
    
    print('Uploading error file: $filePath');
    await uploadFile(webhookUrl, filePath, 1, '$filePath - Error Upload');
  }
}

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('file', abbr: 'f', help: 'File path')
    ..addOption('webhook', abbr: 'w', help: 'Webhook URL')
    ..addFlag('help', abbr: 'h', help: 'Show help message');

  try {
    final storage = DiscordStorage();
    
    // Check token validity
    if (!await storage.checkToken()) {
      print('❌ Bot token is invalid! Please check your config.json file.');
      return;
    }
    
    if (arguments.isEmpty) {
      // Interactive mode
      await storage.runInteractive();
      return;
    }
    
    final command = arguments[0].toLowerCase();
    
    switch (command) {
      case 'help':
      case '--help':
      case '-h':
        DiscordStorage.showHelp();
        break;
        
      case 'backup':
        if (arguments.length < 2) {
          print('❌ Error: File path required for backup command.');
          print('Usage: discordStorage.exe backup <file_path>');
          return;
        }
        print('🔄 Starting backup: ${arguments[1]}');
        await storage.backupFile(arguments[1]);
        break;
        
      case 'download':
        if (arguments.length < 2) {
          print('❌ Error: Links file path required for download command.');
          print('Usage: discordStorage.exe download <links_file>');
          return;
        }
        print('📥 Starting download using: ${arguments[1]}');
        await storage.downloadBackup(arguments[1]);
        break;
        
      case 'upload-error':
        if (arguments.length < 3) {
          print('❌ Error: Webhook URL and file path required for upload-error command.');
          print('Usage: discordStorage.exe upload-error <webhook_url> <file_path>');
          return;
        }
        print('🔧 Uploading error file: ${arguments[2]}');
        await storage.uploadFile(arguments[1], arguments[2], 1, '${arguments[2]} - Error Upload');
        break;
        
      case 'list':
        await storage.listCloudFiles();
        break;
        
      case 'interactive':
        await storage.runInteractive();
        break;
        
      default:
        print('❌ Unknown command: $command');
        print('Use "discordStorage.exe help" for usage information.');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}