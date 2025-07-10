class AppConstants {
  static const String baseUrl = 'http://10.8.5.62:8080'; // Your server IP and port

  static const String apiEndpointPrefix = '/api'; // API base path

  // Auth Endpoints (only paths, no base URL here)
  static const String loginEndpoint = '$apiEndpointPrefix/auth/login';
  static const String registerEndpoint = '$apiEndpointPrefix/auth/register';

  // Chat Endpoints
  static const String chatRoomsEndpoint = '$apiEndpointPrefix/chats';
  static const String chatMessagesEndpoint = '$apiEndpointPrefix/chats'; // append /{chatRoomId}/messages when used
  static const String joinGroupEndpoint = '$apiEndpointPrefix/groups/join';
  static const String counselorsEndpoint = '$apiEndpointPrefix/counselors';
  static const String createPrivateChatEndpoint = '$apiEndpointPrefix/chats/private';

  // Helper methods to get full URLs
  static String getLoginUrl() => '$baseUrl$loginEndpoint';
  static String getRegisterUrl() => '$baseUrl$registerEndpoint';
  static String getChatRoomsUrl() => '$baseUrl$chatRoomsEndpoint';
  static String getChatMessagesUrl(String chatRoomId) => '$baseUrl$chatMessagesEndpoint/$chatRoomId/messages';
}
