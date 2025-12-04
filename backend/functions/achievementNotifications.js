const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Real-Time Achievement Notifications
 * 
 * Triggers IMMEDIATELY when user completes an activity,
 * checks for milestone achievements:
 * - First activity of the day
 * - Streak milestones (3, 7, 14, 30 days)
 * - Daily goals (5, 10 activities)
 * - Perfect week (7 days in a row with 5+ activities)
 */
exports.onActivityCompletion = functions.firestore
  .document('users/{userId}/completions/{completionId}')
  .onCreate(async (snap, context) => {
    const { userId } = context.params;
    const completionData = snap.data();
    const db = admin.firestore();
    
    try {
      // Get user FCM token
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;
      if (!fcmToken) return null;
      
      const today = new Date().toISOString().substring(0, 10);
      const localDate = completionData.localDate || today;
      
      // Count today's completions
      const todayCompletions = await db.collection('users')
        .doc(userId)
        .collection('completions')
        .where('localDate', '==', localDate)
        .get();
      
      const todayCount = todayCompletions.size;
      
      // Calculate streak
      let streak = 1; // Today counts as 1
      let checkDate = new Date();
      checkDate.setDate(checkDate.getDate() - 1);
      
      for (let i = 0; i < 30; i++) {
        const dateStr = checkDate.toISOString().substring(0, 10);
        const dayCompletions = await db.collection('users')
          .doc(userId)
          .collection('completions')
          .where('localDate', '==', dateStr)
          .limit(1)
          .get();
        
        if (!dayCompletions.empty) {
          streak++;
        } else {
          break;
        }
        checkDate.setDate(checkDate.getDate() - 1);
      }
      
      // Check for achievements
      let achievement = null;
      
      // First activity of the day
      if (todayCount === 1) {
        achievement = {
          title: '🌅 Day Started!',
          body: "You've kicked off your eco-journey today. Keep going!",
          icon: 'sunrise',
          priority: 'default',
        };
      }
      
      // 5 activities milestone
      if (todayCount === 5) {
        achievement = {
          title: '🎯 Halfway Hero!',
          body: '5 activities done! You\'re making real impact today.',
          icon: 'target',
          priority: 'high',
        };
      }
      
      // 10 activities - daily champion
      if (todayCount === 10) {
        achievement = {
          title: '🏆 Daily Champion!',
          body: '10 activities! You\'re an eco-warrior superstar!',
          icon: 'trophy',
          priority: 'high',
        };
      }
      
      // Streak milestones (override daily achievements for streaks)
      const streakMilestones = {
        3: { title: '🔥 3-Day Streak!', body: "You're building momentum! Keep it up!", icon: 'fire' },
        7: { title: '⭐ Weekly Warrior!', body: "A whole week! You're amazing!", icon: 'star' },
        14: { title: '💪 2-Week Legend!', body: "14 days of eco-action! Incredible dedication!", icon: 'muscle' },
        21: { title: '🌟 3-Week Master!', body: "21 days = a habit formed! You're unstoppable!", icon: 'glow' },
        30: { title: '👑 Monthly Champion!', body: "30 days! You've made a real difference!", icon: 'crown' },
      };
      
      if (streakMilestones[streak]) {
        achievement = {
          ...streakMilestones[streak],
          priority: 'high',
        };
      }
      
      // Check for perfect week (7 days with 5+ activities each)
      if (streak >= 7 && todayCount >= 5) {
        let perfectDays = 0;
        let perfectCheckDate = new Date();
        
        for (let i = 0; i < 7; i++) {
          const dateStr = perfectCheckDate.toISOString().substring(0, 10);
          const dayCompletions = await db.collection('users')
            .doc(userId)
            .collection('completions')
            .where('localDate', '==', dateStr)
            .get();
          
          if (dayCompletions.size >= 5) {
            perfectDays++;
          }
          perfectCheckDate.setDate(perfectCheckDate.getDate() - 1);
        }
        
        if (perfectDays === 7) {
          achievement = {
            title: '💎 Perfect Week!',
            body: '7 days with 5+ activities each! Absolute legend!',
            icon: 'diamond',
            priority: 'high',
          };
        }
      }
      
      // Send achievement notification
      if (achievement) {
        console.log(`[Achievement] ${userId.substring(0, 8)} - ${achievement.title}`);
        
        const message = {
          notification: {
            title: achievement.title,
            body: achievement.body,
          },
          data: {
            type: 'achievement',
            icon: achievement.icon,
            todayCount: todayCount.toString(),
            streak: streak.toString(),
            date: localDate,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          token: fcmToken,
          android: {
            priority: achievement.priority,
            notification: {
              icon: 'ic_notification',
              color: '#00A859',
              defaultSound: true,
              channelId: 'achievements',
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
        
        await admin.messaging().send(message);
        
        // Log achievement to user's achievements collection
        await db.collection('users').doc(userId).collection('achievements').add({
          title: achievement.title,
          icon: achievement.icon,
          todayCount,
          streak,
          date: localDate,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        return { achievement: achievement.title, streak, todayCount };
      }
      
      return { noAchievement: true, streak, todayCount };
      
    } catch (error) {
      console.error('[Achievement] Error:', error);
      return null;
    }
  });
