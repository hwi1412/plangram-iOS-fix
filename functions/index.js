const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendFriendRequestNotification = functions.firestore
    .document('users/{userId}/friend_requests/{requestId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const userId = context.params.userId;
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) return null;

        const payload = {
            notification: {
                title: '친구 요청',
                body: `${data.senderName}님이 친구 요청을 보냈습니다.`,
            }
        };
        await admin.messaging().sendToDevice(fcmToken, payload);
        return null;
    });

exports.sendChatMessageNotification = functions.firestore
    .document('chat_rooms/{roomId}/messages/{msgId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const roomId = context.params.roomId;
        // 1:1 채팅방만 처리 (roomId에서 이메일 분리)
        const emails = roomId.split('_');
        const sender = data.sender;
        const receiver = emails.find(e => e !== sender);
        if (!receiver) return null;
        const userDoc = await admin.firestore().collection('users').where('email', '==', receiver).limit(1).get();
        if (userDoc.empty) return null;
        const fcmToken = userDoc.docs[0].data().fcmToken;
        if (!fcmToken) return null;

        const payload = {
            notification: {
                title: '새 메시지',
                body: data.message,
            }
        };
        await admin.messaging().sendToDevice(fcmToken, payload);
        return null;
    });
