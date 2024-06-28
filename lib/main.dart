import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // Add this import
import 'package:telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// Add this function for background message handling
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print("Handling a background message: ${message.messageId}");
}

onBackgroundMessage(SmsMessage message) {
  // debugPrint("onBackgroundMessage called");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String _message = "";
  String _fcmToken = ""; // Added to store FCM token
  final telephony = Telephony.instance;
  late final FirebaseMessaging _firebaseMessaging;

  @override
  void initState() {
    super.initState();
    _firebaseMessaging =
        FirebaseMessaging.instance; // Initialize Firebase Messaging
    initPlatformState();
    _initializeFirebaseMessaging();
  }

  void _initializeFirebaseMessaging() {
    _firebaseMessaging.getToken().then((String? token) {
      setState(() {
        _fcmToken = token ?? "";
      });
      _sendTokenToServer(token ?? ""); // Save token to server
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // print('Got a message whilst in the foreground!');
      // print('Message data: ${message.data}');

      if (message.notification != null) {
        // print('Message also contained a notification: ${message.notification}');
        _showNotification(
            message.notification?.title, message.notification?.body);
        if (message.data.containsKey('message')) {
          sendSms(message.data['message']);
        }
      }
    });
  }

  void _showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your_channel_id', 'your_channel_name',
            channelDescription: 'your_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  void _sendTokenToServer(String token) async {
    // Replace with your server URL
    const String serverUrl = 'http://sipbazar.com.np/api/fcm-token';

    // Set up the request
    final response = await http.post(
      Uri.parse(serverUrl),
      headers: <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'secret_key': '!sipbazar@2024!',
        'fcm_token': token,
      }),
    );

    // Handle the response
    if (response.statusCode == 200) {
      // If the server returns a 200 OK response, parse the JSON
      // print('Token saved successfully');
    } else {
      // If the server did not return a 200 OK response,
      // throw an exception.
      // print('Failed to save token: ${response.statusCode}');
    }
  }

  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.body ?? "Error reading message body.";
    });
  }

  onSendStatus(SendStatus status) {
    setState(() {
      _message = status == SendStatus.SENT ? "sent" : "delivered";
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.

    final bool? result = await telephony.requestPhoneAndSmsPermissions;

    if (result != null && result) {
      telephony.listenIncomingSms(
          onNewMessage: onMessage, onBackgroundMessage: onBackgroundMessage);
    }

    if (!mounted) return;
  }

  // Function to send SMS
  void sendSms(String message) async {
    try {
      await telephony.sendSms(
        to: "9800930444",
        message: message,
        statusListener: onSendStatus,
      );
    } catch (e) {
      setState(() {
        _message = "Failed to send SMS: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(child: Text("Latest received SMS: $_message")),
            Center(
              child: Text("FCM token: $_fcmToken"),
            ),
            const SizedBox(
                height: 20), // Add some space between the text and button
            ElevatedButton(
              onPressed: () => sendSms("This is test"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Button color
              ),
              child: const Text(
                'Send SMS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
