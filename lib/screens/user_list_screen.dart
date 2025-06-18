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
  final Map<String, bool> _hasUnreadMap = {};
  final Set<String> _listenersAdded = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    _startMessageListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startMessageListeners() {
    FirebaseFirestore.instance.collection('users').snapshots().listen((
      userSnap,
    ) {
      for (var user in userSnap.docs) {
        final otherUserId = user.id;
        if (otherUserId == widget.currentUserId) continue;

        final ids = [widget.currentUserId, otherUserId]..sort();
        final chatDocId = ids.join('_');

        if (_listenersAdded.contains(chatDocId)) continue;
        _listenersAdded.add(chatDocId);

        FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDocId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots()
            .listen((msgSnap) async {
              if (msgSnap.docs.isEmpty) return;

              final lastMsg = msgSnap.docs.first.data();
              final lastSenderId = lastMsg['senderId'];
              final lastMsgTime = (lastMsg['timestamp'] as Timestamp?)
                  ?.toDate();

              final lastReadsDoc = await FirebaseFirestore.instance
                  .collection('lastReads')
                  .doc(chatDocId)
                  .get();

              final readMap = lastReadsDoc.data() ?? {};
              final lastReadTime = (readMap[widget.currentUserId] as Timestamp?)
                  ?.toDate();

              final isNew =
                  lastMsgTime != null &&
                  (lastReadTime == null || lastMsgTime.isAfter(lastReadTime)) &&
                  lastSenderId != widget.currentUserId;

              setState(() {
                _hasUnreadMap[chatDocId] = isNew;
              });
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LogoutScreen()),
              );
            },
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

              // Safely get user data as Map
              final userData = user.data() as Map<String, dynamic>? ?? {};
              final email = userData['email'] is String
                  ? userData['email'] as String
                  : '';

              final ids = [widget.currentUserId, otherUserId]..sort();
              final chatDocId = ids.join('_');
              final hasNew = _hasUnreadMap[chatDocId] ?? false;

              return _buildUserTile(
                otherUserId,
                email,
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
                        otherUserEmail: email,
                      ),
                    ),
                  );

                  if (mounted) {
                    setState(() {
                      _hasUnreadMap[chatDocId] = false;
                    });
                  }
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

      if (diff.inMinutes < 1) return "Active Now";
      if (diff.inMinutes < 60) return "Last seen ${diff.inMinutes} min ago";
      if (diff.inHours < 24) return "Last seen ${diff.inHours} hr ago";

      return "Last seen on ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}";
    }

    return "Offline";
  }

  Color _getStatusColor(QueryDocumentSnapshot user) {
    return user['isOnline'] ?? false ? Colors.green : Colors.grey;
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
      child: Material(
        elevation: hasNew ? 4 : 1,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: hasNew
                          ? Colors.redAccent
                          : Colors.blueGrey,
                      child: Text(
                        email.isNotEmpty ? email[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (hasNew)
                      const Positioned(
                        right: -2,
                        bottom: -2,
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.mark_email_unread,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: hasNew
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (status == "Active Now")
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            status,
                            style: TextStyle(fontSize: 12, color: statusColor),
                          ),
                        ],
                      ),
                      if (hasNew)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "New message",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
