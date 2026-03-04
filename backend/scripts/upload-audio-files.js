/**
 * Upload meditation audio files to Firebase Storage
 * 
 * This script uploads large audio files from the local assets folder
 * to Firebase Storage so the app can stream them instead of bundling.
 * 
 * Usage: node upload-audio-files.js
 * Requires: firebase login (uses Firebase CLI credentials)
 */

const { Storage } = require('@google-cloud/storage');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const BUCKET_NAME = 'livegreen-bf838.firebasestorage.app';

// Firebase CLI OAuth2 client credentials (public, same as firebase-tools uses)
const FIREBASE_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function getFirebaseRefreshToken() {
  const configPath = path.join(
    process.env.USERPROFILE || process.env.HOME || '',
    '.config', 'configstore', 'firebase-tools.json'
  );
  
  if (!fs.existsSync(configPath)) {
    throw new Error('Firebase CLI config not found. Run: firebase login');
  }
  
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  
  if (!refreshToken) {
    throw new Error('No refresh token in Firebase CLI config. Run: firebase login');
  }
  
  return refreshToken;
}

function createAuthenticatedStorage() {
  const refreshToken = getFirebaseRefreshToken();
  
  const oauth2Client = new OAuth2Client(FIREBASE_CLIENT_ID, FIREBASE_CLIENT_SECRET);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  
  return new Storage({ authClient: oauth2Client });
}

// Audio files to upload
const audioFiles = [
  {
    localPath: '../../frontend/assets/sounds/Breeze.mp3',
    storagePath: 'audio/Breeze.mp3',
    description: 'Breeze ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Rain_sound.mp3',
    storagePath: 'audio/Rain_sound.mp3',
    description: 'Rain ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Forest_sound.mp3',
    storagePath: 'audio/Forest_sound.mp3',
    description: 'Forest ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Guided_Body_Scan_Meditation.mp3',
    storagePath: 'audio/Guided_Body_Scan_Meditation.mp3',
    description: 'Guided meditation voice'
  }
];

async function uploadFile(bucket, localPath, storagePath, description) {
  const fullPath = path.resolve(__dirname, localPath);
  
  // Check if file exists
  if (!fs.existsSync(fullPath)) {
    console.log(`❌ File not found: ${fullPath}`);
    return false;
  }

  try {
    const fileSize = fs.statSync(fullPath).size;
    const fileSizeMB = (fileSize / (1024 * 1024)).toFixed(2);
    
    console.log(`\n📤 Uploading ${description}...`);
    console.log(`   Local: ${fullPath}`);
    console.log(`   Size: ${fileSizeMB} MB`);
    console.log(`   Storage: ${storagePath}`);

    // Retry up to 3 times for large file uploads
    const maxRetries = 3;
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await bucket.upload(fullPath, {
          destination: storagePath,
          resumable: true,
          metadata: {
            contentType: 'audio/mpeg',
            cacheControl: 'public, max-age=31536000', // Cache for 1 year
          },
        });

        // Make publicly readable
        await bucket.file(storagePath).makePublic();

        const publicUrl = `https://storage.googleapis.com/${BUCKET_NAME}/${storagePath}`;
        console.log(`✅ Upload complete! (attempt ${attempt})`);
        console.log(`   URL: ${publicUrl}`);
        return true;
      } catch (retryErr) {
        if (attempt < maxRetries) {
          console.log(`   ⚠️ Attempt ${attempt} failed: ${retryErr.message}`);
          console.log(`   Retrying in 5 seconds...`);
          await new Promise(r => setTimeout(r, 5000));
        } else {
          throw retryErr;
        }
      }
    }
  } catch (error) {
    console.error(`❌ Error uploading ${storagePath}:`, error.message);
    return false;
  }
}

async function main() {
  console.log('🎵 Firebase Storage Audio Uploader');
  console.log('==================================\n');
  
  const storage = createAuthenticatedStorage();
  const bucket = storage.bucket(BUCKET_NAME);
  console.log(`Storage Bucket: ${BUCKET_NAME}`);
  console.log('Authenticated via Firebase CLI credentials\n');
  
  let successCount = 0;
  let failCount = 0;

  for (const file of audioFiles) {
    const success = await uploadFile(bucket, file.localPath, file.storagePath, file.description);
    if (success) {
      successCount++;
    } else {
      failCount++;
    }
  }

  console.log('\n==================================');
  console.log('📊 Upload Summary:');
  console.log(`   ✅ Success: ${successCount}`);
  console.log(`   ❌ Failed: ${failCount}`);
  console.log('\nNext steps:');
  console.log('1. Deploy storage rules: firebase deploy --only storage');
  console.log('2. Build new app bundle: flutter build appbundle --release');
  
  process.exit(failCount > 0 ? 1 : 0);
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
