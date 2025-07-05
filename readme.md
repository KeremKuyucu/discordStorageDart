# Discord Storage CLI

A powerful command-line tool written in Dart that allows you to use Discord as a cloud storage solution for large files. The tool splits large files into chunks and uploads them to Discord channels, providing a free alternative backup solution.

## ⚠️ Important Disclaimer

This tool is intended for **personal backup purposes only**. While it provides a convenient way to store files, it should **never be your only backup solution**. As they say: "If your data is not in three places, it does not exist."

## 🚀 Features

- **Large File Support**: Automatically splits files larger than 10MB into manageable chunks
- **Resume Capability**: Can resume interrupted uploads from where they left off
- **File Integrity**: Uses SHA-256 hashing to verify file integrity during download
- **Interactive Mode**: User-friendly menu-driven interface
- **Command Line Interface**: Supports direct command execution
- **Progress Tracking**: Real-time progress bars for upload/download operations
- **Error Recovery**: Built-in error handling and recovery mechanisms

## 📋 Requirements

- Dart SDK (latest stable version)
- Discord Bot Token
- Discord Server with appropriate permissions

### Required Dart Packages

```yaml
dependencies:
  args: ^2.4.2
  crypto: ^3.0.3
  http: ^1.1.0
  path: ^1.8.3
```

## 🛠️ Installation

1. **Clone or download the source code**
2. **Install Dart SDK** from [dart.dev](https://dart.dev/get-dart)
3. **Install dependencies**:
   ```bash
   dart pub get
   ```
4. **Compile the application** (optional):
   ```bash
   dart compile exe discordStorage.dart -o discordStorage.exe
   ```

## ⚙️ Configuration

### 1. Create a Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Go to the "Bot" section
4. Create a bot and copy the token
5. Enable necessary permissions:
   - Send Messages
   - Manage Channels
   - Manage Webhooks
   - Read Message History

### 2. Set Up Your Discord Server

1. Create a category in your Discord server for file storage
2. Copy the category ID (Enable Developer Mode in Discord settings)
3. Copy your server (guild) ID
4. Invite the bot to your server with the required permissions

### 3. Configure the Application

On first run, the application will create a `config.json` file. Edit it with your Discord credentials:

```json
{
  "BOT_TOKEN": "your_bot_token_here",
  "guild_id": "your_server_id_here",
  "category_id": "your_category_id_here"
}
```

## 💻 Usage

### Interactive Mode (Recommended)

Simply run the program without arguments to start interactive mode:

```bash
dart run discordStorage.dart
# or if compiled:
./discordStorage.exe
```

### Command Line Interface

#### Backup a File
```bash
dart run discordStorage.dart backup "path/to/your/file.zip"
```

#### Download a File
```bash
dart run discordStorage.dart download "file_links.txt"
```

#### List Cloud Files
```bash
dart run discordStorage.dart list
```

#### Upload Error File (Recovery)
```bash
dart run discordStorage.dart upload-error "webhook_url" "file_path"
```

#### Show Help
```bash
dart run discordStorage.dart help
```

## 📁 File Structure

After backing up a file, you'll find:
- `filename_links.txt` - Contains metadata and download links
- `postlog.txt` - Upload logs and responses
- `temp/` directory - Temporary files during processing (auto-cleaned)

## 🔧 How It Works

### Upload Process
1. **File Analysis**: Calculates file hash and determines required parts
2. **Channel Creation**: Creates a dedicated Discord channel for the file
3. **File Splitting**: Divides large files into ~10MB chunks
4. **Sequential Upload**: Uploads each part with progress tracking
5. **Metadata Storage**: Saves download links and file information
6. **Resume Support**: Can continue from the last uploaded part if interrupted

### Download Process
1. **Metadata Reading**: Reads the links file to get file information
2. **Part Download**: Downloads each file part from Discord
3. **File Reconstruction**: Merges parts back into the original file
4. **Integrity Verification**: Compares SHA-256 hashes to ensure file integrity

## 🛡️ Security Recommendations

- **Encrypt sensitive files** before uploading
- **Don't store passwords** or private keys
- **Use this as a secondary backup** method only
- **Keep your bot token secure** and never share it
- **Don't write messages** in the created storage channels

## 🚫 Limitations

- **File size**: Limited by Discord's storage (though practically unlimited for personal use)
- **Upload speed**: Depends on Discord's rate limits
- **Bot dependency**: Requires a Discord bot and server
- **No file browsing**: Files are stored in Discord but not easily browsable

## 🔍 Troubleshooting

### Common Issues

**"Bot token is invalid"**
- Check your `config.json` file
- Ensure the bot token is correct
- Verify bot permissions in Discord

**"Failed to create channel"**
- Check if the bot has "Manage Channels" permission
- Verify the guild ID and category ID are correct
- Ensure the bot is in the correct server

**"Upload failed"**
- Check internet connection
- Verify Discord server status
- Try uploading a smaller file first

**"File hash mismatch"**
- The downloaded file may be corrupted
- Try downloading again
- Check if all parts were downloaded correctly

### Getting Help

If you encounter issues:
1. Check the `postlog.txt` file for detailed error messages
2. Verify your Discord bot permissions
3. Ensure your `config.json` is properly configured
4. Try running in interactive mode for better error messages

## 🤝 Contributing

Feel free to contribute to this project by:
- Reporting bugs
- Suggesting new features
- Improving documentation
- Submitting pull requests

## 📄 License

This project is provided as-is for educational and personal use. Please respect Discord's Terms of Service and use responsibly.

## ⚠️ Legal Notice

This tool is not affiliated with Discord Inc. Use at your own risk and ensure compliance with Discord's Terms of Service. The authors are not responsible for any data loss or account restrictions that may occur from using this tool.

---

**Remember: This is a backup tool, not a replacement for proper data storage solutions. Always maintain multiple backups of important data.**