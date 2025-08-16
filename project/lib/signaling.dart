// lib/signaling.dart
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
  final CollectionReference _chatsCollection = FirebaseFirestore.instance.collection('chats');

  Function(MediaStream stream)? onAddRemoteStream;
  Function(String status)? onCallStatusChanged;

  Signaling({required this.callId, required this.currentUserId, required this.otherUserId});

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

      await _firestore
          .collection('calls')
          .doc(callId)
          .collection('candidates')
          .doc(currentUserId)
          .collection('ice')
          .add(candidateData);
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

    await _firestore.collection('calls').doc(callId).update({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
    });

    _firestore.collection('calls').doc(callId).snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data != null && data['answer'] != null && await _peerConnection?.getRemoteDescription() == null) {
        final answer = data['answer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
      if (data != null && (data['status'] == 'declined' || data['status'] == 'ended' || data['status'] == 'no_answer')) {
        onCallStatusChanged?.call(data['status']);
        hangUp();
      }
    });

    _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .doc(otherUserId)
        .collection('ice')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final data = docChange.doc.data();
          if (data != null) {
            _peerConnection!.addCandidate(
              RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
            );
          }
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

    await _firestore.collection('calls').doc(callId).update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
      'status': 'in_call',
    });

    _firestore
        .collection('calls')
        .doc(callId)
        .collection('candidates')
        .doc(otherUserId)
        .collection('ice')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final data = docChange.doc.data();
          if (data != null) {
            _peerConnection!.addCandidate(
              RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
            );
          }
        }
      }
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

      final callerIceCollection = _firestore.collection('calls').doc(callId).collection('candidates').doc(currentUserId).collection('ice');
      final receiverIceCollection = _firestore.collection('calls').doc(callId).collection('candidates').doc(otherUserId).collection('ice');

      await _deleteCollection(callerIceCollection);
      await _deleteCollection(receiverIceCollection);

      await _firestore.collection('calls').doc(callId).collection('candidates').doc(currentUserId).delete();
      await _firestore.collection('calls').doc(callId).collection('candidates').doc(otherUserId).delete();

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

  Future<String> getOrCreateChatId() async {
    final chatQuery = await _chatsCollection
        .where('counselorId', isEqualTo: currentUserId)
        .where('studentId', isEqualTo: otherUserId)
        .limit(1)
        .get();

    if (chatQuery.docs.isNotEmpty) {
      _chatId = chatQuery.docs.first.id;
      return _chatId!;
    } else {
      final newChatDoc = await _chatsCollection.add({
        'counselorId': currentUserId,
        'studentId': otherUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _chatId = newChatDoc.id;
      return _chatId!;
    }
  }
  
  Future<void> sendMessage(String content) async {
    if (_chatId == null) {
      await getOrCreateChatId();
    }
    
    final messageCollection = _chatsCollection.doc(_chatId!).collection('messages');
    
    await messageCollection.add({
      'senderId': currentUserId,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> get messagesStream {
    if (_chatId == null) {
      throw Exception('Chat ID is not set. Call getOrCreateChatId() first.');
    }
    return _chatsCollection
        .doc(_chatId!)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> deleteChat() async {
    if (_chatId == null) return;
    
    final messages = await _chatsCollection.doc(_chatId).collection('messages').get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await _chatsCollection.doc(_chatId).delete();
  }
}