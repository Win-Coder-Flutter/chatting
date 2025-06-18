import 'package:chatting/screens/chat_screen.dart';
import 'package:chatting/screens/logout_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserListScreen extends StatefulWidget {
  final String currentUserId;

  const UserListScreen({super.key, required this.currentUserId});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Users"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogoutScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: users.map((user) {
              final otherUserId = user.id;
              final otherEmail = user['email'] ?? '';

              if (otherUserId == widget.currentUserId) return const SizedBox();

              final chatId = [widget.currentUserId, otherUserId]..sort();
              final chatDocId = chatId.join('_');

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatDocId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, msgSnapshot) {
                  if (!msgSnapshot.hasData || msgSnapshot.data!.docs.isEmpty) {
                    // No messages yet, no unread indicator needed
                    return _buildUserTile(otherUserId, otherEmail, false);
                  }

                  final lastMsgDoc = msgSnapshot.data!.docs.first;
                  final lastMsgTime = (lastMsgDoc['timestamp'] as Timestamp?)
                      ?.toDate();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('lastReads')
                        .doc(chatDocId)
                        .snapshots(),
                    builder: (context, readSnapshot) {
                      if (!readSnapshot.hasData) {
                        return _buildUserTile(otherUserId, otherEmail, false);
                      }

                      final readData =
                          readSnapshot.data!.data() as Map<String, dynamic>?;
                      final lastReadTime =
                          (readData?[widget.currentUserId] as Timestamp?)
                              ?.toDate();

                      final lastSenderId = lastMsgDoc['senderId'];
                      final lastMsgTime =
                          (lastMsgDoc['timestamp'] as Timestamp?)?.toDate();

                      if (lastMsgTime == null || lastReadTime == null) {
                        return _buildUserTile(otherUserId, otherEmail, false);
                      }

                      final isFromOtherUser =
                          lastSenderId != widget.currentUserId;
                      final hasNew =
                          isFromOtherUser && lastMsgTime.isAfter(lastReadTime);

                      return _buildUserTile(otherUserId, otherEmail, hasNew);
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildUserTile(String otherUserId, String otherEmail, bool hasNew) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: hasNew ? Colors.red[50] : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: hasNew ? Colors.red[400] : Colors.blueGrey[400],
          child: Text(
            otherEmail.isNotEmpty ? otherEmail[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          otherEmail,
          style: TextStyle(
            fontWeight: hasNew ? FontWeight.bold : FontWeight.normal,
            color: hasNew ? Colors.black : Colors.grey[800],
          ),
        ),
        subtitle: hasNew
            ? const Text(
                "New message",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
        trailing: hasNew
            ? const Icon(Icons.mark_email_unread, color: Colors.red)
            : null,
        onTap: () async {
          await openChatScreen(otherUserId, otherEmail);
        },
      ),
    );
  }

  Future<void> openChatScreen(String otherUserId, String otherEmail) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(
          currentUserId: widget.currentUserId,
          otherUserId: otherUserId,
          otherUserEmail: otherEmail,
        ),
      ),
    );
    setState(() {});
  }
}
