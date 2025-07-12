// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
//
// class ChatScreen extends StatefulWidget {
//   final String userId;
//   ChatScreen({required this.userId});
//
//   @override
//   _ChatScreenState createState() => _ChatScreenState();
// }
//
// class _ChatScreenState extends State<ChatScreen> {
//   List conversations = [];
//   String? selectedConvId;
//   List messages = [];
//   IO.Socket? socket;
//   final _controller = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     fetchConversations();
//     setupSocket();
//   }
//
//   void setupSocket() {
//     socket = IO.io('http://192.168.0.159:3000', // ← Update with your IP
//         IO.OptionBuilder().setTransports(['websocket']).build());
//
//     socket!.onConnect((_) {
//       print('Socket connected');
//     });
//
//     socket!.on('newMessage', (data) {
//       if (data['conversationId'] == selectedConvId) {
//         setState(() => messages.add(data));
//       }
//     });
//
//     socket!.onDisconnect((_) => print('Socket disconnected'));
//   }
//
//   Future<void> fetchConversations() async {
//     final res = await http.get(Uri.parse(
//         'http://192.168.0.159:3000/api/v1/conversations/my-conversation/${widget.userId}'));
//     final body = jsonDecode(res.body);
//     setState(() => conversations = body['data']);
//   }
//
//   Future<void> selectConversation(String convoId) async {
//     setState(() {
//       selectedConvId = convoId;
//       messages = [];
//     });
//     socket!.emit('join', convoId);
//
//     final res = await http.get(Uri.parse(
//         'http://192.168.0.159:3000/api/v1/messages/$convoId'));
//     final body = jsonDecode(res.body);
//     setState(() => messages = body['data']);
//   }
//
//   Future<void> sendMessage() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty || selectedConvId == null) return;
//
//     final msg = {
//       'conversationId': selectedConvId,
//       'sender': widget.userId,
//       'text': text,
//     };
//
//     await http.post(
//       Uri.parse('http://192.168.0.159:3000/api/v1/messages'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(msg),
//     );
//
//     _controller.clear();
//   }
//
//   @override
//   void dispose() {
//     socket?.disconnect();
//     socket?.dispose();
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Conversation: ${selectedConvId ?? "..."}')),
//       body: Row(
//         children: [
//           // Conversation List
//           Expanded(
//             flex: 1,
//             child: ListView(
//               children: conversations
//                   .map((c) => ListTile(
//                 title: Text("Conv ID: ${c['_id']}"),
//                 onTap: () => selectConversation(c['_id']),
//               ))
//                   .toList(),
//             ),
//           ),
//           // Chat Box
//           Expanded(
//             flex: 2,
//             child: Column(
//               children: [
//                 Expanded(
//                   child: ListView(
//                     children: messages
//                         .map((m) => ListTile(
//                       title: Text(m['text']),
//                       subtitle: Text('From: ${m['sender']}'),
//                     ))
//                         .toList(),
//                   ),
//                 ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _controller,
//                         decoration: InputDecoration(hintText: 'Type a message...'),
//                       ),
//                     ),
//                     IconButton(
//                       icon: Icon(Icons.send),
//                       onPressed: sendMessage,
//                     )
//                   ],
//                 )
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatScreen extends StatefulWidget {
  final String userId;
  ChatScreen({required this.userId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List conversations = [];
  String? selectedConvId;
  List messages = [];

  IO.Socket? socket;
  final _controller = TextEditingController();
  final _messageStreamController = StreamController<List>.broadcast();

  final String baseUrl = 'http://192.168.0.159:3000'; // your server IP

  @override
  void initState() {
    super.initState();
    log('🔄 App started for user: ${widget.userId}');
    fetchConversations();
    setupSocket();
  }

  void setupSocket() {
    log('🔌 Connecting to Socket.IO...');
    socket = IO.io(baseUrl, IO.OptionBuilder().setTransports(['websocket']).build());

    socket!.onConnect((_) {
      log('✅ Socket connected successfully');
    });

    socket!.on('newMessage', (data) {
      log('📥 New message received via socket: $data');
      if (data['conversationId'] == selectedConvId) {
        messages.add(data);
        _messageStreamController.add(List.from(messages));
        log('🟢 Message added to current chat list');
      } else {
        log('⚠️ Message belongs to another conversation');
      }
    });

    socket!.onDisconnect((_) {
      log('🔴 Socket disconnected');
    });
  }

  Future<void> fetchConversations() async {
    log('📡 Fetching conversations for user: ${widget.userId}');
    final res = await http.get(Uri.parse('$baseUrl/api/v1/conversations/my-conversation/${widget.userId}'));
    final body = jsonDecode(res.body);
    setState(() => conversations = body['data']);
    log('✅ Conversations loaded: ${conversations.length}');
  }

  Future<void> selectConversation(String convoId) async {
    log('🔁 Switching to conversation ID: $convoId');
    setState(() {
      selectedConvId = convoId;
      messages = [];
    });

    socket!.emit('join', convoId);
    log('👥 Joined room: $convoId');

    final res = await http.get(Uri.parse('$baseUrl/api/v1/messages/$convoId'));
    final body = jsonDecode(res.body);
    messages = body['data'];
    _messageStreamController.add(List.from(messages));
    log('📨 Loaded ${messages.length} messages for conversation');
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || selectedConvId == null) {
      log('⚠️ Message text is empty or conversation not selected');
      return;
    }

    final msg = {
      'conversationId': selectedConvId,
      'sender': widget.userId,
      'text': text,
    };

    log('📤 Sending message: $msg');

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(msg),
    );

    if (response.statusCode == 201) {
      log('✅ Message sent successfully');
    } else {
      log('❌ Failed to send message: ${response.body}');
    }

    _controller.clear();
  }

  @override
  void dispose() {
    log('🧹 Cleaning up resources...');
    socket?.disconnect();
    socket?.dispose();
    _controller.dispose();
    _messageStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat as: ${widget.userId}')),
      body: Row(
        children: [
          // Left Side: Conversations
          Expanded(
            flex: 1,
            child: ListView(
              children: conversations.map((c) {
                return ListTile(
                  title: Text("Conv ID: ${c['_id']}"),
                  onTap: () => selectConversation(c['_id']),
                );
              }).toList(),
            ),
          ),
          // Right Side: Messages
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List>(
                    stream: _messageStreamController.stream,
                    initialData: messages,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No messages yet.'));
                      }

                      return ListView(
                        children: snapshot.data!.map((m) {
                          return ListTile(
                            title: Text(m['text']),
                            subtitle: Text("From: ${m['sender']}"),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(hintText: 'Type a message...'),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: sendMessage,
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
