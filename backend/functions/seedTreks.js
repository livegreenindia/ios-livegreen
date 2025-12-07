/**
 * One-off script to seed sample treks near Bangalore.
 * Run with: node seedTreks.js
 * Ensure GOOGLE_APPLICATION_CREDENTIALS is set or use Firebase emulators.
 */
const admin = require('firebase-admin');

try {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT || 'livegreen-bf838';
  admin.initializeApp({ projectId });
} catch (e) {
  // Already initialized
}

const db = admin.firestore();

// Geohash encoding function
function encodeGeohash(latitude, longitude, precision = 9) {
  const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  
  let minLat = -90.0;
  let maxLat = 90.0;
  let minLon = -180.0;
  let maxLon = 180.0;
  
  let hash = '';
  let isLon = true;
  let bits = 0;
  let charIndex = 0;
  
  while (hash.length < precision) {
    if (isLon) {
      const mid = (minLon + maxLon) / 2;
      if (longitude >= mid) {
        charIndex = (charIndex << 1) | 1;
        minLon = mid;
      } else {
        charIndex = charIndex << 1;
        maxLon = mid;
      }
    } else {
      const mid = (minLat + maxLat) / 2;
      if (latitude >= mid) {
        charIndex = (charIndex << 1) | 1;
        minLat = mid;
      } else {
        charIndex = charIndex << 1;
        maxLat = mid;
      }
    }
    
    isLon = !isLon;
    bits++;
    
    if (bits === 5) {
      hash += base32[charIndex];
      bits = 0;
      charIndex = 0;
    }
  }
  
  return hash;
}

// Sample treks near Bangalore (13.0267, 77.6657)
const sampleTreks = [
  {
    title: 'Cubbon Park Walking Trail',
    description: 'A beautiful walking trail through the historic Cubbon Park in the heart of Bangalore. Perfect for morning walks and bird watching.',
    category: 'walking_path',
    difficulty: 'easy',
    distance: 3500,
    estimatedTimeMinutes: 45,
    startPoint: { latitude: 12.9763, longitude: 77.5929 },
    elevationGain: 15,
    elevationLoss: 15,
    minElevation: 900,
    maxElevation: 915,
    tags: ['park', 'nature', 'walking', 'birds'],
    isPublic: true,
  },
  {
    title: 'Lalbagh Botanical Garden Loop',
    description: 'Explore the famous Lalbagh Botanical Garden with its diverse flora, historic glass house, and serene lake.',
    category: 'nature_walk',
    difficulty: 'easy',
    distance: 4200,
    estimatedTimeMinutes: 60,
    startPoint: { latitude: 12.9507, longitude: 77.5848 },
    elevationGain: 20,
    elevationLoss: 20,
    minElevation: 895,
    maxElevation: 920,
    tags: ['garden', 'botanical', 'nature', 'heritage'],
    isPublic: true,
  },
  {
    title: 'Nandi Hills Sunrise Trek',
    description: 'A challenging trek to the top of Nandi Hills for breathtaking sunrise views. Start early to catch the magical morning mist.',
    category: 'trekking_point',
    difficulty: 'moderate',
    distance: 8000,
    estimatedTimeMinutes: 180,
    startPoint: { latitude: 13.3702, longitude: 77.6835 },
    elevationGain: 450,
    elevationLoss: 450,
    minElevation: 900,
    maxElevation: 1478,
    tags: ['trekking', 'sunrise', 'hills', 'adventure'],
    isPublic: true,
  },
  {
    title: 'Bannerghatta Nature Trail',
    description: 'A wildlife-focused trail through Bannerghatta National Park. Spot deer, peacocks, and various bird species.',
    category: 'nature_walk',
    difficulty: 'moderate',
    distance: 6500,
    estimatedTimeMinutes: 120,
    startPoint: { latitude: 12.8006, longitude: 77.5773 },
    elevationGain: 80,
    elevationLoss: 80,
    minElevation: 850,
    maxElevation: 930,
    tags: ['wildlife', 'national-park', 'nature', 'safari'],
    isPublic: true,
  },
  {
    title: 'Ulsoor Lake Cycling Path',
    description: 'A scenic cycling route around Ulsoor Lake, one of the largest lakes in Bangalore. Great for evening rides.',
    category: 'cycle_path',
    difficulty: 'easy',
    distance: 5000,
    estimatedTimeMinutes: 30,
    startPoint: { latitude: 12.9834, longitude: 77.6211 },
    elevationGain: 5,
    elevationLoss: 5,
    minElevation: 910,
    maxElevation: 915,
    tags: ['cycling', 'lake', 'evening', 'fitness'],
    isPublic: true,
  },
  {
    title: 'Whitefield Tech Park Walk',
    description: 'A morning walking trail through the green spaces of Whitefield tech parks. Popular with IT professionals.',
    category: 'walking_path',
    difficulty: 'easy',
    distance: 2800,
    estimatedTimeMinutes: 35,
    startPoint: { latitude: 12.9698, longitude: 77.7500 },
    elevationGain: 10,
    elevationLoss: 10,
    minElevation: 905,
    maxElevation: 915,
    tags: ['walking', 'tech-park', 'morning', 'fitness'],
    isPublic: true,
  },
  {
    title: 'Hebbal Lake Bird Watching Trail',
    description: 'A peaceful trail around Hebbal Lake, famous for migratory birds during winter months.',
    category: 'nature_walk',
    difficulty: 'easy',
    distance: 3200,
    estimatedTimeMinutes: 50,
    startPoint: { latitude: 13.0358, longitude: 77.5970 },
    elevationGain: 8,
    elevationLoss: 8,
    minElevation: 908,
    maxElevation: 916,
    tags: ['birds', 'lake', 'nature', 'photography'],
    isPublic: true,
  },
  {
    title: 'Skandagiri Night Trek',
    description: 'An adventurous night trek to Skandagiri for stunning sunrise views above the clouds. Requires good fitness.',
    category: 'trekking_point',
    difficulty: 'difficult',
    distance: 9000,
    estimatedTimeMinutes: 240,
    startPoint: { latitude: 13.4242, longitude: 77.6946 },
    elevationGain: 600,
    elevationLoss: 600,
    minElevation: 850,
    maxElevation: 1450,
    tags: ['night-trek', 'sunrise', 'adventure', 'challenging'],
    isPublic: true,
  },
  {
    title: 'Indiranagar Fitness Trail',
    description: 'A popular jogging and fitness trail in Indiranagar with outdoor gym equipment stations.',
    category: 'fitness_center',
    difficulty: 'easy',
    distance: 2000,
    estimatedTimeMinutes: 25,
    startPoint: { latitude: 12.9784, longitude: 77.6408 },
    elevationGain: 5,
    elevationLoss: 5,
    minElevation: 910,
    maxElevation: 915,
    tags: ['fitness', 'jogging', 'gym', 'outdoor'],
    isPublic: true,
  },
  {
    title: 'Turahalli Forest Trek',
    description: 'One of the last remaining green patches in South Bangalore. Great for short nature treks and rock climbing.',
    category: 'trekking_point',
    difficulty: 'moderate',
    distance: 5500,
    estimatedTimeMinutes: 90,
    startPoint: { latitude: 12.8867, longitude: 77.5396 },
    elevationGain: 120,
    elevationLoss: 120,
    minElevation: 880,
    maxElevation: 1000,
    tags: ['forest', 'trekking', 'rock-climbing', 'nature'],
    isPublic: true,
  },
  {
    title: 'MG Road Heritage Walk',
    description: 'A historic walking tour through MG Road, exploring colonial architecture and local landmarks.',
    category: 'point_of_interest',
    difficulty: 'easy',
    distance: 2500,
    estimatedTimeMinutes: 60,
    startPoint: { latitude: 12.9756, longitude: 77.6069 },
    elevationGain: 10,
    elevationLoss: 10,
    minElevation: 905,
    maxElevation: 915,
    tags: ['heritage', 'history', 'architecture', 'city'],
    isPublic: true,
  },
  {
    title: 'Koramangala Jogging Track',
    description: 'A well-maintained jogging track in Koramangala with shade trees and drinking water facilities.',
    category: 'walking_path',
    difficulty: 'easy',
    distance: 3000,
    estimatedTimeMinutes: 35,
    startPoint: { latitude: 12.9352, longitude: 77.6245 },
    elevationGain: 5,
    elevationLoss: 5,
    minElevation: 908,
    maxElevation: 913,
    tags: ['jogging', 'running', 'fitness', 'morning'],
    isPublic: true,
  },
];

async function seedTreks() {
  console.log('Starting trek seed...');
  console.log(`Will create ${sampleTreks.length} sample treks near Bangalore`);
  
  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();
  
  for (const trek of sampleTreks) {
    const docRef = db.collection('treks').doc();
    const geohash = encodeGeohash(trek.startPoint.latitude, trek.startPoint.longitude, 9);
    
    const trekData = {
      title: trek.title,
      description: trek.description,
      category: trek.category,
      difficulty: trek.difficulty,
      distance: trek.distance,
      estimatedTimeMinutes: trek.estimatedTimeMinutes,
      startPoint: trek.startPoint,
      endPoint: trek.startPoint, // Same as start for loop trails
      location: {
        geopoint: trek.startPoint,
        geohash: geohash,
      },
      elevationGain: trek.elevationGain,
      elevationLoss: trek.elevationLoss,
      minElevation: trek.minElevation,
      maxElevation: trek.maxElevation,
      tags: trek.tags,
      isPublic: trek.isPublic,
      rating: 4.0 + Math.random() * 1, // Random rating between 4.0 and 5.0
      reviewCount: Math.floor(Math.random() * 50) + 5, // Random 5-55 reviews
      usersToday: Math.floor(Math.random() * 20), // Random 0-20 users today
      createdAt: now,
      updatedAt: now,
      createdBy: 'system_seed',
      routePoints: [],
      elevationProfile: [],
    };
    
    console.log(`Adding: ${trek.title} (geohash: ${geohash})`);
    batch.set(docRef, trekData);
  }
  
  await batch.commit();
  console.log('\n✅ Successfully seeded all treks!');
  console.log(`Total treks added: ${sampleTreks.length}`);
  process.exit(0);
}

seedTreks().catch(err => {
  console.error('❌ Error seeding treks:', err);
  process.exit(1);
});
