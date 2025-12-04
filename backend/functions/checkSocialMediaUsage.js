const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.checkSocialMediaUsage = functions.pubsub
  .schedule('0 */3 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const today = new Date().toISOString().substring(0, 10);
    const currentHour = new Date().getHours();
    
    if (currentHour < 9 || currentHour >= 21) {
      console.log(`[SocialMediaCheck] Skipping check at ${currentHour}:00`);
      return { skipped: true };
    }
    
    try {
      console.log(`[SocialMediaCheck] Starting check for ${today}`);
      const usersSnapshot = await db.collection('users').get();
      const notifications = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) continue;
        
        const metricsSnapshot = await db.collection('users').doc(uid).collection('daily_metrics').where('date', '==', today).limit(1).get();
        if (metricsSnapshot.empty) continue;
        
        const metrics = metricsSnapshot.docs[0].data();
        const totalMinutes = metrics.socialMediaMinutes || (metrics.youtubeMinutes + metrics.instagramMinutes) || 0;
        
        const happinessDoc = await db.collection('users').doc(uid).collection('happiness').doc(today).get();
        const happiness = happinessDoc.exists ? (happinessDoc.data().level || 3) : 3;
        
        const completions = await db.collection('users').doc(uid).collection('completions').where('localDate', '==', today).get();
        const completionCount = completions.size;
        
        const LIMIT = happiness <= 2 ? 150 : 120;
        const HIGH = happiness <= 2 ? 210 : 180;
        
        const alertKey = `socialMediaAlert_${today}`;
        if (userData[alertKey]) continue;
        
        let shouldAlert = false;
        let level = '';
        let title = '';
        let body = '';
        
        const hours = (totalMinutes / 60).toFixed(1);
        
        if (totalMinutes >= HIGH) {
          shouldAlert = true;
          level = 'high';
          if (happiness <= 2 && completionCount === 0) {
            title = 'Gentle Reminder';
            body = `${hours} hours on social media. Maybe try a wellness activity? It might help.`;
          } else if (completionCount >= 5) {
            title = 'Balance Your Day';
            body = `${hours} hours on social media despite ${completionCount} activities done!`;
          } else {
            title = 'Screen Time Alert';
            body = `${hours} hours on social media today. Time for a digital detox!`;
          }
        } else if (totalMinutes >= LIMIT) {
          shouldAlert = true;
          level = 'moderate';
          if (happiness >= 4) {
            title = 'Doing Great!';
            body = `${hours} hours on social media. Keep your positive energy!`;
          } else if (happiness <= 2) {
            title = 'Small Step';
            body = `${hours} hours screen time. A walk might help how you feel.`;
          } else {
            title = 'Screen Time Update';
            body = `${hours} hours on social media. Consider reducing screen time.`;
          }
        }
        
        if (shouldAlert) {
          console.log(`[SocialMediaCheck] User ${uid.substring(0, 8)} - ${totalMinutes}m, H:${happiness}, A:${completionCount}`);
          
          const message = {
            notification: { title, body },
            data: {
              type: 'social_media_alert',
              date: today,
              minutes: totalMinutes.toString(),
              level,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            android: {
              priority: level === 'high' ? 'high' : 'default',
              notification: {
                icon: 'ic_notification',
                color: happiness <= 2 ? '#B39DDB' : '#FF9800',
                defaultSound: level === 'high',
                channelId: 'digital_wellbeing',
              },
            },
          };
          
          notifications.push(
            admin.messaging().send(message)
              .then(() => db.collection('users').doc(uid).update({ [alertKey]: admin.firestore.FieldValue.serverTimestamp() }).then(() => ({ uid, success: true, level })))
              .catch((error) => {
                if (error.code === 'messaging/invalid-registration-token' || error.code === 'messaging/registration-token-not-registered') {
                  return db.collection('users').doc(uid).update({ fcmToken: admin.firestore.FieldValue.delete() }).then(() => ({ uid, removed: true }));
                }
                return { uid, error: error.code };
              })
          );
        }
      }
      
      const results = await Promise.all(notifications);
      const sent = results.filter(r => r.success).length;
      const high = results.filter(r => r.level === 'high').length;
      const moderate = results.filter(r => r.level === 'moderate').length;
      
      console.log(`[SocialMediaCheck] Complete: ${sent} sent (${high} high, ${moderate} moderate)`);
      return { success: true, sent, high, moderate };
      
    } catch (error) {
      console.error('[SocialMediaCheck] Error:', error);
      throw error;
    }
  });

