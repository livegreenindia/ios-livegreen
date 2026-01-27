import '../models/wellness_schedule.dart';

/// Wellness schedule data based on user profiles
/// Source: Wellness schedule matrix for different lifestyle profiles
class WellnessScheduleData {
  static Map<String, WellnessSchedule> getAllSchedules() {
    return {
      'Working': _getWorkingSchedule(),
      'Student': _getStudentSchedule(),
      'Housewife': _getHousewifeSchedule(),
      'Retired': _getRetiredSchedule(),
    };
  }

  static WellnessSchedule getScheduleForProfile(String profile) {
    return getAllSchedules()[profile] ?? _getWorkingSchedule();
  }

  static WellnessSchedule _getWorkingSchedule() {
    return WellnessSchedule(
      profile: 'Working',
      weekdaySchedule: {
        TimeSlot.morning: [
          WellnessActivity(
            title: 'Body Scan Meditation',
            category: 'mindfulness',
            description: 'Practice mindfulness',
            info:
                'Body scan meditation helps you connect with your physical sensations, reduce stress, and start your day with calm awareness.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=body+scan+meditation',
            tips: [
              'Find a quiet space',
              'Start with 15 minutes',
              'Focus on each body part sequentially',
              'Use guided audio if needed',
            ],
          ),
          WellnessActivity(
            title: 'Go out in sunlight',
            category: 'health',
            info:
                'Morning sunlight exposure helps regulate your circadian rhythm, improves vitamin D production, and boosts mood and energy levels.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+sunlight+benefits',
            tips: [
              'Spend at least 10-15 minutes outdoors',
              'Best time: within 1 hour of waking up',
              'No sunglasses for maximum benefit',
            ],
          ),
          WellnessActivity(
            title: 'Exercise',
            category: 'fitness',
            info:
                'Morning exercise jumpstarts metabolism, improves focus, and sets a positive tone for the day.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+workout+routine',
            tips: [
              'Start with light stretching',
              '20-30 minutes is ideal',
              'Include cardio and strength training',
            ],
          ),
          WellnessActivity(
            title: 'Gardening and composting',
            category: 'nature',
            info:
                'Connecting with nature reduces stress, provides light exercise, and supports environmental sustainability.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=home+gardening+composting',
            tips: [
              'Water plants early morning',
              'Check compost moisture',
              'Harvest fresh herbs for breakfast',
            ],
          ),
          WellnessActivity(
            title: 'Breathing Excersice',
            category: 'mindfulness',
            info:
                'Meditation and mindfulness reduce cortisol levels, improve emotional regulation, and enhance mental clarity.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+meditation+guided',
            tips: [
              '5-10 minutes of deep breathing',
              'Focus on gratitude',
              'Set positive intentions for the day',
            ],
          ),
          WellnessActivity(
            title: 'Finish the shower with cold water',
            category: 'health',
            info:
                'Cold water therapy boosts circulation, strengthens immunity, and increases alertness and willpower.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=cold+shower+benefits',
            tips: [
              'Start with 30 seconds of cold water',
              'Gradually increase duration',
              'Deep breathing helps adaptation',
            ],
          ),
          WellnessActivity(
            title: 'No whatsapp or social media',
            category: 'digital_wellness',
            info:
                'Avoiding social media in the morning protects your mental space and prevents reactive behavior.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=digital+detox+morning',
            tips: [
              'Keep phone away from bedroom',
              'Use alarm clock instead of phone',
              'Check messages after breakfast',
            ],
          ),
        ],
        TimeSlot.midDay: [
          WellnessActivity(
            title: 'Eat the food with protein, fibers and nutrients',
            category: 'nutrition',
            info:
                'Balanced nutrition with protein, fiber, and essential nutrients sustains energy and supports cognitive function.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=healthy+balanced+meal',
            tips: [
              'Include vegetables in every meal',
              'Lean protein sources',
              'Whole grains over refined',
            ],
          ),
          WellnessActivity(
            title: 'Check light intensity and maintain above 500 lux',
            category: 'health',
            info:
                'Adequate lighting reduces eye strain, improves alertness, and supports circadian rhythm.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=office+lighting+health',
            tips: [
              'Natural light is best',
              'Use daylight bulbs if needed',
              'Position desk near windows',
            ],
          ),
          WellnessActivity(
            title: 'Keep spine straight',
            category: 'posture',
            info:
                'Good posture prevents back pain, improves breathing, and enhances confidence and energy.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=proper+sitting+posture',
            tips: [
              'Chair back support',
              'Feet flat on ground',
              'Screen at eye level',
            ],
          ),
          WellnessActivity(
            title: 'Every 15 min look at long horizon',
            category: 'eye_health',
            info:
                'The 20-20-20 rule: every 20 minutes, look at something 20 feet away for 20 seconds to reduce eye strain.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=eye+exercises+screen+time',
            tips: ['Set reminders', 'Look out the window', 'Blink frequently'],
          ),
          WellnessActivity(
            title: 'Deep work',
            category: 'productivity',
            info:
                'Deep work sessions improve productivity, creativity, and job satisfaction while reducing stress.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=deep+work+cal+newport',
            tips: [
              'Block 2-4 hour slots',
              'Single-task only',
              'Communicate boundaries to colleagues',
            ],
          ),
        ],
        TimeSlot.afternoon: [
          WellnessActivity(
            title: 'Eat lunch mindfully',
            category: 'nutrition',
            info:
                'Mindful eating improves digestion, prevents overeating, and enhances enjoyment of food.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=mindful+eating+practice',
            tips: [
              'Chew slowly',
              'No screens during meals',
              'Focus on flavors and textures',
            ],
          ),
          WellnessActivity(
            title: 'Take walk and observe nature around you',
            category: 'nature',
            info:
                'Walking in nature reduces stress hormones, improves creativity, and provides gentle exercise.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=nature+walk+benefits',
            tips: [
              '15-20 minute walk',
              'Notice plants, birds, sky',
              'Practice forest bathing',
            ],
          ),
          WellnessActivity(
            title: 'Do minor work like sending emails, administrative tasks',
            category: 'productivity',
            info:
                'Post-lunch is ideal for lighter tasks as energy naturally dips in early afternoon.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=productivity+circadian+rhythm',
            tips: [
              'Handle emails and calls',
              'Plan next day',
              'Review and organize',
            ],
          ),
        ],
        TimeSlot.evening: [
          WellnessActivity(
            title:
                'Play a game for 15-30 minutes (Chess, table tennis, Sudoku)',
            category: 'mental_fitness',
            info:
                'Games stimulate cognitive function, reduce stress, and provide enjoyable mental exercise.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=brain+games+benefits',
            tips: [
              'Variety of games',
              'Physical games preferred',
              'Social games enhance connection',
            ],
          ),
          WellnessActivity(
            title: 'Spend time with family, no screens, no social media',
            category: 'social',
            info:
                'Quality family time strengthens relationships, provides emotional support, and enhances life satisfaction.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=quality+family+time',
            tips: [
              'Device-free dinner',
              'Meaningful conversations',
              'Share daily experiences',
            ],
          ),
          WellnessActivity(
            title: 'Hear soft nature music',
            category: 'relaxation',
            info:
                'Nature sounds and soft music lower stress, improve sleep quality, and create calming atmosphere.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=nature+sounds+relaxation',
            tips: [
              'Low volume',
              'Water sounds, birds, rain',
              'Create evening routine',
            ],
          ),
          WellnessActivity(
            title:
                'use warm color (amber) Led light (100-200 lux)',
            category: 'sleep_hygiene',
            info:
                'Warm, dim lighting in evening supports melatonin production and prepares body for sleep.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=lighting+circadian+rhythm',
            tips: [
              'Amber/orange bulbs',
              'Dim lights progressively',
              'Blue light blockers',
            ],
          ),
          WellnessActivity(
            title:
                'Reduce the light intensity below 50lux one hour before sleep, do star gazing for 10 minutes',
            category: 'sleep_hygiene',
            info:
                'Very dim lighting and darkness signal sleep time. Stargazing provides awe and perspective.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=sleep+hygiene+darkness',
            tips: [
              'Blackout curtains',
              'Remove electronics',
              'Star identification apps',
            ],
          ),
        ],
      },
      weekendActivities: [
        WellnessActivity(
          title: 'Birding',
          category: 'nature',
          info:
              'Bird watching connects you with nature, teaches patience, and provides gentle outdoor exercise.',
          youtubeUrl:
              'https://www.youtube.com/results?search_query=birding+for+beginners',
          tips: [
            'Early morning best time',
            'Use birding apps for identification',
            'Bring binoculars',
          ],
        ),
        WellnessActivity(
          title: 'Tree identification',
          category: 'nature',
          info:
              'Learning about trees deepens environmental awareness and appreciation of biodiversity.',
          youtubeUrl:
              'https://www.youtube.com/results?search_query=tree+identification+guide',
          tips: [
            'Leaf shapes and bark patterns',
            'Use plant ID apps',
            'Visit local parks',
          ],
        ),
        WellnessActivity(
          title: 'Swimming or physical sports',
          category: 'fitness',
          info:
              'Physical activities improve cardiovascular health, build strength, and boost mood.',
          youtubeUrl:
              'https://www.youtube.com/results?search_query=weekend+sports+activities',
          tips: [
            'Variety of activities',
            'Social sports preferred',
            'Stay hydrated',
          ],
        ),
        WellnessActivity(
          title: 'Trekking and camping',
          category: 'nature',
          info:
              'Outdoor adventures provide intense physical activity, stress relief, and connection with nature.',
          youtubeUrl:
              'https://www.youtube.com/results?search_query=trekking+camping+tips',
          tips: [
            'Plan routes in advance',
            'Proper gear essential',
            'Leave no trace principles',
          ],
        ),
        WellnessActivity(
          title: 'Cycling or walking in natural terrain',
          category: 'fitness',
          info:
              'Low-impact exercise in natural settings combines fitness with nature therapy.',
          youtubeUrl:
              'https://www.youtube.com/results?search_query=cycling+nature+trails',
          tips: [
            'Explore new trails',
            'Carry water and snacks',
            'Safety gear mandatory',
          ],
        ),
      ],
    );
  }

  static WellnessSchedule _getStudentSchedule() {
    return WellnessSchedule(
      profile: 'Student',
      weekdaySchedule: {
        TimeSlot.morning: [
          WellnessActivity(
            title: 'Body Scan Meditation',
            category: 'mindfulness',
            description: 'Practice mindfulness',
            info:
                'Body scan meditation helps students manage stress, improve focus, and start the day with calm awareness.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=body+scan+meditation',
            tips: [
              'Find a quiet space',
              'Start with 15 minutes',
              'Focus on each body part sequentially',
              'Use guided audio if needed',
            ],
          ),
          WellnessActivity(
            title: 'Go out in sunlight',
            category: 'health',
            info:
                'Morning sunlight exposure helps regulate your circadian rhythm, improves vitamin D production, and boosts mood and energy levels.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+sunlight+benefits',
            tips: [
              'Spend at least 10-15 minutes outdoors',
              'Best time: within 1 hour of waking up',
            ],
          ),
          WellnessActivity(
            title: 'Exercise',
            category: 'fitness',
            info:
                'Morning exercise jumpstarts metabolism, improves focus, and sets a positive tone for the day.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+morning+exercise',
          ),
          WellnessActivity(
            title: 'Reading',
            category: 'learning',
            info:
                'Morning reading improves comprehension, builds knowledge, and enhances vocabulary.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=benefits+morning+reading',
            tips: [
              'Read for 20-30 minutes',
              'Choose inspiring content',
              'Physical books preferred',
            ],
          ),
          WellnessActivity(
            title: 'Breathing Exercise',
            category: 'mindfulness',
            info:
                'Meditation helps students manage academic stress, improve concentration, and enhance memory.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+meditation',
          ),
          WellnessActivity(
            title: 'Finish the shower with cold water',
            category: 'health',
            info:
                'Cold water therapy boosts circulation, strengthens immunity, and increases alertness.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=cold+shower+benefits',
          ),
          WellnessActivity(
            title: 'No whatsapp or social media',
            category: 'digital_wellness',
            info:
                'Avoiding social media in morning protects focus and prevents distraction from studies.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+digital+detox',
          ),
        ],
        TimeSlot.midDay: [
          WellnessActivity(
            title: 'Eat the food with protein, fibers and nutrients',
            category: 'nutrition',
            info:
                'Balanced nutrition supports brain function, memory, and sustained energy for learning.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+nutrition+brain+food',
          ),
          
          WellnessActivity(
            title: 'Check light intensity and maintain above 500 lux',
            category: 'health',
            info:
                'Adequate lighting reduces eye strain and improves concentration during studies.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=study+room+lighting',
          ),
          WellnessActivity(
            title: 'Keep spine straight',
            category: 'posture',
            info:
                'Good posture while studying prevents back pain and improves focus.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=study+posture',
          ),
          WellnessActivity(
            title: 'Every 15 min look at long horizon',
            category: 'eye_health',
            info:
                'Regular eye breaks prevent strain and protect vision during long study hours.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+eye+health',
          ),
          WellnessActivity(
            title: 'Deep study',
            category: 'learning',
            info:
                'Focused study sessions enhance understanding, retention, and academic success.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=deep+study+techniques',
            tips: [
              'Use Pomodoro technique',
              'Active recall and spaced repetition',
              'Teach others to reinforce learning',
            ],
          ),
        ],
        TimeSlot.afternoon: [
          WellnessActivity(
            title: 'Eat lunch mindfully',
            category: 'nutrition',
            info:
                'Mindful eating improves digestion and provides energy for afternoon activities.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=mindful+eating',
          ),
          WellnessActivity(
            title: 'Do minor study',
            category: 'learning',
            info:
                'Light review or reading helps maintain momentum without causing fatigue.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=afternoon+study+tips',
            tips: [
              'Review notes',
              'Read supplementary material',
              'Practice problems',
            ],
          ),
        ],
        TimeSlot.evening: [
          WellnessActivity(
            title:
                'Play a game for 15-30 minutes (Chess, table tennis, Sudoku)',
            category: 'mental_fitness',
            info:
                'Games provide mental stimulation and stress relief after studies.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=brain+games+students',
          ),
          WellnessActivity(
            title: 'Spend time with family, no screens, no social media',
            category: 'social',
            info:
                'Family time provides emotional support crucial for student well-being.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=family+time+importance',
          ),
          WellnessActivity(
            title: 'Hear soft nature music',
            category: 'relaxation',
            info:
                'Calming music helps transition from study mode to relaxation.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=study+music+relaxation',
          ),
          WellnessActivity(
            title: 'study in warm color (amber) Led light (100-200 lux)',
            category: 'sleep_hygiene',
            info: 'Evening study with warm lighting protects sleep quality.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=evening+study+lighting',
            tips: [
              'Limit evening study time',
              'Avoid last-minute cramming',
              'Review only, no new topics',
            ],
          ),
          WellnessActivity(
            title:
                'Reduce the light intensity below 50lux one hour before sleep, do star gazing for 10 minutes',
            category: 'sleep_hygiene',
            info:
                'Proper sleep hygiene ensures quality rest essential for memory consolidation.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=student+sleep+hygiene',
          ),
        ],
      },
      weekendActivities: _getCommonWeekendActivities(),
    );
  }

  static WellnessSchedule _getHousewifeSchedule() {
    return WellnessSchedule(
      profile: 'Housewife',
      weekdaySchedule: {
        TimeSlot.morning: [
          WellnessActivity(
            title: 'Body Scan Meditation',
            category: 'mindfulness',
            description: 'Practice mindfulness',
            info:
                'Body scan meditation provides a peaceful start to the day, reduces household stress, and promotes self-care.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=body+scan+meditation',
            tips: [
              'Find a quiet space',
              'Start with 15 minutes',
              'Focus on each body part sequentially',
              'Use guided audio if needed',
            ],
          ),
          WellnessActivity(
            title: 'Go out in sunlight for 30 minutes',
            category: 'health',
            info:
                'Morning sunlight boosts vitamin D, improves mood, and regulates sleep-wake cycle.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+sunlight+walk',
          ),
          WellnessActivity(
            title: 'Walking',
            category: 'fitness',
            info:
                'Regular walking improves cardiovascular health, maintains weight, and reduces stress.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=morning+walk+benefits',
            tips: [
              'Brisk pace for 30 minutes',
              'Comfortable footwear',
              'Hydrate before and after',
            ],
          ),
        ],
        TimeSlot.midDay: [
          WellnessActivity(
            title: 'Eat the food with protein, fibers and nutrients',
            category: 'nutrition',
            info:
                'Nutritious meals provide energy for household tasks and support overall health.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=healthy+home+cooking',
          ),
          WellnessActivity(
            title: 'Gardening and composting',
            category: 'nature',
            info:
                'Gardening provides exercise, stress relief, and fresh produce for family.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=kitchen+gardening',
          ),
          WellnessActivity(
            title: 'Finish the shower with cold water',
            category: 'health',
            info:
                'Cold water therapy energizes, improves circulation, and boosts immunity.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=cold+shower+benefits',
          ),
          WellnessActivity(
            title: 'Check light intensity and maintain minimum above 500 lux',
            category: 'health',
            info:
                'Good lighting prevents eye strain during household activities and cooking.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=home+lighting+health',
          ),
          WellnessActivity(
            title: 'Every 15 min look at long horizon',
            category: 'eye_health',
            info:
                'Eye breaks are important even during household work to prevent strain.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=eye+care+exercises',
          ),
          
        ],
        TimeSlot.afternoon: [
          WellnessActivity(
            title: 'Eat lunch mindfully',
            category: 'nutrition',
            info:
                'Taking time to eat properly ensures better digestion and energy.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=mindful+eating',
          ),
          WellnessActivity(
            title: 'Take walk and observe nature around you',
            category: 'nature',
            info:
                'Afternoon nature walks provide break from household routines and refresh mind.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=nature+walk+meditation',
          ),
          WellnessActivity(
            title: 'Practice a hobby',
            category: 'creativity',
            info:
                'Hobbies provide creative outlet, personal growth, and joy beyond household duties.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=hobbies+for+homemakers',
            tips: [
              'Painting, crafts, music',
              'Dedicate 30-60 minutes daily',
              'Join online or local groups',
            ],
          ),
        ],
        TimeSlot.evening: [
          WellnessActivity(
            title: 'Spend time with family, no screens, no social media',
            category: 'social',
            info:
                'Quality family time strengthens bonds and creates lasting memories.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=family+bonding+activities',
          ),
          WellnessActivity(
            title: 'Hear soft nature music',
            category: 'relaxation',
            info:
                'Calming music creates peaceful home atmosphere for evening routine.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=relaxing+home+music',
          ),
          WellnessActivity(
            title:
                'Check light intensity, use warm color (amber) Led light (100-200 lux)',
            category: 'sleep_hygiene',
            info:
                'Warm evening lighting helps entire family prepare for restful sleep.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=home+evening+lighting',
          ),
          WellnessActivity(
            title:
                'Reduce the light intensity below 50lux one hour before sleep, do star gazing for 10 minutes',
            category: 'sleep_hygiene',
            info:
                'Creating dark, calm environment ensures quality sleep for everyone.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=bedtime+routine',
          ),
        ],
      },
      weekendActivities: _getCommonWeekendActivities(),
    );
  }

  static WellnessSchedule _getRetiredSchedule() {
    return WellnessSchedule(
      profile: 'Retired',
      weekdaySchedule: {
        TimeSlot.morning: [
          WellnessActivity(
            title: 'Body Scan Meditation',
            category: 'mindfulness',
            description: 'Practice mindfulness',
            info:
                'Body scan meditation helps seniors maintain mental clarity, reduce stress, and connect with their body mindfully.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=body+scan+meditation',
            tips: [
              'Find a quiet space',
              'Start with 15 minutes',
              'Focus on each body part sequentially',
              'Can be done seated or lying down',
            ],
          ),
          WellnessActivity(
            title: 'Go out in sunlight for 30 minutes',
            category: 'health',
            info:
                'Morning sunlight is especially important for seniors to maintain bone health and regulate sleep.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=seniors+morning+sunlight',
          ),
          WellnessActivity(
            title: 'Walking',
            category: 'fitness',
            info:
                'Regular walking maintains mobility, cardiovascular health, and independence.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+walking+exercise',
            tips: [
              'Gentle pace, listen to body',
              'Walking stick if needed',
              'Walk with friends',
            ],
          ),
          WellnessActivity(
            title: 'Gardening and composting',
            category: 'nature',
            info:
                'Gardening provides gentle exercise, purpose, and connection to nature.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+gardening+benefits',
          ),
        ],
        TimeSlot.midDay: [
          WellnessActivity(
            title: 'Eat the food with protein, fibers and nutrients',
            category: 'nutrition',
            info:
                'Nutritious diet supports healthy aging, maintains energy, and prevents disease.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+nutrition+guide',
          ),
          WellnessActivity(
            title: 'Gardening and composting',
            category: 'nature',
            info:
                'Continued garden work provides fulfilling activity and fresh produce.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=retirement+gardening',
          ),
          WellnessActivity(
            title: 'Finish the shower with cold water',
            category: 'health',
            info:
                'Cold water therapy (adapted for comfort) improves circulation and vitality.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=seniors+cold+water+therapy',
            tips: [
              'Start with cool, not ice cold',
              'Brief exposure',
              'Consult doctor if health concerns',
            ],
          ),
          WellnessActivity(
            title: 'Check light intensity and maintain minimum above 500 lux',
            category: 'health',
            info:
                'Adequate lighting is crucial for seniors to prevent falls and eye strain.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+home+lighting',
          ),
          WellnessActivity(
            title: 'Every 15 min look at long horizon',
            category: 'eye_health',
            info: 'Eye care helps maintain vision health in senior years.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+eye+health',
          ),
          
        ],
        TimeSlot.afternoon: [
          WellnessActivity(
            title: 'Eat lunch mindfully',
            category: 'nutrition',
            info: 'Mindful eating aids digestion and enjoyment of meals.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=mindful+eating+seniors',
          ),
          WellnessActivity(
            title: 'Take walk and observe nature around you',
            category: 'nature',
            info:
                'Nature walks provide gentle exercise and mental stimulation.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+nature+walking',
          ),
          WellnessActivity(
            title: 'Practice a hobby',
            category: 'creativity',
            info:
                'Hobbies keep mind active, provide purpose, and social connections.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=retirement+hobbies',
            tips: [
              'Arts, crafts, music',
              'Join community groups',
              'Volunteer opportunities',
            ],
          ),
        ],
        TimeSlot.evening: [
          WellnessActivity(
            title: 'Spend time with family, no screens, no social media',
            category: 'social',
            info:
                'Family connections provide emotional support and combat loneliness.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+family+time',
          ),
          WellnessActivity(
            title: 'Hear soft nature music',
            category: 'relaxation',
            info: 'Soothing music reduces stress and enhances relaxation.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=relaxation+music+seniors',
          ),
          WellnessActivity(
            title:
                'Check light intensity, use warm color (amber) Led light (100-200 lux)',
            category: 'sleep_hygiene',
            info:
                'Proper evening lighting supports healthy sleep patterns in seniors.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+sleep+lighting',
          ),
          WellnessActivity(
            title:
                'Reduce the light intensity below 50lux one hour before sleep, do star gazing for 10 minutes',
            category: 'sleep_hygiene',
            info:
                'Good sleep hygiene ensures restorative rest crucial for senior health.',
            youtubeUrl:
                'https://www.youtube.com/results?search_query=senior+sleep+hygiene',
          ),
        ],
      },
      weekendActivities: _getCommonWeekendActivities(),
    );
  }

  static List<WellnessActivity> _getCommonWeekendActivities() {
    return [
      WellnessActivity(
        title: 'Birding',
        category: 'nature',
        info:
            'Bird watching connects you with nature, teaches patience, and provides gentle outdoor exercise.',
        youtubeUrl:
            'https://www.youtube.com/results?search_query=birding+for+beginners',
        tips: [
          'Early morning best time',
          'Use birding apps',
          'Bring binoculars',
        ],
      ),
      WellnessActivity(
        title: 'Tree identification',
        category: 'nature',
        info:
            'Learning about trees deepens environmental awareness and appreciation.',
        youtubeUrl:
            'https://www.youtube.com/results?search_query=tree+identification',
      ),
      WellnessActivity(
        title: 'Swimming or physical sports',
        category: 'fitness',
        info:
            'Physical activities improve health, build strength, and boost mood.',
        youtubeUrl:
            'https://www.youtube.com/results?search_query=weekend+sports',
      ),
      WellnessActivity(
        title: 'Trekking and camping',
        category: 'nature',
        info:
            'Outdoor adventures provide exercise, stress relief, and nature connection.',
        youtubeUrl:
            'https://www.youtube.com/results?search_query=trekking+camping',
      ),
      WellnessActivity(
        title: 'Cycling or walking in natural terrain',
        category: 'fitness',
        info:
            'Low-impact exercise in natural settings combines fitness with nature therapy.',
        youtubeUrl:
            'https://www.youtube.com/results?search_query=cycling+nature',
      ),
    ];
  }
}
