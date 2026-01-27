/**
 * Upload meditation audio files to Firebase Storage
 * 
 * This script uploads large audio files from the local assets folder
 * to Firebase Storage so the app can stream them instead of bundling.
 * 
 * Usage: node upload-audio-files.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin using Application Default Credentials
// Make sure you're logged in with: firebase login
try {
  admin.initializeApp({
    storageBucket: 'livegreen-8319e.firebasestorage.app'
  });
} catch (error) {
  console.error('Failed to initialize Firebase Admin. Make sure you run: firebase login');
  process.exit(1);
}

const bucket = admin.storage().bucket();

// Audio files to upload
const audioFiles = [
  {
    localPath: '../../frontend/assets/sounds/Breeze.mp3',
    storagePath: 'audio/Breeze.mp3',
    description: 'Breeze ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Rain sound.mp3',
    storagePath: 'audio/Rain_sound.mp3',
    description: 'Rain ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Forest_sound.mp3',
    storagePath: 'audio/Forest_sound.mp3',
    description: 'Forest ambiance sound'
  },
  {
    localPath: '../../frontend/assets/sounds/Guided Body Scan Meditation.mp3',
    storagePath: 'audio/Guided_Body_Scan_Meditation.mp3',
    description: 'Guided meditation voice'
  }
];

async function uploadFile(localPath, storagePath, description) {
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

    // Upload to Firebase Storage
    await bucket.upload(fullPath, {
      destination: storagePath,
      metadata: {
        contentType: 'audio/mpeg',
        cacheControl: 'public, max-age=31536000', // Cache for 1 year
      },
      public: true, // Make publicly readable
    });

    console.log(`✅ Upload complete!`);
    
    // Get public URL
    const file = bucket.file(storagePath);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-01-2500', // Far future date
    });
    
    console.log(`   URL: ${url.split('?')[0]}`);
    return true;
  } catch (error) {
    console.error(`❌ Error uploading ${storagePath}:`, error.message);
    return false;
  }
}

async function main() {
  console.log('🎵 Firebase Storage Audio Uploader');
  console.log('==================================\n');
  console.log(`Storage Bucket: ${bucket.name}`);
  
  let successCount = 0;
  let failCount = 0;

  for (const file of audioFiles) {
    const success = await uploadFile(file.localPath, file.storagePath, file.description);
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
