import { useEffect, useState } from 'react';
import { collection, query, getDocs, doc, setDoc, deleteDoc, orderBy } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { CheckCircle, XCircle, Clock, Loader2, MapPin, Phone, Globe, User } from 'lucide-react';

interface Place {
  id: string;
  title: string;
  description: string;
  category: string;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  address?: string;
  phoneNumber?: string;
  website?: string;
  submitterName?: string;
  createdAt?: Date;
  startPoint?: {
    latitude: number;
    longitude: number;
  };
}

export default function PlacesPage() {
  const [places, setPlaces] = useState<Place[]>([]);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState<string | null>(null);

  useEffect(() => {
    loadPendingPlaces();
  }, []);

  const loadPendingPlaces = async () => {
    try {
      setLoading(true);
      const q = query(
        collection(db, 'pendingPlaces'),
        orderBy('createdAt', 'desc')
      );

      const snapshot = await getDocs(q);
      const placesData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate?.() || new Date(doc.data().createdAt),
      })) as Place[];

      setPlaces(placesData);
    } catch (error) {
      console.error('Error loading places:', error);
    } finally {
      setLoading(false);
    }
  };

  const approvePlace = async (place: Place) => {
    try {
      setUpdating(place.id);
      
      // Move to treks collection with approved status
      const trekData = {
        ...place,
        isPublic: true,
        approvalStatus: 'approved',
        approvedAt: new Date(),
        approvedBy: 'admin',
      };
      delete (trekData as any).id;
      
      await setDoc(doc(db, 'treks', place.id), trekData);
      await deleteDoc(doc(db, 'pendingPlaces', place.id));
      
      setPlaces(prev => prev.filter(p => p.id !== place.id));
    } catch (error) {
      console.error('Error approving place:', error);
      alert('Failed to approve place');
    } finally {
      setUpdating(null);
    }
  };

  const rejectPlace = async (placeId: string) => {
    // Reason for rejection (optional) - could be used for notification
    // const reason = prompt('Reason for rejection (optional):');
    try {
      setUpdating(placeId);
      await deleteDoc(doc(db, 'pendingPlaces', placeId));
      setPlaces(prev => prev.filter(p => p.id !== placeId));
    } catch (error) {
      console.error('Error rejecting place:', error);
      alert('Failed to reject place');
    } finally {
      setUpdating(null);
    }
  };

  const getCategoryColor = (category: string) => {
    const colors: Record<string, string> = {
      nature: 'bg-green-100 text-green-700',
      historical: 'bg-amber-100 text-amber-700',
      cultural: 'bg-purple-100 text-purple-700',
      scenic: 'bg-blue-100 text-blue-700',
      adventure: 'bg-red-100 text-red-700',
    };
    return colors[category?.toLowerCase()] || 'bg-gray-100 text-gray-700';
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Pending Places</h1>
        <p className="text-gray-500 mt-1">Review user-submitted places for Explorer</p>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
        </div>
      ) : places.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center border border-gray-100">
          <MapPin className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-500">No pending places to review</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {places.map((place) => (
            <div
              key={place.id}
              className="bg-white rounded-2xl p-6 shadow-sm border border-gray-100"
            >
              <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-lg font-semibold text-gray-900">{place.title}</h3>
                    <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${getCategoryColor(place.category)}`}>
                      {place.category}
                    </span>
                  </div>
                  
                  <p className="text-gray-600 mb-4">{place.description}</p>
                  
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
                    {place.submitterName && (
                      <div className="flex items-center gap-2 text-gray-500">
                        <User className="w-4 h-4" />
                        <span>Submitted by: {place.submitterName}</span>
                      </div>
                    )}
                    {place.address && (
                      <div className="flex items-center gap-2 text-gray-500">
                        <MapPin className="w-4 h-4" />
                        <span>{place.address}</span>
                      </div>
                    )}
                    {place.phoneNumber && (
                      <div className="flex items-center gap-2 text-gray-500">
                        <Phone className="w-4 h-4" />
                        <span>{place.phoneNumber}</span>
                      </div>
                    )}
                    {place.website && (
                      <div className="flex items-center gap-2 text-gray-500">
                        <Globe className="w-4 h-4" />
                        <a href={place.website} target="_blank" rel="noopener noreferrer" className="text-primary-600 hover:underline">
                          {place.website}
                        </a>
                      </div>
                    )}
                    {place.startPoint && (
                      <div className="flex items-center gap-2 text-gray-500">
                        <MapPin className="w-4 h-4" />
                        <a 
                          href={`https://maps.google.com/?q=${place.startPoint.latitude},${place.startPoint.longitude}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-primary-600 hover:underline"
                        >
                          View on Map
                        </a>
                      </div>
                    )}
                    <div className="flex items-center gap-2 text-gray-500">
                      <Clock className="w-4 h-4" />
                      <span>{place.createdAt?.toLocaleDateString() || '-'}</span>
                    </div>
                  </div>
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={() => approvePlace(place)}
                    disabled={updating === place.id}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-green-50 text-green-600 hover:bg-green-100 rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
                  >
                    {updating === place.id ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <CheckCircle className="w-4 h-4" />
                    )}
                    Approve
                  </button>
                  <button
                    onClick={() => rejectPlace(place.id)}
                    disabled={updating === place.id}
                    className="inline-flex items-center gap-2 px-4 py-2 bg-red-50 text-red-600 hover:bg-red-100 rounded-xl font-medium text-sm transition-colors disabled:opacity-50"
                  >
                    <XCircle className="w-4 h-4" />
                    Reject
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
