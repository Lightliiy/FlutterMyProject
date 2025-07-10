import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'dart:async';

const String appId = "48d3121e7f3a46e6ba5c0aba0862d209";
const String token = "6bb03ba65f354601a5689fe8c2227d71"; // Fetch dynamically in production
const String channelName = "testchannel";

class VideoCallScreen extends StatefulWidget {
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  bool _isEngineReady = false;
  bool _isJoined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerOn = false;
  int _callDuration = 0;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() {
          _isJoined = true;
          _startCallTimer();
        });
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() {
          _remoteUid = remoteUid;
        });
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() {
          _remoteUid = null;
        });
      },
    ));

    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    setState(() {
      _isEngineReady = true;
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _callDuration++);
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    Navigator.pop(context);
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      );
    } else {
      return const Center(
        child: Text(
          'Waiting for remote user...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEngineReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _renderRemoteVideo()),
            Positioned(
              top: 40,
              right: 20,
              child: SizedBox(
                width: 120,
                height: 160,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: () {
                      _engine.muteLocalAudioStream(!_isMuted);
                      setState(() => _isMuted = !_isMuted);
                    },
                    backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                  ),
                  FloatingActionButton(
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      _engine.muteLocalVideoStream(!_isVideoOn);
                      setState(() => _isVideoOn = !_isVideoOn);
                    },
                    backgroundColor: _isVideoOn ? Colors.white24 : Colors.red,
                    child: Icon(_isVideoOn ? Icons.videocam : Icons.videocam_off, color: Colors.white),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      _engine.setEnableSpeakerphone(!_isSpeakerOn);
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    },
                    backgroundColor: _isSpeakerOn ? Colors.blue : Colors.white24,
                    child: Icon(_isSpeakerOn ? Icons.volume_up : Icons.volume_down, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
