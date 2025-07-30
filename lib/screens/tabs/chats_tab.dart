import 'package:flutter/material.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  // Sample chat data matching your design
  final List<Map<String, dynamic>> chats = const [
    {
      'name': 'Jerome Bell',
      'message': 'Thanks sir!',
      'time': '16:52',
      'avatar': 'JB',
      'hasMessage': true,
      'isRead': true,
    },
    {
      'name': 'Floyd Miles',
      'message': 'Hello, bro! Can you help me?',
      'time': '13:06',
      'avatar': 'FM',
      'hasMessage': false,
      'isRead': false,
      'unreadCount': 1,
    },
    {
      'name': 'Devon Lane',
      'message': '00:34',
      'time': '11:20',
      'avatar': 'DL',
      'hasMessage': false,
      'isRead': true,
      'isVoiceMessage': true,
    },
    {
      'name': 'Annette Black',
      'message': 'Well, good job! 👍',
      'time': 'Yesterday',
      'avatar': 'AB',
      'hasMessage': true,
      'isRead': true,
    },
    {
      'name': 'Darlene Robertson',
      'message': 'Whoaah! 😄',
      'time': '4 Feb 2025',
      'avatar': 'DR',
      'hasMessage': true,
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A5F),
      body: SafeArea(
        child: Column(
          children: [
            // Header section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Top row with logo and menu
                  Row(
                    children: [
                      // ChatLink logo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            // Main chat bubble
                            Positioned(
                              top: 9,
                              left: 9,
                              child: Container(
                                width: 22,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            // Chat tail dots
                            Positioned(
                              bottom: 11,
                              left: 11,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // ChatLink text
                      const Text(
                        'ChatLink',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      // Menu button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.menu,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Search bar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A4A6B),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search chat or contact',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Chat list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A4A6B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF00A8FF),
                          backgroundImage: NetworkImage(
                            'https://api.dicebear.com/7.x/avataaars/png?seed=${chat['avatar']}&backgroundColor=00a8ff',
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Chat info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                chat['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Message/Status
                              Row(
                                children: [
                                  if (chat['isVoiceMessage'] == true)
                                    const Icon(
                                      Icons.mic,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  if (chat['isVoiceMessage'] == true)
                                    const SizedBox(width: 4),
                                  if (chat['isRead'] && chat['hasMessage'])
                                    const Icon(
                                      Icons.done_all,
                                      color: Color(0xFF00A8FF),
                                      size: 16,
                                    ),
                                  if (chat['isRead'] && chat['hasMessage'])
                                    const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      chat['message'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Time and status
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              chat['time'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Status indicators
                            if (chat['unreadCount'] != null)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00A8FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    chat['unreadCount'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                            else if (chat['isRead'] && chat['hasMessage'])
                              const Icon(
                                Icons.done_all,
                                color: Color(0xFF00A8FF),
                                size: 16,
                              )
                            else if (chat['isVoiceMessage'] == true)
                              Icon(
                                Icons.volume_up,
                                color: Colors.white.withOpacity(0.5),
                                size: 16,
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
