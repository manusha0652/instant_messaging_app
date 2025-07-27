import 'package:flutter/material.dart';

class ChatHomePage extends StatelessWidget {
  const ChatHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF162B3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF162B3A),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32), // Replace with your logo
            const SizedBox(width: 8),
            const Text('ChatLink', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search chat or contact',
                filled: true,
                fillColor: const Color(0xFF233A4D),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white54),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ChatItem(
                  avatar: 'assets/user1.png',
                  name: 'Jerome Bell',
                  message: 'Thanks sir!',
                  time: '16:52',
                  isOnline: true,
                ),
                ChatItem(
                  avatar: 'assets/user2.png',
                  name: 'Floyd Miles',
                  message: 'Hello, bro! Can you help me?',
                  time: '13:06',
                  unreadCount: 1,
                ),
                ChatItem(
                  avatar: 'assets/user3.png',
                  name: 'Devon Lane',
                  message: '00:34',
                  time: '11:20',
                  isVoice: true,
                ),
                ChatItem(
                  avatar: 'assets/user4.png',
                  name: 'Annette Black',
                  message: 'Well, good job! 👍',
                  time: 'Yesterday',
                ),
                ChatItem(
                  avatar: 'assets/user5.png',
                  name: 'Darlene Robertson',
                  message: 'Whoaah!! 🤔',
                  time: '4 Feb 2025',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF233A4D),
        selectedItemColor: Colors.tealAccent,
        unselectedItemColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ChatItem extends StatelessWidget {
  final String avatar;
  final String name;
  final String message;
  final String time;
  final bool isOnline;
  final int unreadCount;
  final bool isVoice;

  const ChatItem({
    super.key,
    required this.avatar,
    required this.name,
    required this.message,
    required this.time,
    this.isOnline = false,
    this.unreadCount = 0,
    this.isVoice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF233A4D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundImage: AssetImage(avatar),
                radius: 24,
              ),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isVoice)
                      const Icon(Icons.mic, color: Colors.white54, size: 16),
                    Text(message, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}