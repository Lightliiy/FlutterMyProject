// lib/screens/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:project/signaling.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String currentUserId;
  final String otherUserId;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Signaling? _signaling;
  bool _isLoading = true;
  bool _isMuted = false;
  bool _isVideoOn = true;

  @override
  void initState() {
    super.initState();
    initRenderers();
    _connectToCall();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _connectToCall() async {
    await [Permission.microphone, Permission.camera].request();

    _signaling = Signaling(
      callId: widget.callId,
      currentUserId: widget.currentUserId,
      otherUserId: widget.otherUserId,
    );

    _signaling!.onAddRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    };
    
    _signaling!.onCallStatusChanged = (status) {
      if (mounted) {
        if (status == 'declined' || status == 'ended' || status == 'no_answer') {
          _handleCallEnd();
        }
      }
    };

    try {
      final localStream = await _signaling!.openUserMedia();
      _localRenderer.srcObject = localStream;
      await _signaling!.initPeerConnection();

      if (widget.isCaller) {
        await _signaling!.makeCall();
      } else {
        await _signaling!.answerCall();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _handleCallEnd();
    }
  }

  void _handleCallEnd() {
    _signaling?.hangUp();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _toggleAudio() {
    final audioTrack = _localRenderer.srcObject?.getAudioTracks().first;
    if (audioTrack != null) {
      audioTrack.enabled = !_isMuted;
      setState(() => _isMuted = !_isMuted);
    }
  }

  void _toggleVideo() {
    final videoTrack = _localRenderer.srcObject?.getVideoTracks().first;
    if (videoTrack != null) {
      videoTrack.enabled = !_isVideoOn;
      setState(() => _isVideoOn = !_isVideoOn);
    }
  }

  @override
  void dispose() {
    _signaling?.hangUp();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                Positioned.fill(
                  child: _remoteRenderer.srcObject != null
                      ? RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Center(
                          child: Text(
                            widget.isCaller ? 'Calling...' : 'Connecting...',
                            style: const TextStyle(color: Colors.white, fontSize: 24),
                          ),
                        ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: RTCVideoView(
                        _localRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
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
                        heroTag: 'audioBtn',
                        onPressed: _toggleAudio,
                        backgroundColor: _isMuted ? Colors.red : Colors.white24,
                        child: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                      ),
                      FloatingActionButton(
                        heroTag: 'hangUpBtn',
                        onPressed: _handleCallEnd,
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end, color: Colors.white),
                      ),
                      FloatingActionButton(
                        heroTag: 'videoBtn',
                        onPressed: _toggleVideo,
                        backgroundColor: _isVideoOn ? Colors.white24 : Colors.red,
                        child: Icon(_isVideoOn ? Icons.videocam : Icons.videocam_off, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}