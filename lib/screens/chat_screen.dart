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

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController msgCtrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final FocusNode focusNode = FocusNode();

  String get chatId {
    final ids = [widget.currentUserId, widget.otherUserId];
    ids.sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    markChatAsRead();

    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), scrollToBottom);
      }
    });
  }

  void markChatAsRead() {
    FirebaseFirestore.instance.collection('lastReads').doc(chatId).set({
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
  void dispose() {
    msgCtrl.dispose();
    scrollCtrl.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        markChatAsRead(); // Mark as read on back
        return true; // Allow pop
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(widget.otherUserEmail)),
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
      return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} "
          "${time.hourOfPeriod.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} "
          "${time.period == DayPeriod.am ? 'AM' : 'PM'}";
    }
    return '';
  }
}
