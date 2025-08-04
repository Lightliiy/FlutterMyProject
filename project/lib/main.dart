import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

void main() {
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

        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(
            backendBaseUrl: 'http://10.132.251.181:8080',
            userId: null,
          ),
          update: (_, authProvider, notificationProvider) {
            final userId = authProvider.user?.studentId;
            if (notificationProvider == null) {
              return NotificationProvider(
                backendBaseUrl: 'http://10.132.251.181:8080',
                userId: userId,
              )..initialize();
            }
            if (notificationProvider.userId != userId) {
              notificationProvider.userId = userId;
              notificationProvider.initialize();
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
              '/video-call': (context) => VideoCallScreen(),
              '/profile': (context) => ProfileScreen(),
              '/notifications': (context) => NotificationsScreen(),

              // ✅ Chat route with argument extraction
              '/chat': (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is! Chat) {
                  return Scaffold(
                    appBar: AppBar(),
                    body: const Center(child: Text('Invalid chat data')),
                  );
                }
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
