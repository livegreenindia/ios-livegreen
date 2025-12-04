const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Midday Check-in Reminders - Runs at 1:00 PM IST
 * 
 * Schedule: Every day at 1:00 PM IST (lunch break engagement)
 * 
 * Only sends to users who:
 * - Have 0 activities completed today
 * - Had good activity yesterday (to prevent streak loss)
 * - OR have low happiness and need gentle nudge
 * 
 * This is a lighter notification - not sent to everyone.
 */
exports.sendMiddayReminders = functions.pubsub
  .schedule('0 13 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const today = now.toISOString().substring(0, 10);
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
    const dayOfWeek = now.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    
    try {
      console.log('[MiddayReminders] Starting selective check for', today);
      const usersSnapshot = await db.collection('users').get();
      const notifications = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) continue;
        
        // Check today's completions
        const todayCompletions = await db.collection('users')
          .doc(uid)
          .collection('completions')
          .where('localDate', '==', today)
          .get();
        
        const todayCount = todayCompletions.size;
        
        // Only target users with 0 completions
        if (todayCount > 0) continue;
        
        // Check yesterday's performance
        const yesterdayCompletions = await db.collection('users')
          .doc(uid)
          .collection('completions')
          .where('localDate', '==', yesterday)
          .get();
        
        const yesterdayCount = yesterdayCompletions.size;
        
        // Get happiness level
        const happinessDoc = await db.collection('users')
          .doc(uid)
          .collection('happiness')
          .doc(today)
          .get();
        const happiness = happinessDoc.exists ? (happinessDoc.data().level || 3) : 3;
        
        // Calculate streak
        let streak = 0;
        let checkDate = new Date(Date.now() - 24 * 60 * 60 * 1000);
        for (let i = 0; i < 7; i++) {
          const dateStr = checkDate.toISOString().substring(0, 10);
          const dayCompletions = await db.collection('users')
            .doc(uid)
            .collection('completions')
            .where('localDate', '==', dateStr)
            .limit(1)
            .get();
          
          if (!dayCompletions.empty) {
            streak++;
          } else {
            break;
          }
          checkDate = new Date(checkDate.getTime() - 24 * 60 * 60 * 1000);
        }
        
        // Decide if we should send notification
        let shouldSend = false;
        let title = '';
        let body = '';
        let priority = 'default';
        
        // Priority 1: Streak protection (3+ day streak at risk)
        if (streak >= 3 && todayCount === 0) {
          shouldSend = true;
          title = '⚡ Streak Alert!';
          body = `Your ${streak}-day streak needs you! Quick activity during lunch?`;
          priority = 'high';
        }
        // Priority 2: Low happiness - gentle nudge
        else if (happiness <= 2 && todayCount === 0) {
          shouldSend = true;
          title = '🌿 Gentle Reminder';
          body = "A 5-minute eco-activity might help lift your mood.";
          priority = 'default';
        }
        // Priority 3: Had good day yesterday (5+), none today
        else if (yesterdayCount >= 5 && todayCount === 0) {
          shouldSend = true;
          title = '🎯 Lunch Break?';
          body = `You did ${yesterdayCount} yesterday! Quick one before afternoon?`;
          priority = 'default';
        }
        // Priority 4: Weekend motivation (if completely inactive)
        else if (isWeekend && todayCount === 0 && yesterdayCount >= 3) {
          shouldSend = true;
          title = '☀️ Weekend Check-in';
          body = "Perfect time for a refreshing outdoor activity!";
          priority = 'default';
        }
        
        if (shouldSend) {
          console.log(`[MiddayReminders] ${uid.substring(0, 8)} - Streak:${streak} Yesterday:${yesterdayCount} H:${happiness}`);
          
          const message = {
            notification: { title, body },
            data: {
              type: 'midday_reminder',
              date: today,
              streak: streak.toString(),
              happiness: happiness.toString(),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            android: {
              priority,
              notification: {
                icon: 'ic_notification',
                color: streak >= 3 ? '#FF9800' : '#38e07b',
                defaultSound: true,
                channelId: 'activity_reminders',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };
          
          notifications.push(
            admin.messaging().send(message)
              .then(() => ({ uid, success: true, reason: streak >= 3 ? 'streak' : 'nudge' }))
              .catch((error) => {
                if (error.code === 'messaging/invalid-registration-token' ||
                    error.code === 'messaging/registration-token-not-registered') {
                  return db.collection('users').doc(uid).update({ 
                    fcmToken: admin.firestore.FieldValue.delete() 
                  }).then(() => ({ uid, removed: true }));
                }
                return { uid, error: error.code };
              })
          );
        }
      }
      
      const results = await Promise.all(notifications);
      const sent = results.filter(r => r.success).length;
      const streakAlerts = results.filter(r => r.reason === 'streak').length;
      
      console.log(`[MiddayReminders] Complete: ${sent} sent (${streakAlerts} streak alerts)`);
      return { success: true, sent, streakAlerts };
      
    } catch (error) {
      console.error('[MiddayReminders] Error:', error);
      throw error;
    }
  });
