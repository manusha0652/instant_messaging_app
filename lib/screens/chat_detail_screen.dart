import 'package:flutter/material.dart';

class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232A32),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232A32),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage('assets/user2.png'),
              radius: 18,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Floyd Miles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Online', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call, color: Colors.tealAccent), onPressed: () {}),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.tealAccent), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // Date label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Februari 2025', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 12),
          // Image message bubble
          _ImageMessageBubble(),
          // Reply bubble
          _ReplyMessageBubble(),
          // Unread chat indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.tealAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('1 Unread Chat', style: TextStyle(color: Color(0xFF232A32), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          // Text message bubble
          _TextMessageBubble(),
          const Spacer(),
          // Message input field
          _MessageInputField(),
        ],
      ),
    );
  }
}

// Image message bubble widget
class _ImageMessageBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C333B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/chat_image.jpg',
                height: 160,
                width: 320,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Come join here bro! ☕', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(Icons.thumb_up, color: Colors.amber, size: 18),
                SizedBox(width: 4),
                Text('1', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Spacer(),
                Text('17:24', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Reply message bubble widget
class _ReplyMessageBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF233A4D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: AssetImage('assets/user2.png'),
                  radius: 14,
                ),
                const SizedBox(width: 8),
                const Text('Floyd Miles', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 4),
                const Text('☕', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Come join here bro! ☕', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('Wait, I\'ll be there soon!!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text('17:40', style: TextStyle(color: Colors.white38, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.done_all, color: Colors.white54, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Text message bubble widget
class _TextMessageBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C333B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Hello, bro! Can you help me?', style: TextStyle(color: Colors.white)),
            SizedBox(height: 4),
            Text('13:06', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// Message input field widget
class _MessageInputField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C333B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type message..',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white54),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}