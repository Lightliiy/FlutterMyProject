import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/counselors/counselor_list_screen.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/video_call_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/notifications/notifications_screen.dart';

import 'utils/theme.dart';

void main() {
  runApp(AppEntryPoint());
}

class AppEntryPoint extends StatefulWidget {
  @override
  _AppEntryPointState createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  String? studentId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentId();
  }

  Future<void> _loadStudentId() async {
    final authProvider = AuthProvider();
    final id = await authProvider.getStudentId();
    setState(() {
      studentId = id;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),

        if (studentId != null)
          ChangeNotifierProvider(
            create: (_) => NotificationProvider(
              backendBaseUrl: 'https://yourbackend.com/api', // Your backend URL here
              userId: studentId!,
            )..initialize(),
          ),
      ],
      child: MaterialApp(
        title: 'Student Counseling System',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/dashboard': (context) => DashboardScreen(),
          '/counselors': (context) => CounselorListScreen(),
          '/booking': (context) => BookingScreen(),
          '/chats': (context) => ChatListScreen(),
          '/chat': (context) => ChatScreen(),
          '/video-call': (context) => VideoCallScreen(),
          '/profile': (context) => ProfileScreen(),
          '/notifications': (context) => NotificationsScreen(),
        },
      ),
    );
  }
}
