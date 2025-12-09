# Clubs Feature Implementation Guide

## Overview
The Clubs feature allows users to create, discover, and join ecology-focused clubs with admin approval workflow. This guide explains the complete implementation and integration.

## Architecture

### Data Models (frontend/lib/models/club.dart)

**Club**
- id, name, description, imageUrl
- category: ClubCategory enum (environment, wildlife, conservation, sustainability, community, education, health, other)
- status: ClubStatus enum (pending, approved, rejected, archived)
- Creator info: creatorId, creatorName, creatorImageUrl
- Members: leaderIds, memberIds, memberCount
- Location: location, latitude, longitude
- createdAt, approvedAt, rejectedAt, approvedBy
- activityCount, tags
- Contact: website, contactEmail, phoneNumber

**ClubActivity**
- Club posts/events/announcements
- Author info with timestamps
- Like/comment counts
- Event-specific fields: eventDate, location

**ClubMember**
- Track club membership
- Role: 'leader' or 'member'
- joinedAt, isActive

### Services (frontend/lib/services/club_service.dart)

**Key Methods:**
- `createClub()` - Create pending club
- `getApprovedClubs()` - Fetch public clubs with filtering
- `getPendingClubs()` - Admin only
- `getClubById()` - Get single club
- `getUserClubs()` - User's joined clubs
- `getCreatedClubs()` - User's created clubs
- `approveClub()` - Admin approve
- `rejectClub()` - Admin reject with reason
- `joinClub()` / `leaveClub()` - Membership management
- `postActivity()` - Club members post content
- `likeActivity()` / `unlikeActivity()` - Engagement
- `Stream` variants for real-time updates

### UI Screens

**1. ClubsListScreen** (`frontend/lib/screens/community/clubs_list_screen.dart`)
- Browse all approved clubs
- Search & category filtering
- Create club button
- Club cards with stats and tags

**2. CreateClubScreen** (`frontend/lib/screens/community/create_club_screen.dart`)
- Form with validation
- Image picker
- Location capture with GPS
- Tags, contact info
- Explains pending approval

**3. ClubDetailsScreen** (`frontend/lib/screens/community/club_details_screen.dart`)
- 3 tabs: About, Activities, Members
- Join/Leave button
- Club map display
- Activity feed with likes
- Member list with leader badges

**4. MyClubsScreen** (`frontend/lib/screens/community/my_clubs_screen.dart`)
- 2 tabs: Joined, Created
- Shows club status (pending/approved/rejected)
- Create club button
- Links to details

**5. AdminClubApprovalScreen** (`frontend/lib/screens/admin/admin_club_approval_screen.dart`)
- Pending club review interface
- Approve with one click
- Reject with reason dialog
- Full club preview
- Creator info display

### Firestore Rules (backend/firestore.rules)

**Club Collection Rules:**
- Public read for approved clubs
- Authenticated users can create pending clubs
- Creators can update pending clubs
- Admins can approve/reject
- Leaders can update approved clubs
- Activities/Members subcollections scoped accordingly

**Key Security:**
- Pending clubs only visible to creator/admin
- Activity creation restricted to members
- Leader-only modifications to club details

### Cloud Functions (backend/functions/clubNotifications.js)

**Automatic Notifications:**
1. `notifyAdminOnClubCreation` - Alerts admins when club created
2. `notifyCreatorOnClubApproval` - Approval notification to creator
3. `notifyCreatorOnClubRejection` - Rejection reason notification
4. `updateClubActivityCount` - Auto-increment activity counter
5. `cleanupArchivedClubs` - Cleanup after 30 days

**Admin Functions:**
- `getClubStatistics()` - Dashboard stats

## Integration Steps

### 1. Frontend Route Integration

Add to your routes configuration (e.g., `frontend/lib/config/routes.dart`):

```dart
// Club routes
'/clubs': (context) => const ClubsListScreen(),
'/clubs/create': (context) => const CreateClubScreen(),
'/clubs/:id': (context, {id}) => ClubDetailsScreen(clubId: id),
'/my-clubs': (context) => const MyClubsScreen(),
'/admin/clubs': (context) => const AdminClubApprovalScreen(),
```

### 2. Add Navigation

In your Community/Home screen, add:

```dart
// In AppBar or navigation menu
IconButton(
  icon: const Icon(Icons.groups),
  label: const Text('Clubs'),
  onPressed: () => Navigator.pushNamed(context, '/clubs'),
)
```

### 3. Firestore Indexes

If Firestore shows missing index errors, add these indexes:

```
clubs collection:
- Index 1: status (Ascending), createdAt (Descending)
- Index 2: status (Ascending), category (Ascending)
- Index 3: status (Ascending), memberIds (Ascending)
- Index 4: creatorId (Ascending), status (Ascending)

clubs/activities subcollection:
- Index 1: createdAt (Descending)
```

### 4. Deploy Cloud Functions

In backend directory:
```bash
firebase deploy --only functions:notifyAdminOnClubCreation
firebase deploy --only functions:notifyCreatorOnClubApproval
firebase deploy --only functions:notifyCreatorOnClubRejection
firebase deploy --only functions:updateClubActivityCount
firebase deploy --only functions:cleanupArchivedClubs
firebase deploy --only functions:getClubStatistics
```

### 5. Update Admin Panel

In your admin dashboard, add:
```dart
ListTile(
  title: const Text('Club Approvals'),
  leading: const Icon(Icons.verified_user),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminClubApprovalScreen()),
  ),
)
```

## Usage Flow

### For Users (Creating Club)
1. Navigate to Clubs → Create button
2. Fill form: name, description, category, location
3. Add optional image, tags, contact info
4. Submit → Club status = "pending"
5. Wait for admin approval notification
6. Once approved, appears in Clubs list
7. Users can now join and post activities

### For Users (Joining Club)
1. Browse Clubs list with search/filters
2. Tap club → View details
3. Click "Join Club" button
4. Now member - can post activities, see members
5. "Leave Club" to remove membership

### For Leaders
- Can update club details (approved clubs only)
- Can post announcements/events
- Can manage members (add/remove leaders)

### For Admins
1. Get notification when club created
2. Go to Admin → Club Approvals
3. Review club details
4. Click Approve (with verification) or Reject (with reason)
5. Creator gets notification
6. Approved → visible to all users
7. Rejected → feedback to creator

## Database Structure

```
firestore/
├── clubs/{clubId}
│   ├── name: string
│   ├── description: string
│   ├── status: 'pending'|'approved'|'rejected'|'archived'
│   ├── category: string
│   ├── creatorId: string
│   ├── leaderIds: array
│   ├── memberIds: array
│   ├── memberCount: number
│   ├── activityCount: number
│   ├── createdAt: timestamp
│   ├── approvedAt: timestamp (if approved)
│   ├── approvedBy: string (admin uid)
│   ├── rejectionReason: string (if rejected)
│   └── activities/{activityId}
│       ├── authorId: string
│       ├── title: string
│       ├── content: string
│       ├── type: 'post'|'event'|'announcement'
│       ├── createdAt: timestamp
│       ├── likeCount: number
│       ├── commentCount: number
│       └── ... more fields
│   └── members/{userId}
│       ├── clubId: string
│       ├── name: string
│       ├── role: 'leader'|'member'
│       └── joinedAt: timestamp
```

## Testing Checklist

- [ ] Create club form validation
- [ ] Pending club visible to creator only
- [ ] Admin sees pending club in approval screen
- [ ] Approve club → notification to creator
- [ ] Approved club visible in clubs list
- [ ] User can join/leave club
- [ ] Members can post activities
- [ ] Activity counter increments
- [ ] Reject club → rejection reason shown to creator
- [ ] Firestore rules enforce access control
- [ ] Cloud functions deploy successfully

## Future Enhancements

1. **Activity Comments** - Add comment system to activities
2. **Events Calendar** - Schedule events in clubs
3. **Club Roles** - Moderator, event organizer roles
4. **Invitations** - Leaders invite specific users
5. **Club Analytics** - Member engagement metrics
6. **Photo Gallery** - Club photo albums
7. **Discussion Threads** - Topic-based discussions
8. **Club Badges** - Achievement badges for clubs
9. **Search Improvements** - Full-text search across clubs/activities
10. **Recommendations** - ML-based club recommendations

## Troubleshooting

**Issue: "Permission denied" when creating club**
- Check Firebase auth
- Verify user has custom claims set

**Issue: Cloud functions not firing**
- Deploy with `firebase deploy --only functions`
- Check Cloud Functions logs in Firebase Console

**Issue: Images not loading**
- Implement Firebase Storage for image uploads
- Update image URLs in club creation

**Issue: Firestore quota exceeded**
- Add indexes for common queries
- Implement pagination with cursors
