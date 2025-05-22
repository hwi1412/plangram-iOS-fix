const functions = require('firebase-functions');
const admin = require('firebase-admin');
const sgMail = require('@sendgrid/mail');
admin.initializeApp();

const SENDGRID_API_KEY = functions.config().sendgrid.key;
const TO_EMAIL = 'dean7767@naver.com';

sgMail.setApiKey(SENDGRID_API_KEY);

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

exports.sendReportEmail = functions.firestore
    .document('reports/{reportId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const {
            targetUid = '',
            targetEmail = '',
            reporterUid = '',
            reporterEmail = '',
            reason = '',
            timestamp = null,
        } = data;

        const msg = {
            to: TO_EMAIL,
            from: 'noreply@plangram.app', // SendGrid에서 인증된 발신자 사용
            subject: '[Plangram] 새로운 신고가 접수되었습니다',
            text: `
신고 대상 UID: ${targetUid}
신고 대상 이메일: ${targetEmail}
신고자 UID: ${reporterUid}
신고자 이메일: ${reporterEmail}
신고 사유: ${reason}
신고 시각: ${timestamp ? timestamp.toDate() : 'N/A'}
      `,
            html: `
        <h3>Plangram 신고 접수</h3>
        <ul>
          <li><b>신고 대상 UID:</b> ${targetUid}</li>
          <li><b>신고 대상 이메일:</b> ${targetEmail}</li>
          <li><b>신고자 UID:</b> ${reporterUid}</li>
          <li><b>신고자 이메일:</b> ${reporterEmail}</li>
          <li><b>신고 사유:</b> ${reason}</li>
          <li><b>신고 시각:</b> ${timestamp ? timestamp.toDate() : 'N/A'}</li>
        </ul>
      `,
        };

        try {
            await sgMail.send(msg);
            console.log('신고 이메일 전송 성공');
        } catch (error) {
            console.error('신고 이메일 전송 실패:', error);
        }
        return null;
    });
