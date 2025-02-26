import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: WebSocketScreen(),
    );
  }
}

class WebSocketScreen extends StatefulWidget {
  @override
  _WebSocketScreenState createState() => _WebSocketScreenState();
  //test
}

class _WebSocketScreenState extends State<WebSocketScreen> {
  WebSocketChannel? channel;
  List<String> messages = [];
  String status = "offline";
  String token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkcml2ZXJfaWQiOiJjOTI5NTY0ZS1hNWY4LTQ4MjYtYWE0OC01ZDEwY2QxY2VmNTkiLCJleHAiOiIyMDI1LTAyLTI3VDIwOjI5OjA2LjA3MDUxNDc3WiJ9.CUFI2JKJ2vSgl9nKl9Me-LK3S8KdZUeH8dI1V7GSHqU";
  String driverServiceDomain = "http://192.168.63.136:3002";
  String websocketProxyDomain = "ws://192.168.63.136:8080";
  Timer? reconnectTimer;


  @override
  void initState() {
    super.initState();
    fetchInitialStatus();
  }

  void fetchInitialStatus() async {
    Uri url = Uri.parse('$driverServiceDomain/drivers/status');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          status = data['status'] ?? "offline";
        });

        if (data['status'] == 'free' && channel == null) {
          connectWebSocket();
        }
      } else {
        log("HTTP error: ${response.statusCode} - ${response.body}", name: "HTTP");
      }
    } catch (e, stackTrace) {
      log("Network error: $e", name: "Network", error: e, stackTrace: stackTrace);
    }
  }

  void connectWebSocket() {
    log("Connecting to WebSocket...", name: "WebSocket");

    channel = IOWebSocketChannel.connect('$websocketProxyDomain/connections/join?token=$token');

    channel?.stream.listen(
          (message) {
        log("Message received: $message", name: "WebSocket");

        setState(() {
          messages.add(message);
        });
      },
      onError: (error) {
        log("WebSocket error: $error", name: "WebSocket", error: error);
        reconnect();
      },
      onDone: () {
        log("The WebSocket connection is closed. Reconnecting...", name: "WebSocket");
        reconnect();
      },
    );
  }

  void reconnect() {
    if (reconnectTimer != null && reconnectTimer!.isActive) return;

    reconnectTimer = Timer(Duration(seconds: 5), () {
      if (status == 'free') {
        connectWebSocket();
      }
    });
  }

  void updateStatus(String newStatus) async {
    setState(() {
      status = newStatus;
    });

    Uri? url;

    if (newStatus == 'free') {
      url = Uri.parse('$driverServiceDomain/drivers/set-free');
    } else if (newStatus == 'offline') {
      url = Uri.parse('$driverServiceDomain/drivers/set-offline');
    }

    if (url != null) {
      try {
        final response = await http.patch(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          log("Status successfully updated: $newStatus", name: "HTTP");

          if (channel == null) {
            connectWebSocket();
          }
        } else {
          log("Failed to update status: ${response.body}", name: "HTTP", level: 900);
        }
      } catch (e) {
        log("Network error: $e", name: "HTTP", error: e, level: 1000);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController controller = TextEditingController();

    return Scaffold(
      body: Padding(
          padding: EdgeInsets.all(20.0),
      child: Padding(
          padding: EdgeInsets.only(top: 16.0),
        child: Column(
          children: [
            // Верхняя панель с текущим статусом и кнопками
            Container(
              height: 60,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Статус: $status',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: status == "offline" ? null : () => updateStatus("offline"),
                        child: Text('offline'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: status == "free" ? null : () => updateStatus("free"),
                        child: Text('free'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Список сообщений
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(messages[index]),
                ),
              ),
            ),
          ],
        ),
      )
      )
    );
  }
}
