import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF800080),
              Color(0xFF4B0082),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Chat',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16.0),
                          children: const [
                            ChatBubble(
                              message: 'Hello, I need to schedule an appointment for my dog.',
                              sender: 'Client',
                              time: '03:00 PM',
                            ),
                            ChatBubble(
                              message: 'Sure, let me check the vet’s availability.',
                              sender: 'Secretary',
                              time: '03:02 PM',
                            ),
                            ChatBubble(
                              message: 'I’m available at 4:00 PM today. Does that work?',
                              sender: 'Vet',
                              time: '03:03 PM',
                            ),
                            ChatBubble(
                              message: 'Yes, that works! Thank you!',
                              sender: 'Client',
                              time: '03:04 PM',
                            ),
                            ChatBubble(
                              message: 'I’ve booked it for you. See you at 4:00 PM!',
                              sender: 'Secretary',
                              time: '03:05 PM',
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add, color: Color(0xFF800080)),
                              onPressed: () {},
                            ),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Type a message...',
                                  hintStyle: GoogleFonts.poppins(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                ),
                                style: GoogleFonts.poppins(),
                              ),
                            ),

                            IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFF800080)),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final String sender;
  final String time;

  const ChatBubble({
    super.key,
    required this.message,
    required this.sender,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    // Define profile image URLs and styling based on sender
    String profileImageUrl;
    Decoration bubbleDecoration;
    TextStyle textStyle;

    switch (sender) {
      case 'Client':
        profileImageUrl = 'https://www.georgetown.edu/wp-content/uploads/2022/02/Jkramerheadshot-scaled-e1645036825432-1050x1050-c-default.jpg';
        bubbleDecoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF800080),
              Color(0xFF4B0082),
            ],
          ),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
        textStyle = GoogleFonts.poppins(fontSize: 16, color: Colors.white);
        break;
      case 'Vet':
        profileImageUrl = 'https://t3.ftcdn.net/jpg/02/60/00/72/360_F_260007203_oIHxD9nIdYnN69zBcYajybIJ4m2kVoYA.jpg';
        bubbleDecoration = BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
        textStyle = GoogleFonts.poppins(fontSize: 16, color: Colors.black87);
        break;
      case 'Secretary':
        profileImageUrl = 'https://img.freepik.com/free-photo/close-up-veterinarian-taking-care-cat_23-2149100172.jpg';
        bubbleDecoration = BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
        textStyle = GoogleFonts.poppins(fontSize: 16, color: Colors.black87);
        break;
      default:
        profileImageUrl = '';
        bubbleDecoration = BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
        textStyle = GoogleFonts.poppins(fontSize: 16, color: Colors.black87);
    }

    // Align Client on the left, Vet and Secretary on the right
    Alignment alignment = sender == 'Client' ? Alignment.centerLeft : Alignment.centerRight;
    CrossAxisAlignment crossAlignment = sender == 'Client' ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisAlignment: sender == 'Client' ? MainAxisAlignment.start : MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile picture
            if (sender == 'Client')
              CircleAvatar(
                radius: 20,
                backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? const Icon(Icons.person, size: 20, color: Colors.grey)
                    : null,
              ),
            if (sender == 'Client') const SizedBox(width: 8),
            Column(
              crossAxisAlignment: crossAlignment,
              children: [
                Text(
                  '$sender - $time',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  decoration: bubbleDecoration,
                  child: Text(
                    message,
                    style: textStyle,
                  ),
                ),
              ],
            ),
            if (sender != 'Client') const SizedBox(width: 8),
            if (sender != 'Client')
              CircleAvatar(
                radius: 20,
                backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? const Icon(Icons.person, size: 20, color: Colors.grey)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}