# LiveGreen Website Hosting

This folder contains the simple redirect website for deep linking.

## Files
- `index.html` - Main redirect page that handles club deep links

## How It Works
1. User clicks link: `https://livegreen.app/clubs/abc123`
2. Page tries to open app: `livegreen://clubs/abc123`
3. If app installed → Opens directly in app
4. If not installed → Redirects to Play Store after 4 seconds

## Hosting Options

### Option 1: Firebase Hosting (Free)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize in this directory
cd c:\Employee\livegreen\website
firebase init hosting

# Select:
# - Use existing project (livegreen-xxx)
# - Public directory: . (current directory)
# - Configure as single-page app: Yes
# - Set up automatic builds: No

# Deploy
firebase deploy --only hosting
```

### Option 2: Netlify (Free)
1. Go to https://netlify.com
2. Drag and drop the `website` folder
3. Configure custom domain: livegreen.app

### Option 3: GitHub Pages (Free)
```bash
# Create a new repo: livegreen-website
# Push this folder
# Enable GitHub Pages in repo settings
```

### Option 4: Vercel (Free)
```bash
npm install -g vercel
cd c:\Employee\livegreen\website
vercel
```

## Domain Setup

Once hosted, point your domain `livegreen.app` to the hosting:

### For Firebase:
```bash
firebase hosting:channel:deploy live
# Follow instructions to add custom domain
```

### DNS Records:
- **A Record**: Point to hosting IP
- **CNAME**: www → your-site.netlify.app (or firebase)

## Testing

Test the link:
```
https://livegreen.app/clubs/test123
```

Should:
1. Try to open app
2. Show "Download from Play Store" button
3. Auto-redirect after 4 seconds
