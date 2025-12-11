import { useEffect, useState } from 'react';
import { collection, query, getDocs, doc, updateDoc, orderBy, limit, startAfter, DocumentData, QueryDocumentSnapshot } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { Search, Shield, ShieldOff, ChevronLeft, ChevronRight, Loader2 } from 'lucide-react';

interface User {
  id: string;
  email: string;
  name?: string;
  displayName?: string;
  role?: string;
  isAdmin?: boolean;
  plan?: string;
  createdAt?: Date;
}

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [updating, setUpdating] = useState<string | null>(null);
  const [lastDoc, setLastDoc] = useState<QueryDocumentSnapshot<DocumentData> | null>(null);
  const [hasMore, setHasMore] = useState(true);
  const pageSize = 20;

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async (loadMore = false) => {
    try {
      setLoading(true);
      let q = query(
        collection(db, 'users'),
        orderBy('email'),
        limit(pageSize)
      );

      if (loadMore && lastDoc) {
        q = query(
          collection(db, 'users'),
          orderBy('email'),
          startAfter(lastDoc),
          limit(pageSize)
        );
      }

      const snapshot = await getDocs(q);
      const usersData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate(),
      })) as User[];

      if (loadMore) {
        setUsers(prev => [...prev, ...usersData]);
      } else {
        setUsers(usersData);
      }

      setLastDoc(snapshot.docs[snapshot.docs.length - 1] || null);
      setHasMore(snapshot.docs.length === pageSize);
    } catch (error) {
      console.error('Error loading users:', error);
    } finally {
      setLoading(false);
    }
  };

  const toggleAdminRole = async (userId: string, currentIsAdmin: boolean) => {
    try {
      setUpdating(userId);
      const userRef = doc(db, 'users', userId);
      
      if (currentIsAdmin) {
        // Remove admin role
        await updateDoc(userRef, {
          role: 'user',
          isAdmin: false,
        });
      } else {
        // Add admin role
        await updateDoc(userRef, {
          role: 'admin',
          isAdmin: true,
        });
      }

      // Update local state
      setUsers(prev =>
        prev.map(user =>
          user.id === userId
            ? { ...user, role: currentIsAdmin ? 'user' : 'admin', isAdmin: !currentIsAdmin }
            : user
        )
      );
    } catch (error) {
      console.error('Error updating admin role:', error);
      alert('Failed to update admin role');
    } finally {
      setUpdating(null);
    }
  };

  const filteredUsers = users.filter(user => {
    const search = searchTerm.toLowerCase();
    return (
      user.email?.toLowerCase().includes(search) ||
      user.name?.toLowerCase().includes(search) ||
      user.displayName?.toLowerCase().includes(search)
    );
  });

  const isAdmin = (user: User) => user.role === 'admin' || user.isAdmin === true;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Users</h1>
          <p className="text-gray-500 mt-1">Manage user accounts and admin roles</p>
        </div>
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

      {/* Users Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100">
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">User</th>
                <th className="text-left py-4 px-6 text-sm font-medium text-gray-500">Role</th>
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
                            {(user.name || user.email)?.[0]?.toUpperCase() || '?'}
                          </span>
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">
                            {user.name || user.displayName || 'No name'}
                          </p>
                          <p className="text-sm text-gray-500">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-6">
                      <span
                        className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium ${
                          isAdmin(user)
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-gray-100 text-gray-600'
                        }`}
                      >
                        {isAdmin(user) ? (
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
                      {user.createdAt?.toLocaleDateString() || '-'}
                    </td>
                    <td className="py-4 px-6 text-right">
                      <button
                        onClick={() => toggleAdminRole(user.id, isAdmin(user))}
                        disabled={updating === user.id}
                        className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                          isAdmin(user)
                            ? 'bg-red-50 text-red-600 hover:bg-red-100'
                            : 'bg-amber-50 text-amber-600 hover:bg-amber-100'
                        } disabled:opacity-50`}
                      >
                        {updating === user.id ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : isAdmin(user) ? (
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

        {/* Load More */}
        {hasMore && !loading && (
          <div className="p-4 border-t border-gray-100">
            <button
              onClick={() => loadUsers(true)}
              className="w-full py-2 text-sm text-primary-600 hover:text-primary-700 font-medium"
            >
              Load more users
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
