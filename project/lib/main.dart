import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/settings_provider.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(AppEntryPoint());
}

class AppEntryPoint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, authProvider, __) {
            final userId = authProvider.user?.studentId;
            return ChatProvider(userId: userId);
          },
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // ✅ CORRECTED: Ensure the notification provider is updated correctly when the user changes
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            return NotificationProvider(
              backendBaseUrl: 'http://10.192.163.181:8080',
              userId: authProvider.user?.studentId,
            );
          },
          update: (context, authProvider, notificationProvider) {
            final newUserId = authProvider.user?.studentId;
            // Only update if the user ID has actually changed
            if (notificationProvider!.userId != newUserId) {
              notificationProvider.userId = newUserId;
              // The setter on NotificationProvider now handles calling initialize(),
              // so we don't need to call it manually here.
            }
            return notificationProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Student Counseling System',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('sw')],
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

              '/video-call': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
                if (args == null || !args.containsKey('callId') || !args.containsKey('isCaller') || !args.containsKey('currentUserId') || !args.containsKey('otherUserId')) {
                  return Scaffold(
                    appBar: AppBar(),
                    body: const Center(child: Text('Missing video call parameters')),
                  );
                }
                return VideoCallScreen(
                  callId: args['callId'],
                  isCaller: args['isCaller'],
                  currentUserId: args['currentUserId'],
                  otherUserId: args['otherUserId'],
                );
              },

              '/profile': (context) => ProfileScreen(),
              '/notifications': (context) => NotificationsScreen(),

              '/chat': (context) {
                final args = ModalRoute.of(context)!.settings.arguments as Chat;
                return ChatScreen(
                  counselorId: args.counselorId,
                  chatId: args.id,
                  counselorName: args.counselorName,
                );
              },
            },
          );
        },
      ),
    );
  }
}