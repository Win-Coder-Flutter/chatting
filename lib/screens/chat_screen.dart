import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivateChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUserEmail;

  const PrivateChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserEmail,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final FocusNode focusNode = FocusNode();
  Timer? statusTimer;

  String get chatId {
    final ids = [widget.currentUserId, widget.otherUserId];
    ids.sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    markChatAsRead();
    setUserOnlineStatus(true);
    startStatusUpdateTimer();

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), scrollToBottom);
      }
    });
  }

  void startStatusUpdateTimer() {
    statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {}); // forces app bar status refresh
    });
  }

  void setUserOnlineStatus(bool isOnline) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .set({
          'isOnline': isOnline,
          if (!isOnline) 'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> markChatAsRead() async {
    await FirebaseFirestore.instance.collection('lastReads').doc(chatId).set({
      widget.currentUserId: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void sendMessage() async {
    final text = msgCtrl.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': widget.currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });

    msgCtrl.clear();
    scrollToBottom();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setUserOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      setUserOnlineStatus(false);
    }
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    setUserOnlineStatus(false);
    msgCtrl.dispose();
    scrollCtrl.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        markChatAsRead();
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.otherUserId)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;

              final isOnline = userData?['isOnline'] ?? false;
              final lastSeen = (userData?['lastSeen'] as Timestamp?)?.toDate();

              String statusText = 'Loading...';
              if (isOnline) {
                statusText = 'Active Now';
              } else if (lastSeen != null) {
                final diff = DateTime.now().difference(lastSeen);
                if (diff.inMinutes < 1) {
                  statusText = 'Active Now';
                } else if (diff.inMinutes < 60) {
                  statusText = 'Last seen ${diff.inMinutes} min ago';
                } else if (diff.inHours < 24) {
                  statusText = 'Last seen ${diff.inHours} hr ago';
                } else {
                  statusText =
                      'Last seen on ${lastSeen.year}/${lastSeen.month.toString().padLeft(2, '0')}/${lastSeen.day.toString().padLeft(2, '0')}';
                }
              } else {
                statusText = 'Offline';
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserEmail,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Row(
                    children: [
                      if (statusText == 'Active Now')
                        Container(
                          margin: const EdgeInsets.only(right: 6, top: 2),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(statusText, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    scrollToBottom();
                  });

                  return ListView.builder(
                    controller: scrollCtrl,
                    itemCount: docs.length,
                    itemBuilder: (_, index) {
                      final msg = docs[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == widget.currentUserId;
                      final isLast = index == docs.length - 1;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Padding(
                          padding: isLast
                              ? const EdgeInsets.only(bottom: 40)
                              : EdgeInsets.zero,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 10,
                            ),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue[100]
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(msg['text']),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(msg['timestamp']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgCtrl,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final time = TimeOfDay.fromDateTime(date);
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}"
          "  ${time.hourOfPeriod.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} "
          "${time.period == DayPeriod.am ? 'AM' : 'PM'}";
    }
    return '';
  }
}
