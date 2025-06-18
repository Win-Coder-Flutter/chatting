import 'dart:async';

import 'package:chatting/screens/chat_screen.dart';
import 'package:chatting/screens/logout_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserListScreen extends StatefulWidget {
  final String currentUserId;

  const UserListScreen({Key? key, required this.currentUserId})
    : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final Set<String> _readChats = {};
  final Map<String, bool> _lastReadsLoaded = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Timer to refresh UI every minute for real-time last seen update
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          // Just rebuild to update last seen text
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LogoutScreen()),
              );
            },
            icon: Icon(Icons.logout),
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

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final otherUserId = user.id;

              if (otherUserId == widget.currentUserId) return const SizedBox();

              final ids = [widget.currentUserId, otherUserId]..sort();
              final chatDocId = ids.join('_');

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatDocId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, msgSnapshot) {
                  bool hasNew = false;

                  if (msgSnapshot.hasData &&
                      msgSnapshot.data!.docs.isNotEmpty) {
                    final lastMsgDoc = msgSnapshot.data!.docs.first;
                    final lastSenderId = lastMsgDoc['senderId'];
                    final lastMsgTime = (lastMsgDoc['timestamp'] as Timestamp?)
                        ?.toDate();

                    if (lastMsgTime != null) {
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('lastReads')
                            .doc(chatDocId)
                            .snapshots(),
                        builder: (context, readSnapshot) {
                          if (readSnapshot.connectionState ==
                                  ConnectionState.active ||
                              readSnapshot.connectionState ==
                                  ConnectionState.done) {
                            _lastReadsLoaded[chatDocId] = true;
                          }

                          if (!_lastReadsLoaded.containsKey(chatDocId)) {
                            // Avoid flicker before lastReads loaded
                            return _buildUserTile(
                              otherUserId,
                              user['email'] ?? '',
                              false,
                              _getStatusText(user),
                              _getStatusColor(user),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PrivateChatScreen(
                                      currentUserId: widget.currentUserId,
                                      otherUserId: otherUserId,
                                      otherUserEmail: user['email'] ?? '',
                                    ),
                                  ),
                                );

                                _readChats.add(chatDocId);
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                setState(() {});
                              },
                            );
                          }

                          final readData =
                              readSnapshot.data?.data()
                                  as Map<String, dynamic>?;

                          final lastReadTime =
                              (readData?[widget.currentUserId] as Timestamp?)
                                  ?.toDate();

                          final isFromOtherUser =
                              lastSenderId != widget.currentUserId;

                          if (_readChats.contains(chatDocId)) {
                            hasNew = false;
                          } else {
                            hasNew =
                                isFromOtherUser &&
                                (lastReadTime == null ||
                                    lastMsgTime.isAfter(lastReadTime));
                          }

                          return _buildUserTile(
                            otherUserId,
                            user['email'] ?? '',
                            hasNew,
                            _getStatusText(user),
                            _getStatusColor(user),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrivateChatScreen(
                                    currentUserId: widget.currentUserId,
                                    otherUserId: otherUserId,
                                    otherUserEmail: user['email'] ?? '',
                                  ),
                                ),
                              );

                              _readChats.add(chatDocId);
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              setState(() {});
                            },
                          );
                        },
                      );
                    }
                  }

                  // No last message, so no unread
                  return _buildUserTile(
                    otherUserId,
                    user['email'] ?? '',
                    false,
                    _getStatusText(user),
                    _getStatusColor(user),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PrivateChatScreen(
                            currentUserId: widget.currentUserId,
                            otherUserId: otherUserId,
                            otherUserEmail: user['email'] ?? '',
                          ),
                        ),
                      );

                      _readChats.add(chatDocId);
                      await Future.delayed(const Duration(milliseconds: 500));
                      setState(() {});
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _getStatusText(QueryDocumentSnapshot user) {
    final isOnline = user['isOnline'] ?? false;
    final lastSeen = (user['lastSeen'] as Timestamp?)?.toDate();

    if (isOnline) return "Active Now";

    if (lastSeen != null) {
      final diff = DateTime.now().difference(lastSeen);

      if (diff.inMinutes < 1) {
        return "Active Now";
      } else if (diff.inMinutes < 60) {
        return "Last seen ${diff.inMinutes} min ago";
      } else if (diff.inHours < 24) {
        return "Last seen ${diff.inHours} hr ago";
      } else {
        return "Last seen on ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}";
      }
    }

    return "Offline";
  }

  Color _getStatusColor(QueryDocumentSnapshot user) {
    final isOnline = user['isOnline'] ?? false;
    if (isOnline) return Colors.green;
    return Colors.grey;
  }

  Widget _buildUserTile(
    String uid,
    String email,
    bool hasNew,
    String status,
    Color statusColor, {
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: hasNew ? Colors.red[50] : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: hasNew ? Colors.red[400] : Colors.blueGrey[400],
          child: Text(
            email.isNotEmpty ? email[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          email,
          style: TextStyle(
            fontWeight: hasNew ? FontWeight.bold : FontWeight.normal,
            color: hasNew ? Colors.black : Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasNew)
              const Text(
                "New message",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Row(
              children: [
                if (status == "Active Now")
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: hasNew
            ? const Icon(Icons.mark_email_unread, color: Colors.red)
            : null,
        onTap: onTap,
      ),
    );
  }
}
