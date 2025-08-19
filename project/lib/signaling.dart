import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signaling {
  final String callId;
  final String currentUserId;
  final String otherUserId;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  String? _chatId;
  final CollectionReference _chatsCollection =
      FirebaseFirestore.instance.collection('chats');

  Function(MediaStream stream)? onAddRemoteStream;
  Function(String status)? onCallStatusChanged;

  Signaling(
      {required this.callId, required this.currentUserId, required this.otherUserId});

  Future<MediaStream> openUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    });
    _localStream = stream;
    return stream;
  }

  Future<void> initPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };
    final constraints = {
      'mandatory': {},
      'optional': [],
    };

    _peerConnection = await createPeerConnection(config, constraints);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        _peerConnection?.addTrack(track, _localStream!);
      }
    }

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty && onAddRemoteStream != null) {
        onAddRemoteStream!(event.streams[0]);
      }
    };

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) async {
      if (candidate == null) return;

      final candidateData = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      };

      await _firestore.collection('calls').doc(callId).update({
  'iceCandidates.$currentUserId': FieldValue.arrayUnion([candidateData]),
});

    };

    _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {};
    _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {};
  }

  Future<void> makeCall() async {
    if (_peerConnection == null) {
      return;
    }

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    await _firestore.collection('calls').doc(callId).set({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'status': 'calling',
      'iceCandidates': {},
      'answer': null,
    }, SetOptions(merge: true));

    _firestore.collection('calls').doc(callId).snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) {
        onCallStatusChanged?.call('ended');
        hangUp();
        return;
      }
      if (data['answer'] != null && await _peerConnection?.getRemoteDescription() == null) {
        final answer = data['answer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
      if (data['status'] == 'declined' || data['status'] == 'ended' || data['status'] == 'no_answer') {
        onCallStatusChanged?.call(data['status']);
        hangUp();
      }

      if (data['iceCandidates'] != null && data['iceCandidates'][otherUserId] != null) {
        List<dynamic> candidates = data['iceCandidates'][otherUserId];
        if (candidates.isNotEmpty) {
          for (var candidateData in candidates) {
            _peerConnection!.addCandidate(
              RTCIceCandidate(candidateData['candidate'], candidateData['sdpMid'], candidateData['sdpMLineIndex']),
            );
          }
          
          await _firestore.collection('calls').doc(callId).update({
            'iceCandidates.$otherUserId': FieldValue.arrayRemove(candidates),
          });
        }
      }
    });
  }

  Future<void> answerCall() async {
    if (_peerConnection == null) {
      return;
    }

    final callDoc = await _firestore.collection('calls').doc(callId).get();
    final offer = callDoc.data()?['offer'];

    if (offer == null) {
      hangUp();
      return;
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _firestore.collection('calls').doc(callId).snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) {
        onCallStatusChanged?.call('ended');
        hangUp();
        return;
      }

      if (data['iceCandidates'] != null && data['iceCandidates'][otherUserId] != null) {
        List<dynamic> candidates = data['iceCandidates'][otherUserId];
        if (candidates.isNotEmpty) {
          for (var candidateData in candidates) {
            _peerConnection!.addCandidate(
              RTCIceCandidate(candidateData['candidate'], candidateData['sdpMid'], candidateData['sdpMLineIndex']),
            );
          }
        
          await _firestore.collection('calls').doc(callId).update({
            'iceCandidates.$otherUserId': FieldValue.arrayRemove(candidates),
          });
        }
      }
    });

  
    await _firestore.collection('calls').doc(callId).update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'in_call',
    });
  }

  Future<void> hangUp() async {
    try {
      _localStream?.getTracks().forEach((track) => track.dispose());
      await _localStream?.dispose();
      _localStream = null;

      await _peerConnection?.close();
      _peerConnection = null;

      await _firestore.collection('calls').doc(callId).update({'status': 'ended'});
    } catch (e) {}
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    final batch = _firestore.batch();
    final snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}