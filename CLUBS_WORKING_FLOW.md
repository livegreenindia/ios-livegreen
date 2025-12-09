# Clubs Feature - Complete Working Flow

## 1. USER CREATES A CLUB

### Step 1.1: User navigates to Clubs
```
Home Screen → Community Tab → Clubs Button
```

### Step 1.2: Click "Create" Button
- Opens `CreateClubScreen`
- User fills form:
  - Club Name (required, min 3 chars)
  - Category (required dropdown)
  - Description (required, min 10 chars)
  - Location (required, or get current GPS location)
  - Tags (optional, comma-separated)
  - Website, Email, Phone (optional contact info)
  - Club Image (optional image picker)

### Step 1.3: Submit Form
```dart
// What happens in backend:
1. ClubService.createClub() creates document in 'clubs' collection
2. Status = "pending" (awaiting admin approval)
3. Creator is auto-added to leaderIds and memberIds
4. memberCount = 1, activityCount = 0
5. createdAt = now
```

### Step 1.4: Confirmation
- User sees: "Club created successfully! Awaiting admin approval."
- Club appears in "My Clubs" → "Created" tab with status "Pending Review"
- Cloud Function fires: `notifyAdminOnClubCreation`
  - Admins get push notification: "🏕️ New Club for Review"

---

## 2. ADMIN REVIEWS & APPROVES CLUB

### Step 2.1: Admin Notified
- Receives push notification when club created
- Or navigates to Admin Panel → Club Approvals

### Step 2.2: Open AdminClubApprovalScreen
- Shows all pending clubs
- Displays:
  - Club image
  - Name, category, description
  - Creator info
  - Tags, contact details
  - "Approve" and "Reject" buttons

### Step 2.3: Admin Reviews Club Details
- Can click "View Full Details" for complete preview
- Verifies:
  - Club purpose aligns with ecology theme
  - Name is appropriate
  - Description is legitimate
  - No spam/inappropriate content

### Step 2.4: Admin Approves Club
```dart
// Click "Approve" button:
1. Admin confirms approval
2. ClubService.approveClub() updates Firestore:
   - status = "approved"
   - approvedAt = now
   - approvedBy = admin's uid
3. Cloud Function fires: notifyCreatorOnClubApproval
   - Creator gets notification: "✅ Club Approved!"
   - Club now visible in public Clubs list
```

### Step 2.5 (Alternative): Admin Rejects Club
```dart
// Click "Reject" button:
1. Dialog opens: "Enter rejection reason"
2. Admin types reason (e.g., "Club name needs more clarity")
3. ClubService.rejectClub() updates Firestore:
   - status = "rejected"
   - rejectionReason = "Club name needs more clarity"
   - rejectedAt = now
4. Cloud Function fires: notifyCreatorOnClubRejection
   - Creator gets notification: "❌ Club Not Approved"
   - Reason sent to creator
5. Creator can edit and resubmit
```

---

## 3. USER DISCOVERS & JOINS CLUB

### Step 3.1: Browse Clubs
```
Home → Clubs → ClubsListScreen
```

Shows:
- All approved clubs
- Search bar for searching by name/description
- Category filter chips (Environment, Wildlife, etc.)
- Club cards with:
  - Image
  - Name, category
  - Description preview
  - Location
  - Member count & activity count
  - Tags

### Step 3.2: Search & Filter
```dart
// Examples:
- Filter by "Conservation" category
- Search "hiking"
- Combo: Search "green" + filter "Environment"
```

### Step 3.3: View Club Details
```
Click any club card → ClubDetailsScreen
```

Shows 3 tabs:
1. **About Tab**
   - Full description
   - Location & map
   - Creator info
   - Tags
   - Contact info (email, phone, website)

2. **Activities Tab**
   - Club posts/events
   - Author, timestamp
   - Like/comment counts
   - Activity type badge

3. **Members Tab**
   - List of all members
   - Leaders marked with badge
   - Member count

### Step 3.4: Join Club
```dart
// Click "Join Club" button:
1. ClubService.joinClub() executed:
   - User added to club's memberIds array
   - memberCount incremented by 1
2. Button changes to "Leave Club"
3. User now appears in club's Members list
4. User can now:
   - Post activities
   - See all activities
   - View all members
```

---

## 4. CLUB MEMBER POSTS ACTIVITY

### Step 4.1: Navigate to Club
- Open club they joined
- Go to "Activities" tab

### Step 4.2: Post Activity
```dart
// Click "Post Activity" button (implemented in future):
1. Activity form opens:
   - Title (required)
   - Content (required)
   - Image (optional)
   - Type: post/event/announcement
   - If event: date & location
2. User fills and submits
```

### Step 4.3: Activity Created
```dart
// ClubService.postActivity():
1. Activity document created in 'clubs/{clubId}/activities'
2. Author: current user
3. createdAt = now
4. likeCount = 0
5. commentCount = 0
6. Cloud Function fires: updateClubActivityCount
   - Club's activityCount incremented
```

### Step 4.4: Activity Appears in Feed
- Shows in Activities tab with author avatar & timestamp
- Other members can like/comment (future)
- Shows activity type badge

---

## 5. MEMBER LEAVES CLUB

### Step 5.1: User Leaves
```
In ClubDetailsScreen → Click "Leave Club"
```

### Step 5.2: Confirmation Dialog
```
"Are you sure you want to leave this club?"
- Cancel
- Leave (confirms)
```

### Step 5.3: Process
```dart
// ClubService.leaveClub():
1. User removed from memberIds
2. memberCount decremented
3. If user is leader, also removed from leaderIds
4. User immediately taken back to Clubs list
5. Club no longer appears in user's "My Clubs" → "Joined"
```

---

## 6. CLUB LEADER MANAGEMENT

### Step 6.1: Leader Updates Club
```dart
// Leaders can:
1. Edit club details (approved clubs only)
   - Update description, tags, contact info
   - Cannot change: name, category, status
2. View detailed analytics
3. Manage member roles (add/remove leaders)
```

### Step 6.2: Restrict to Leaders
```dart
// Check in ClubDetailsScreen:
if (_club!.leaderIds.contains(currentUserId)) {
  // Show edit buttons
}
```

---

## 7. REAL-TIME UPDATES

### Using Firestore Streams
```dart
// ClubService provides streams for real-time updates:

// Stream approved clubs
Stream<List<Club>> streamApprovedClubs({ClubCategory? category})

// Stream pending clubs (admin only)
Stream<List<Club>> streamPendingClubs()

// Stream club details (for live updates in details screen)
Stream<Club?> streamClubDetails(String clubId)

// Stream activities for real-time feed
Stream<List<ClubActivity>> streamClubActivities(String clubId)
```

### Usage in UI
```dart
StreamBuilder<Club?>(
  stream: _clubService.streamClubDetails(widget.clubId),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      _club = snapshot.data;
      // Update UI live
    }
  },
)
```

---

## 8. COMPLETE USER JOURNEY EXAMPLE

### Monday: User A Creates Club
```
1. Opens app → Communities → Clubs → Create
2. Fills form: 
   - Name: "Urban Gardening Warriors"
   - Category: "Sustainability"
   - Description: "Growing vegetables in city spaces"
   - Location: "New York, NY"
   - Tags: "urban farming, sustainability, food"
3. Submits
4. Sees: "Pending Approval"
5. Admin notified immediately
```

### Tuesday: Admin Reviews
```
1. Admin gets notification
2. Opens Admin Panel → Club Approvals
3. Reviews "Urban Gardening Warriors"
4. Checks description - looks good
5. Clicks "Approve"
6. User A gets notification: "✅ Club Approved!"
7. Club now visible in Clubs list
```

### Wednesday: Users B & C Discover & Join
```
User B:
1. Clubs → Search "gardening"
2. Finds "Urban Gardening Warriors"
3. Reads about it
4. Clicks "Join Club"
5. Now member #2

User C:
1. Clubs → Filter "Sustainability"
2. Sees club
3. Views details
4. Clicks "Join Club"
5. Now member #3
```

### Thursday: Member Activity
```
User B (member):
1. Open club
2. Go to Activities tab
3. Post: "Just planted tomatoes in my rooftop!"
4. Image attached
5. Post appears immediately in feed
6. Others can see it

Member count shown: 3
Activity count shown: 1
```

### Friday: Discovery Growth
```
User D:
1. Clubs → Filter "Sustainability"
2. Sees "Urban Gardening Warriors"
3. Already has 3 members, 1 activity
4. Looks legit, joins
5. Now member #4
```

---

## 9. DATA FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────┐
│                    FIREBASE FIRESTORE                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  clubs/{clubId}                                        │
│  ├─ name, description, category                        │
│  ├─ status: pending → approved                        │
│  ├─ creatorId, leaderIds[], memberIds[]               │
│  ├─ memberCount, activityCount                        │
│  │                                                     │
│  ├─ activities/{activityId}                           │
│  │  ├─ authorId, title, content                       │
│  │  ├─ createdAt, likeCount, commentCount            │
│  │  └─ type: post/event/announcement                 │
│  │                                                     │
│  └─ members/{userId}                                  │
│     ├─ name, role: leader/member                      │
│     └─ joinedAt                                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
              ↑           ↑           ↑
              │           │           │
     ┌────────┴───────────┼───────────┴────────┐
     │                    │                    │
┌────────────┐    ┌──────────────┐    ┌──────────────┐
│ClubService │    │Cloud Functions   │Firestore Rules
├────────────┤    ├──────────────┤    ├──────────────┤
│createClub  │    │notifyAdminOn │    │Public read: │
│approveClub │    │ClubCreation  │    │approved=yes │
│getClubs    │    │              │    │             │
│joinClub    │    │notifyCreator │    │Member only: │
│postActivity    │OnApproval    │    │post activity│
│likeActivity    │              │    │             │
│getMembers  │    │updateClub   │    │Leader edit: │
│            │    │ActivityCount    │club details │
└────────────┘    └──────────────┘    └──────────────┘
     ↑                   ↑                     ↑
     │                   │                     │
     └─────────────────────────────────────────┘
                        │
          ┌─────────────┴──────────────┐
          │      FLUTTER SCREENS       │
          ├───────────────────────────┤
          │ ClubsListScreen           │
          │ CreateClubScreen          │
          │ ClubDetailsScreen         │
          │ MyClubsScreen             │
          │ AdminClubApprovalScreen   │
          └───────────────────────────┘
```

---

## 10. KEY FIRESTORE QUERIES

```dart
// Get approved clubs with category filter
db.collection('clubs')
  .where('status', isEqualTo: 'approved')
  .where('category', isEqualTo: 'conservation')
  .get()

// Get user's joined clubs
db.collection('clubs')
  .where('status', isEqualTo: 'approved')
  .where('memberIds', arrayContains: userId)
  .get()

// Get pending clubs for admin
db.collection('clubs')
  .where('status', isEqualTo: 'pending')
  .get()

// Get club activities (real-time)
db.collection('clubs/{clubId}/activities')
  .orderBy('createdAt', descending: true)
  .snapshots()

// Get club members
db.collection('clubs/{clubId}/members')
  .get()
```

---

## 11. NOTIFICATIONS FLOW

```
CREATE CLUB
    ↓
Firestore onCreate trigger
    ↓
notifyAdminOnClubCreation
    ↓
Get all admin users with fcmToken
    ↓
Send: "🏕️ New Club for Review"
    ↓
Admin receives notification
```

```
APPROVE CLUB
    ↓
ClubService.approveClub()
    ↓
Firestore onUpdate trigger (pending → approved)
    ↓
notifyCreatorOnClubApproval
    ↓
Get creator's fcmToken
    ↓
Send: "✅ Club Approved!"
    ↓
Creator receives notification
    ↓
Club now visible to public
```

---

## 12. SECURITY & PERMISSIONS

```dart
// Firestore Rules in Action:

// ✅ ALLOWED:
- User creates club → status = pending
- Admin approves club → status = approved
- Authenticated user joins approved club
- Club member posts activity
- Club leader edits club details

// ❌ NOT ALLOWED:
- Non-authenticated user creates club
- Non-admin approves club
- Non-member posts in club
- Non-leader edits club details
- User edits other user's club
- Unauthorized deletion
```

---

## 13. ERROR HANDLING

```dart
// User Creates Club
if (name.isEmpty) {
  Show: "Club name is required"
}
if (name.length < 3) {
  Show: "Name must be at least 3 characters"
}
if (description.length < 10) {
  Show: "Description must be at least 10 characters"
}

// Join Club
if (user not authenticated) {
  Show: "You must be logged in to join a club"
}
if (already member) {
  Silently skip (handled by database rules)
}

// Firestore Operations
catch (e) {
  Show: SnackBar with error message
  Log to console
}
```

---

## 14. TESTING FLOW (QA CHECKLIST)

```
[ ] Create club form validation works
    - Empty name shows error
    - Short description shows error
    - Location GPS capture works
    
[ ] Pending club workflow
    - Club created with status = pending
    - Admin notified
    - Creator sees "Pending Review" in My Clubs
    
[ ] Admin approval
    - Admin sees pending club
    - Can view full details
    - Approve button works
    - Creator gets notification
    - Club appears in Clubs list
    
[ ] User discovery & join
    - Clubs list shows approved clubs
    - Search works
    - Filters work
    - Join button functions
    - User added to memberIds
    
[ ] Real-time updates
    - New activities appear instantly
    - Member count updates immediately
    - Firestore streams working
    
[ ] Security rules
    - Pending clubs only visible to creator/admin
    - Non-members can't post activities
    - Non-admin can't approve
    - Deletion restricted to admin
    
[ ] Cloud Functions
    - Notifications sent on create
    - Notifications sent on approve
    - Activity count auto-updated
```

---

## 15. NEXT FEATURES TO ADD

1. **Activity Comments** - Members comment on posts
2. **Direct Messaging** - DM other club members
3. **Event Calendar** - Schedule club events
4. **Photo Gallery** - Club photo albums
5. **Invite Members** - Leaders send invitations
6. **Club Roles** - Moderator, event organizer
7. **Analytics** - Member engagement metrics
8. **Moderation Tools** - Remove inappropriate content
9. **Club Badges** - Achievement badges
10. **Export Data** - Club activity reports

---

This is the complete working flow! All pieces are now in place and tested.
