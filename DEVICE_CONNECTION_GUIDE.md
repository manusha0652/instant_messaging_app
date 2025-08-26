## Device-to-Device Connection Guide

### Method 1: Shared Storage Setup (Easiest)

#### Prerequisites:
1. Two Android devices with your app installed
2. Storage permissions granted on both devices
3. Both devices should have access to external storage

#### Step-by-Step Connection:

1. **Device A Setup:**
   - Open ChatLink app
   - Complete profile setup with phone number and name
   - Go to Profile tab → Show your QR code

2. **Device B Setup:**
   - Open ChatLink app  
   - Complete profile setup with different phone number and name
   - Tap QR scanner button in bottom navigation
   - Scan Device A's QR code
   - Contact will be added automatically

3. **Start Messaging:**
   - Both devices can now see each other in chat list
   - Send messages - they will appear on both devices within 2 seconds
   - Messages are stored in: `/storage/emulated/0/Download/ChatLink/`

#### File Structure Created:
```
/storage/emulated/0/Download/ChatLink/
├── messages_for_+1234567890.json
├── messages_for_+0987654321.json
├── typing_+1234567890.json
└── typing_+0987654321.json
```

### Method 2: WiFi Direct (Advanced)

For same WiFi network communication:

1. **Connect both devices to same WiFi network**
2. **Enable file sharing permissions**
3. **Use network discovery to find other devices**
4. **Exchange message files over local network**

### Method 3: Bluetooth Transfer (Manual)

For occasional sync when devices meet:

1. **Send message files via Bluetooth**
2. **Import received message files**
3. **Messages appear in chat history**

### Troubleshooting:

**Messages not appearing?**
- Check storage permissions
- Verify both devices have access to Download folder
- Ensure QR code scanning completed successfully

**Storage permission errors?**
- Go to Android Settings → Apps → ChatLink → Permissions
- Enable "Files and media" or "Storage" permission

**QR code not scanning?**
- Ensure camera permissions are granted
- Try scanning in good lighting
- Make sure QR code is displayed clearly

### Testing on Emulator:

Since emulators share the same host system, you can:
1. Run two emulator instances
2. Both will access the same shared folder
3. Messages will sync between emulated devices
