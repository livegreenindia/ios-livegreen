import { useEffect, useState } from 'react';
import { collection, query, getDocs, doc, updateDoc, deleteDoc, where, orderBy } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { CheckCircle, XCircle, Clock, Loader2, Users, MapPin } from 'lucide-react';

interface Club {
  id: string;
  name: string;
  description: string;
  category: string;
  status: 'pending' | 'approved' | 'rejected';
  createdBy: string;
  createdByName?: string;
  memberCount?: number;
  createdAt?: Date;
}

export default function ClubsPage() {
  const [clubs, setClubs] = useState<Club[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('pending');
  const [updating, setUpdating] = useState<string | null>(null);

  useEffect(() => {
    loadClubs();
  }, [filter]);

  const loadClubs = async () => {
    try {
      setLoading(true);
      let q;
      
      if (filter === 'all') {
        q = query(collection(db, 'clubs'), orderBy('createdAt', 'desc'));
      } else {
        q = query(
          collection(db, 'clubs'),
          where('status', '==', filter),
          orderBy('createdAt', 'desc')
        );
      }

      const snapshot = await getDocs(q);
      const clubsData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate(),
      })) as Club[];

      setClubs(clubsData);
    } catch (error) {
      console.error('Error loading clubs:', error);
    } finally {
      setLoading(false);
    }
  };

  const approveClub = async (clubId: string) => {
    try {
      setUpdating(clubId);
      await updateDoc(doc(db, 'clubs', clubId), {
        status: 'approved',
        approvedAt: new Date(),
      });
      setClubs(prev =>
        prev.map(club =>
          club.id === clubId ? { ...club, status: 'approved' } : club
        )
      );
    } catch (error) {
      console.error('Error approving club:', error);
      alert('Failed to approve club');
    } finally {
      setUpdating(null);
    }
  };

  const rejectClub = async (clubId: string) => {
    const reason = prompt('Reason for rejection (optional):');
    try {
      setUpdating(clubId);
      await updateDoc(doc(db, 'clubs', clubId), {
        status: 'rejected',
        rejectedAt: new Date(),
        rejectionReason: reason || '',
      });
      setClubs(prev =>
        prev.map(club =>
          club.id === clubId ? { ...club, status: 'rejected' } : club
        )
      );
    } catch (error) {
      console.error('Error rejecting club:', error);
      alert('Failed to reject club');
    } finally {
      setUpdating(null);
    }
  };

  const deleteClub = async (clubId: string) => {
    if (!confirm('Are you sure you want to delete this club? This action cannot be undone.')) {
      return;
    }
    try {
      setUpdating(clubId);
      await deleteDoc(doc(db, 'clubs', clubId));
      setClubs(prev => prev.filter(club => club.id !== clubId));
    } catch (error) {
      console.error('Error deleting club:', error);
      alert('Failed to delete club');
    } finally {
      setUpdating(null);
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'approved':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-700">
            <CheckCircle className="w-3 h-3" />
            Approved
          </span>
        );
      case 'rejected':
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-red-100 text-red-700">
            <XCircle className="w-3 h-3" />
            Rejected
          </span>
        );
      default:
        return (
          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
            <Clock className="w-3 h-3" />
            Pending
          </span>
        );
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Clubs</h1>
          <p className="text-gray-500 mt-1">Review and manage community clubs</p>
        </div>
        <div className="flex gap-2">
          {(['pending', 'approved', 'rejected', 'all'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition-colors ${
                filter === f
                  ? 'bg-primary-500 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Clubs Grid */}
      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
        </div>
      ) : clubs.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
          <p className="text-gray-500">No {filter !== 'all' ? filter : ''} clubs found</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {clubs.map((club) => (
            <div
              key={club.id}
              className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100"
            >
              <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-semibold text-gray-900">{club.name}</h3>
                    {getStatusBadge(club.status)}
                  </div>
                  <p className="text-gray-600 mb-3">{club.description}</p>
                  <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                    <span className="flex items-center gap-1">
                      <MapPin className="w-4 h-4" />
                      {club.category}
                    </span>
                    <span className="flex items-center gap-1">
                      <Users className="w-4 h-4" />
                      {club.memberCount || 0} members
                    </span>
                    <span>Created: {club.createdAt?.toLocaleDateString() || '-'}</span>
                    {club.createdByName && <span>By: {club.createdByName}</span>}
                  </div>
                </div>

                <div className="flex gap-2">
                  {club.status === 'pending' && (
                    <>
                      <button
                        onClick={() => approveClub(club.id)}
                        disabled={updating === club.id}
                        className="inline-flex items-center gap-2 px-4 py-2 bg-green-50 text-green-600 hover:bg-green-100 rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
                      >
                        {updating === club.id ? (
                          <Loader2 className="w-4 h-4 animate-spin" />
                        ) : (
                          <CheckCircle className="w-4 h-4" />
                        )}
                        Approve
                      </button>
                      <button
                        onClick={() => rejectClub(club.id)}
                        disabled={updating === club.id}
                        className="inline-flex items-center gap-2 px-4 py-2 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
                      >
                        <XCircle className="w-4 h-4" />
                        Reject
                      </button>
                    </>
                  )}
                  <button
                    onClick={() => deleteClub(club.id)}
                    disabled={updating === club.id}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-gray-100 text-gray-600 hover:bg-gray-200 rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
