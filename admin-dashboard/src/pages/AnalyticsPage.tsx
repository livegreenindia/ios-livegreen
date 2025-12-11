import { useEffect, useState } from 'react';
import { collection, query, getDocs, limit, where } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { TrendingUp, Users, Activity, Heart } from 'lucide-react';

export default function AnalyticsPage() {
  const [loading, setLoading] = useState(true);
  const [totalUsers, setTotalUsers] = useState(0);
  const [activeToday, setActiveToday] = useState(0);
  const [avgHappiness, setAvgHappiness] = useState(0);
  const [totalCompletions, setTotalCompletions] = useState(0);

  useEffect(() => {
    loadAnalytics();
  }, []);

  const loadAnalytics = async () => {
    try {
      setLoading(true);

      // Total users
      const usersSnap = await getDocs(collection(db, 'users'));
      setTotalUsers(usersSnap.size);

      // Today's date
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

      // Get happiness scores from last 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      const sevenDaysAgoStr = `${sevenDaysAgo.getFullYear()}-${String(sevenDaysAgo.getMonth() + 1).padStart(2, '0')}-${String(sevenDaysAgo.getDate()).padStart(2, '0')}`;

      // Calculate averages (simplified - would need to iterate users in production)
      let happinessTotal = 0;
      let happinessCount = 0;
      let completionsCount = 0;
      let activeUsers = new Set<string>();

      for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        
        // Get happiness scores
        try {
          const happinessQuery = query(
            collection(db, 'users', userId, 'happiness'),
            where('date', '>=', sevenDaysAgoStr),
            limit(10)
          );
          const happinessSnap = await getDocs(happinessQuery);
          happinessSnap.docs.forEach(doc => {
            const data = doc.data();
            if (data.score) {
              happinessTotal += data.score;
              happinessCount++;
            }
            if (data.date === todayStr) {
              activeUsers.add(userId);
            }
          });
        } catch (e) {
          // Skip if subcollection doesn't exist
        }

        // Get completions count
        try {
          const completionsQuery = query(
            collection(db, 'users', userId, 'completions'),
            where('date', '>=', sevenDaysAgoStr)
          );
          const completionsSnap = await getDocs(completionsQuery);
          completionsCount += completionsSnap.size;
          completionsSnap.docs.forEach(doc => {
            if (doc.data().date === todayStr) {
              activeUsers.add(userId);
            }
          });
        } catch (e) {
          // Skip if subcollection doesn't exist
        }
      }

      setActiveToday(activeUsers.size);
      setAvgHappiness(happinessCount > 0 ? Math.round((happinessTotal / happinessCount) * 10) : 0);
      setTotalCompletions(completionsCount);

    } catch (error) {
      console.error('Error loading analytics:', error);
    } finally {
      setLoading(false);
    }
  };

  const stats = [
    {
      title: 'Total Users',
      value: totalUsers.toLocaleString(),
      icon: Users,
      color: 'text-blue-500',
      bgColor: 'bg-blue-50',
    },
    {
      title: 'Active Today',
      value: activeToday.toLocaleString(),
      icon: Activity,
      color: 'text-green-500',
      bgColor: 'bg-green-50',
    },
    {
      title: 'Avg. Wellness (7d)',
      value: `${avgHappiness}%`,
      icon: Heart,
      color: 'text-red-500',
      bgColor: 'bg-red-50',
    },
    {
      title: 'Activities (7d)',
      value: totalCompletions.toLocaleString(),
      icon: TrendingUp,
      color: 'text-primary-500',
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
        <h1 className="text-2xl font-bold text-gray-900">Analytics</h1>
        <p className="text-gray-500 mt-1">Overview of app usage and engagement</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((stat) => (
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
                <stat.icon className={`w-6 h-6 ${stat.color}`} />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Info Card */}
      <div className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">Analytics Overview</h2>
        <p className="text-gray-600">
          This dashboard provides a high-level overview of your app's usage. The stats above show:
        </p>
        <ul className="mt-4 space-y-2 text-gray-600">
          <li className="flex items-center gap-2">
            <Users className="w-4 h-4 text-blue-500" />
            <strong>Total Users:</strong> All registered users in the system
          </li>
          <li className="flex items-center gap-2">
            <Activity className="w-4 h-4 text-green-500" />
            <strong>Active Today:</strong> Users who logged wellness or completed activities today
          </li>
          <li className="flex items-center gap-2">
            <Heart className="w-4 h-4 text-red-500" />
            <strong>Avg. Wellness:</strong> Average wellness score from the last 7 days (as percentage)
          </li>
          <li className="flex items-center gap-2">
            <TrendingUp className="w-4 h-4 text-primary-500" />
            <strong>Activities:</strong> Total completed activities in the last 7 days
          </li>
        </ul>
      </div>
    </div>
  );
}
