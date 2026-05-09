import { useEffect, useState } from 'react';
import { doc, setDoc, serverTimestamp, writeBatch } from 'firebase/firestore';
import { db, auth } from '../lib/firebase';
import { Search, Shield, ShieldOff, Loader2, AlertCircle, Rss, Users } from 'lucide-react';

const API_BASE = import.meta.env.VITE_API_BASE_URL as string;

interface User {
  id: string;
  uid: string;
  email: string;
  displayName?: string;
  role?: string;
  isAdmin?: boolean;
  feedAccess?: boolean;
  plan?: string;
  createdAt?: string;
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState<string | null>(null);
  const [bulkUpdating, setBulkUpdating] = useState(false);

  useEffect(() => {
    loadUsers();
  }, []);

  const getToken = async () => {
    const currentUser = auth.currentUser;
    if (!currentUser) throw new Error('Not logged in');
    return currentUser.getIdToken();
  };

  const loadUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      const token = await getToken();
      const res = await fetch(`${API_BASE}/admin/users`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.error || `HTTP ${res.status}`);
      }
      const data = await res.json();
      const usersData: User[] = (data.users || []).map((u: any) => ({
        id: u.uid,
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        role: u.role,
        isAdmin: u.isAdmin,
        feedAccess: u.feedAccess,
        plan: u.plan,
        createdAt: u.createdAt,
      }));
      // Sort: newest first (nulls last)
      usersData.sort((a, b) =>
        new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime()
      );
      setUsers(usersData);
    } catch (err: any) {
      console.error('Error loading users:', err);
      setError(err.message || 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const toggleAdminRole = async (userId: string, currentIsAdmin: boolean) => {
    try {
      setUpdating(userId);
      const newRole = currentIsAdmin ? 'user' : 'admin';
      // Write directly to Firestore (upsert — creates doc if it doesn't exist)
      await setDoc(
        doc(db, 'users', userId),
        { role: newRole, isAdmin: !currentIsAdmin, updatedAt: serverTimestamp() },
        { merge: true }
      );
      setUsers(prev =>
        prev.map(user =>
          user.id === userId
            ? { ...user, role: newRole, isAdmin: !currentIsAdmin }
            : user
        )
      );
    } catch (err: any) {
      console.error('Error updating admin role:', err);
      alert('Failed to update admin role: ' + err.message);
    } finally {
      setUpdating(null);
    }
  };

  const filteredUsers = users.filter(user => {
    const search = searchTerm.toLowerCase();
    return (
      user.email?.toLowerCase().includes(search) ||
      user.displayName?.toLowerCase().includes(search)
    );
  });

  const isUserAdmin = (user: User) => user.role === 'admin' || user.isAdmin === true;

  const hasFeedAccess = (user: User) => isUserAdmin(user) || user.feedAccess === true;

  const bulkSetFeed = async (enable: boolean) => {
    const targets = users.filter(u => !isUserAdmin(u) && (enable ? !u.feedAccess : u.feedAccess));
    if (targets.length === 0) return alert(enable ? 'All users already have feed access.' : 'No users have feed access to disable.');
    if (!confirm(`${enable ? 'Enable' : 'Disable'} feed access for ${targets.length} user(s)?`)) return;
    try {
      setBulkUpdating(true);
      const CHUNK = 500;
      for (let i = 0; i < targets.length; i += CHUNK) {
        const batch = writeBatch(db);
        targets.slice(i, i + CHUNK).forEach(u => {
          batch.set(doc(db, 'users', u.uid), { feedAccess: enable, updatedAt: serverTimestamp() }, { merge: true });
        });
        await batch.commit();
      }
      setUsers(prev =>
        prev.map(u => (!isUserAdmin(u) ? { ...u, feedAccess: enable } : u))
      );
    } catch (err: any) {
      console.error('Bulk feed update failed:', err);
      alert('Bulk update failed: ' + err.message);
    } finally {
      setBulkUpdating(false);
    }
  };

  const toggleFeedAccess = async (userId: string, currentAccess: boolean) => {
    try {
      setUpdating(userId + '_feed');
      await setDoc(
        doc(db, 'users', userId),
        { feedAccess: !currentAccess, updatedAt: serverTimestamp() },
        { merge: true }
      );
      setUsers(prev =>
        prev.map(user =>
          user.id === userId ? { ...user, feedAccess: !currentAccess } : user
        )
      );
    } catch (err: any) {
      console.error('Error updating feed access:', err);
      alert('Failed to update feed access: ' + err.message);
    } finally {
      setUpdating(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Users</h1>
          <p className="text-gray-500 mt-1">Manage user accounts and admin roles</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => bulkSetFeed(true)}
            disabled={bulkUpdating || loading}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm bg-green-50 text-green-700 border border-green-200 rounded-xl hover:bg-green-100 disabled:opacity-50"
          >
            {bulkUpdating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Users className="w-4 h-4" />}
            Enable Feed for All
          </button>
          <button
            onClick={() => bulkSetFeed(false)}
            disabled={bulkUpdating || loading}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm bg-red-50 text-red-700 border border-red-200 rounded-xl hover:bg-red-100 disabled:opacity-50"
          >
            {bulkUpdating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Users className="w-4 h-4" />}
            Disable Feed for All
          </button>
          <button onClick={loadUsers} className="px-3 py-2 text-sm border border-gray-300 rounded-xl hover:bg-gray-50">
            Refresh
          </button>
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search users..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-10 pr-4 py-2 border border-gray-300 rounded-xl focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none w-full sm:w-64"
            />
          </div>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-3 p-4 bg-red-50 border border-red-200 rounded-xl text-red-700">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span className="text-sm">{error}</span>
        </div>
      )}

      {/* Users Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100">
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">User</th>
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">Role</th>
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">Feed Access</th>
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">Plan</th>
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">Joined</th>
                <th className="text-right py-4 px-6 text-sm font-medium text-gray-500">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center">
                    <div className="flex items-center justify-center">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
                    </div>
                  </td>
                </tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-gray-500">
                    No users found
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => (
                  <tr key={user.id} className="border-b border-gray-100 hover:bg-gray-50">
                    <td className="py-4 px-6">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-primary-100 flex items-center justify-center">
                          <span className="text-sm font-medium text-primary-600">
                            {(user.displayName || user.email)?.[0]?.toUpperCase() || '?'}
                          </span>
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">
                            {user.displayName || 'No name'}
                          </p>
                          <p className="text-sm text-gray-500">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <span
                        className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium ${
                          isUserAdmin(user)
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {isUserAdmin(user) ? (
                          <>
                            <Shield className="w-3 h-3" />
                            Admin
                          </>
                        ) : (
                          'User'
                        )}
                      </span>
                    </td>
                    <td className="py-4 px-6">
                      <button
                        onClick={() => !isUserAdmin(user) && toggleFeedAccess(user.id, hasFeedAccess(user))}
                        disabled={updating === user.id + '_feed' || isUserAdmin(user)}
                        title={isUserAdmin(user) ? 'Admins always have feed access' : (hasFeedAccess(user) ? 'Revoke feed access' : 'Grant feed access')}
                        className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium transition-colors ${
                          hasFeedAccess(user)
                            ? 'bg-green-100 text-green-700 hover:bg-green-200'
                            : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                        } disabled:cursor-default`}
                      >
                        {updating === user.id + '_feed' ? (
                          <Loader2 className="w-3 h-3 animate-spin" />
                        ) : (
                          <Rss className="w-3 h-3" />
                        )}
                        {hasFeedAccess(user) ? 'Enabled' : 'Disabled'}
                      </button>
                    </td>
                    <td className="py-4 px-6">
                      <span
                        className={`inline-flex px-2.5 py-1 rounded-full text-xs font-medium ${
                          user.plan === 'Premium'
                            ? 'bg-primary-100 text-primary-700'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {user.plan || 'Free'}
                      </span>
                    </td>
                    <td className="py-4 px-6 text-sm text-gray-500">
                      {user.createdAt ? new Date(user.createdAt).toLocaleDateString() : '-'}
                    </td>
                    <td className="py-4 px-6 text-right">
                      <button
                        onClick={() => toggleAdminRole(user.id, isUserAdmin(user))}
                        disabled={updating === user.id}
                        className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                          isUserAdmin(user)
                            ? 'bg-red-50 text-red-600 hover:bg-red-100'
                            : 'bg-amber-50 text-amber-600 hover:bg-amber-100'
                        } disabled:opacity-50`}
                      >
                        {updating === user.id ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : isUserAdmin(user) ? (
                          <>
                            <ShieldOff className="w-4 h-4" />
                            Remove Admin
                          </>
                        ) : (
                          <>
                            <Shield className="w-4 h-4" />
                            Make Admin
                          </>
                        )}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
        {!loading && users.length > 0 && (
          <div className="px-6 py-3 border-t border-gray-100 text-sm text-gray-500">
            {filteredUsers.length} of {users.length} users
          </div>
        )}
      </div>
    </div>
  );
}
