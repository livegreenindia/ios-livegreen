const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Enhanced Evening Activity Reminders - Runs at 7:30 PM IST
 * 
 * Schedule: Every day at 7:30 PM IST (optimal evening engagement)
 * 
 * Smart personalization based on:
 * - Today's completion count vs user's typical average
 * - Current happiness level
 * - Weekly performance trends
 * - Time remaining in the day
 * - Day of week context
 */
exports.sendActivityReminders = functions.pubsub
  .schedule('30 19 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const today = now.toISOString().substring(0, 10);
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
    const dayOfWeek = now.getDay();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    const isFriday = dayOfWeek === 5;
    
    try {
      console.log('[ActivityReminders] Starting check for', today);
      const users = await db.collection('users').get();
      const notifications = [];
      
      for (const userDoc of users.docs) {
        const uid = userDoc.id;
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) continue;
        
        const completions = await db.collection('users').doc(uid).collection('completions').where('localDate', '==', today).get();
        const count = completions.size;
        
        const happinessDoc = await db.collection('users').doc(uid).collection('happiness').doc(today).get();
        const happiness = happinessDoc.exists ? (happinessDoc.data().level || 3) : 3;
        
        const weekCompletions = await db.collection('users').doc(uid).collection('completions').where('localDate', '>=', weekAgo).where('localDate', '<', today).get();
        const weeklyAvg = weekCompletions.size / 7;
        
        let title = '';
        let body = '';
        let priority = 'default';
        let send = false;
        
        // Enhanced context-aware evening messages
        if (count === 0) {
          send = true;
          priority = 'high';
          if (happiness <= 2) {
            title = '💚 You Matter';
            body = "It's okay to start small. Even one tiny eco-action counts.";
          } else if (isWeekend) {
            title = '🌙 Weekend Evening';
            body = "Still time for a relaxing eco-activity before bed!";
          } else if (isFriday) {
            title = '🎉 TGIF!';
            body = "End your week with one quick wellness activity?";
          } else {
            title = '⏰ Evening Check-in';
            body = "2+ hours left! Quick activity before winding down?";
          }
        }
        else if (count >= 1 && count <= 2) {
          send = true;
          if (happiness >= 4) {
            title = '✨ Almost There!';
            body = `${count} done! One more to hit your daily goal?`;
          } else {
            title = '🌿 Good Start';
            body = `${count} completed today. Every step matters!`;
          }
        }
        else if (count >= 3 && count <= 4) {
          send = true;
          if (happiness >= 4) {
            title = '🎯 Great Progress!';
            body = `${count} activities! Push for ${count + 2} to level up?`;
          } else if (happiness <= 2) {
            title = '💪 Proud of You';
            body = `${count} done despite a tough day. That's real strength.`;
            priority = 'high';
          } else {
            title = '🌱 Solid Day';
            body = `${count} eco-actions completed. Well done!`;
          }
        }
        else if (count >= 5 && count <= 6) {
          if (happiness <= 2) {
            send = true;
            title = '🌟 Resilience';
            body = `${count} activities on a hard day. You're amazing!`;
            priority = 'high';
          } else {
            send = true;
            title = '🔥 On Fire!';
            body = `${count} done! One more for a perfect day?`;
          }
        }
        else if (count >= 7) {
          send = true;
          title = '🏆 Eco Champion!';
          body = `${count} completed! You're making a real difference!`;
        }
        
        // Below average notification
        if (!send && count < weeklyAvg * 0.7 && weeklyAvg >= 3) {
          send = true;
          title = '📊 Quick Check';
          body = `Usually ${Math.round(weeklyAvg)} by now. Still time to catch up!`;
        }
        
        // Friday motivation for weekend
        if (!send && isFriday && count >= 3) {
          send = true;
          title = '🎉 Great Week!';
          body = `${count} today! Keep the momentum this weekend.`;
        }
        
        if (send) {
          console.log(`[ActivityReminders] ${uid.substring(0, 8)} - Count:${count} H:${happiness} Avg:${weeklyAvg.toFixed(1)} Weekend:${isWeekend}`);
          
          const message = {
            notification: { title, body },
            data: { type: 'activity_reminder', date: today, completedCount: count.toString(), happiness: happiness.toString(), click_action: 'FLUTTER_NOTIFICATION_CLICK' },
            token: fcmToken,
            android: {
              priority,
              notification: { icon: 'ic_notification', color: count >= 7 ? '#FFD700' : count === 0 ? '#FF6B9D' : '#38e07b', defaultSound: true, channelId: 'activity_reminders' }
            }
          };
          
          notifications.push(
            admin.messaging().send(message)
              .then(() => ({ uid, success: true }))
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
      console.log(`[ActivityReminders] Complete: ${sent} sent`);
      return { success: true, sent };
      
    } catch (error) {
      console.error('[ActivityReminders] Error:', error);
      throw error;
    }
  });

