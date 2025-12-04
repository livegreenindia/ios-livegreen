const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Enhanced Morning Wellness Reminders - Runs at 7:30 AM IST
 * 
 * Schedule: Every day at 7:30 AM IST (optimal morning engagement time)
 * 
 * Personalizes messages based on:
 * - Day of week (weekday vs weekend)
 * - Recent happiness levels (last 3 days)
 * - Activity completion streaks
 * - Yesterday's performance
 * - Weather-appropriate suggestions (seasonal)
 * - User's typical completion patterns
 */
exports.sendMorningReminders = functions.pubsub
  .schedule('30 7 * * *')
  .timeZone('Asia/Kolkata') // IST timezone
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const today = now.toISOString().substring(0, 10);
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
    const dayOfWeek = now.getDay(); // 0=Sunday, 6=Saturday
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 6;
    const month = now.getMonth(); // 0-11
    
    // Seasonal context for India
    const isMonsoon = month >= 5 && month <= 8; // June-September
    const isWinter = month >= 10 || month <= 1; // Nov-Feb
    const isSummer = month >= 2 && month <= 4; // March-May
    
    try {
      console.log(`[MorningReminders] Starting personalized check for ${today}`);
      
      // Get all users with FCM tokens
      const usersSnapshot = await db.collection('users').get();
      const notifications = [];
      
      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        // Skip users without FCM token
        if (!fcmToken) {
          continue;
        }
        
        // Check if user has completed any activities today
        const completionsSnapshot = await db.collection('users')
          .doc(uid)
          .collection('completions')
          .where('localDate', '==', today)
          .get();
        
        const completedCount = completionsSnapshot.size;
        
        // Only send if user hasn't started activities yet
        if (completedCount === 0) {
          // Get personalization data
          const yesterdayCompletions = await db.collection('users')
            .doc(uid)
            .collection('completions')
            .where('localDate', '==', yesterday)
            .get();
          
          const yesterdayCount = yesterdayCompletions.size;
          
          // Get recent happiness level (last 3 days)
          const recentHappiness = await db.collection('users')
            .doc(uid)
            .collection('happiness')
            .orderBy('date', 'desc')
            .limit(3)
            .get();
          
          let avgHappiness = 3; // Default neutral
          if (!recentHappiness.empty) {
            const happinessSum = recentHappiness.docs.reduce((sum, doc) => {
              return sum + (doc.data().level || 3);
            }, 0);
            avgHappiness = Math.round(happinessSum / recentHappiness.size);
          }
          
          // Calculate activity streak (consecutive days with activities)
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
          
          // Enhanced personalized messages with context awareness
          let title = '🌅 Good Morning!';
          let body = 'Start your day with wellness!';
          let priority = 'default';
          
          // Weekend-specific messages
          if (isWeekend) {
            if (avgHappiness >= 4 && streak >= 3) {
              title = '🌴 Weekend Vibes!';
              body = `${streak}-day streak going strong! Perfect day for outdoor eco-activities.`;
            } else if (avgHappiness <= 2) {
              title = '💚 Self-Care Sunday';
              body = "Weekends are for recharging. Try a calming nature activity today.";
              priority = 'high';
            } else {
              title = '☀️ Weekend Wellness';
              body = "Extra time today? Explore a new eco-friendly activity!";
            }
          }
          // Seasonal + context-aware messages
          else if (isMonsoon) {
            if (avgHappiness >= 4) {
              title = '🌧️ Monsoon Morning!';
              body = "Rainy day? Perfect for indoor wellness activities!";
            } else {
              title = '🌱 Rainy Day Renewal';
              body = "Let the rain inspire your eco-journey today.";
            }
          }
          else if (isWinter && avgHappiness >= 4) {
            title = '❄️ Cozy Morning!';
            body = "Start your winter day with warm wellness activities.";
          }
          // High happiness + good streak = encouraging
          else if (avgHappiness >= 4 && streak >= 5) {
            title = '🏆 Eco Champion!';
            body = `Incredible ${streak}-day streak! You're making a real impact.`;
          }
          else if (avgHappiness >= 4 && streak >= 3) {
            title = '🌟 Great Morning!';
            body = `${streak}-day streak! Keep up the amazing momentum.`;
          }
          // Low happiness = supportive
          else if (avgHappiness <= 2) {
            title = '💚 We\'re Here for You';
            body = "Starting small is still starting. One easy activity can brighten your day.";
            priority = 'high';
          }
          // Good yesterday performance
          else if (yesterdayCount >= 5) {
            title = '🎯 Morning, Achiever!';
            body = `${yesterdayCount} activities yesterday! Ready to beat that today?`;
          }
          // Lost streak - motivational
          else if (streak === 0 && yesterdayCount === 0) {
            title = '🌱 Fresh Start';
            body = "Every eco-journey begins with one step. Make today count!";
            priority = 'high';
          }
          // Active streak
          else if (streak >= 1) {
            title = `🔥 ${streak}-Day Streak!`;
            body = "Keep the momentum going! What's your first activity today?";
          }
          
          console.log(`[MorningReminders] User ${uid.substring(0, 8)} - H:${avgHappiness}, Streak:${streak}, Yesterday:${yesterdayCount}, Weekend:${isWeekend}`);
          const message = {
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: 'morning_reminder',
              date: today,
              happiness: avgHappiness.toString(),
              streak: streak.toString(),
              yesterdayCount: yesterdayCount.toString(),
              isWeekend: isWeekend.toString(),
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            android: {
              priority: priority,
              notification: {
                icon: 'ic_notification',
                color: avgHappiness >= 4 ? '#FFD700' : avgHappiness <= 2 ? '#FF6B9D' : '#38e07b',
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
              .then(() => {
                console.log(`[MorningReminders] Sent to user ${uid}`);
                return { uid, success: true };
              })
              .catch((error) => {
                console.error(`[MorningReminders] Failed to send to ${uid}:`, error.code);
                // Remove invalid tokens
                if (error.code === 'messaging/invalid-registration-token' ||
                    error.code === 'messaging/registration-token-not-registered') {
                  return db.collection('users').doc(uid).update({ 
                    fcmToken: admin.firestore.FieldValue.delete() 
                  }).then(() => ({ uid, success: false, removed: true }));
                }
                return { uid, success: false, error: error.code };
              })
          );
        }
      }
      
      const results = await Promise.all(notifications);
      const successCount = results.filter(r => r.success).length;
      const failCount = results.filter(r => !r.success && !r.removed).length;
      const removedCount = results.filter(r => r.removed).length;
      
      console.log(`[MorningReminders] Complete: ${successCount} sent, ${failCount} failed, ${removedCount} tokens removed`);
      
      return {
        success: true,
        sent: successCount,
        failed: failCount,
        tokensRemoved: removedCount,
      };
      
    } catch (error) {
      console.error('[MorningReminders] Error:', error);
      throw error;
    }
  });
