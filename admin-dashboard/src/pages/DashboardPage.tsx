import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  collection,
  collectionGroup,
  query,
  getDocs,
  where,
  orderBy,
  limit,
} from 'firebase/firestore';
import { db } from '../lib/firebase';
import { Users, Building2, MapPin, TrendingUp, Clock, CheckCircle, Activity } from 'lucide-react';

interface Stats {
  totalUsers: number;
  pendingClubs: number;
  pendingPlaces: number;
  todayCompletions: number;
}

interface RecentActivity {
  id: string;
  type: 'user' | 'completion';
  title: string;
  subtitle: string;
  timestamp: Date | null;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats>({
    totalUsers: 0,
    pendingClubs: 0,
    pendingPlaces: 0,
    todayCompletions: 0,
  });
  const [recentActivity, setRecentActivity] = useState<RecentActivity[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      const todayStr = new Date().toISOString().slice(0, 10);

      // ── run independent queries in parallel ──────────────────────────────
      const [usersSnap, pendingClubsSnap, pendingPlacesSnap, recentUsersSnap] =
        await Promise.all([
          getDocs(collection(db, 'users')),
          getDocs(query(collection(db, 'clubs'), where('status', '==', 'pending'))),
          getDocs(collection(db, 'pendingPlaces')),
          getDocs(
            query(collection(db, 'users'), orderBy('createdAt', 'desc'), limit(5))
          ),
        ]);

      // ── today's completions via collectionGroup ───────────────────────────
      let todayCompletions = 0;
      let recentCompletions: RecentActivity[] = [];
      try {
        const [todaySnap, recentSnap] = await Promise.all([
          getDocs(
            query(collectionGroup(db, 'completions'), where('date', '==', todayStr))
          ),
          getDocs(
            query(collectionGroup(db, 'completions'), orderBy('ts', 'desc'), limit(5))
          ),
        ]);
        todayCompletions = todaySnap.size;
        recentCompletions = recentSnap.docs.map(d => {
          const data = d.data();
          const rawId: string = (data.activityId as string) ?? '';
          // activityId can be a Firestore auto-id or a slug — show the date + short id
          const label = rawId.replace(/_/g, ' ').slice(0, 40) || 'activity';
          const shortUid = ((data.uid as string) ?? '').slice(0, 6);
          return {
            id: d.id,
            type: 'completion' as const,
            title: `Completed: ${label}`,
            subtitle: `User …${shortUid} · ${data.date as string}`,
            timestamp: (data.ts as { toDate?: () => Date })?.toDate?.() ?? null,
          };
        });
      } catch {
        // collectionGroup index may not be ready yet — degrade gracefully
      }

      setStats({
        totalUsers: usersSnap.size,
        pendingClubs: pendingClubsSnap.size,
        pendingPlaces: pendingPlacesSnap.size,
        todayCompletions,
      });

      // Combine recent signups + recent completions, sort by time, take top 8
      const recentSignups: RecentActivity[] = recentUsersSnap.docs.map(d => ({
        id: d.id,
        type: 'user' as const,
        title: `New user: ${(d.data().email as string) ?? (d.data().name as string) ?? 'Unknown'}`,
        subtitle: 'Signed up',
        timestamp: (d.data().createdAt as { toDate?: () => Date })?.toDate?.() ?? null,
      }));

      const combined = [...recentSignups, ...recentCompletions]
        .sort((a, b) => (b.timestamp?.getTime() ?? 0) - (a.timestamp?.getTime() ?? 0))
        .slice(0, 8);

      setRecentActivity(combined);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const statCards = [
    {
      title: 'Total Users',
      value: stats.totalUsers,
      icon: Users,
      color: 'bg-blue-500',
      bgColor: 'bg-blue-50',
    },
    {
      title: 'Pending Clubs',
      value: stats.pendingClubs,
      icon: Building2,
      color: 'bg-amber-500',
      bgColor: 'bg-amber-50',
    },
    {
      title: 'Pending Places',
      value: stats.pendingPlaces,
      icon: MapPin,
      color: 'bg-purple-500',
      bgColor: 'bg-purple-50',
    },
    {
      title: "Today's Completions",
      value: stats.todayCompletions,
      icon: TrendingUp,
      color: 'bg-primary-500',
      bgColor: 'bg-primary-50',
    },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-gray-500 mt-1">Welcome to LiveGreen Admin Dashboard</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((stat) => (
          <div
            key={stat.title}
            className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100"
          >
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-500">{stat.title}</p>
                <p className="text-3xl font-bold text-gray-900 mt-1">{stat.value}</p>
              </div>
              <div className={`w-12 h-12 rounded-xl ${stat.bgColor} flex items-center justify-center`}>
                <stat.icon className={`w-6 h-6 ${stat.color.replace('bg-', 'text-')}`} />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Quick Actions & Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Quick Actions */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h2>
          <div className="space-y-3">
            <Link
              to="/clubs"
              className="flex items-center gap-4 p-4 rounded-xl bg-amber-50 hover:bg-amber-100 transition-colors"
            >
              <div className="w-10 h-10 rounded-lg bg-amber-500 flex items-center justify-center">
                <Building2 className="w-5 h-5 text-white" />
              </div>
              <div>
                <p className="font-medium text-gray-900">Review Pending Clubs</p>
                <p className="text-sm text-gray-500">{stats.pendingClubs} clubs waiting for approval</p>
              </div>
            </Link>
            <Link
              to="/places"
              className="flex items-center gap-4 p-4 rounded-xl bg-purple-50 hover:bg-purple-100 transition-colors"
            >
              <div className="w-10 h-10 rounded-lg bg-purple-500 flex items-center justify-center">
                <MapPin className="w-5 h-5 text-white" />
              </div>
              <div>
                <p className="font-medium text-gray-900">Review Pending Places</p>
                <p className="text-sm text-gray-500">{stats.pendingPlaces} places waiting for approval</p>
              </div>
            </Link>
            <Link
              to="/users"
              className="flex items-center gap-4 p-4 rounded-xl bg-blue-50 hover:bg-blue-100 transition-colors"
            >
              <div className="w-10 h-10 rounded-lg bg-blue-500 flex items-center justify-center">
                <Users className="w-5 h-5 text-white" />
              </div>
              <div>
                <p className="font-medium text-gray-900">Manage Users</p>
                <p className="text-sm text-gray-500">View and manage user accounts</p>
              </div>
            </Link>
            <Link
              to="/activities"
              className="flex items-center gap-4 p-4 rounded-xl bg-green-50 hover:bg-green-100 transition-colors"
            >
              <div className="w-10 h-10 rounded-lg bg-green-500 flex items-center justify-center">
                <Activity className="w-5 h-5 text-white" />
              </div>
              <div>
                <p className="font-medium text-gray-900">Manage Activities</p>
                <p className="text-sm text-gray-500">Add, edit or remove daily activities</p>
              </div>
            </Link>
          </div>
        </div>

        {/* Recent Activity */}
        <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h2>
          {recentActivity.length === 0 ? (
            <p className="text-gray-500 text-center py-8">No recent activity</p>
          ) : (
            <div className="space-y-4">
              {recentActivity.map((activity) => (
                <div key={activity.id} className="flex items-center gap-4">
                  <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                    activity.type === 'completion' ? 'bg-green-50' : 'bg-primary-50'
                  }`}>
                    {activity.type === 'completion'
                      ? <CheckCircle className="w-5 h-5 text-green-500" />
                      : <Users className="w-5 h-5 text-primary-500" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {activity.title}
                    </p>
                    <p className="text-xs text-gray-500 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      {activity.subtitle}
                      {activity.timestamp && (
                        <> · {activity.timestamp.toLocaleDateString()}</>
                      )}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
