import { useEffect, useState } from 'react';
import {
  collection,
  getDocs,
  addDoc,
  doc,
  updateDoc,
  deleteDoc,
  orderBy,
  query,
} from 'firebase/firestore';
import { db } from '../lib/firebase';
import {
  Plus,
  Pencil,
  Trash2,
  Search,
  X,
  Loader2,
  Activity,
  ChevronDown,
} from 'lucide-react';

// ── types ────────────────────────────────────────────────────────────────────

interface ActivityDoc {
  id: string;
  name: string;
  category: string;
  subtitle: string;
  timeSlot: string;
  timeSlotOrder: number;
  isWellnessActivity: boolean;
}

const TIME_SLOTS = [
  { label: 'Morning (6am-9am)',     order: 0 },
  { label: 'Mid-Day (9am-2pm)',     order: 1 },
  { label: 'Afternoon (2:30pm-6pm)', order: 2 },
  { label: 'Evening (7pm-10pm)',    order: 3 },
  { label: 'Weekend',               order: 4 },
];

const CATEGORIES = [
  'mindfulness',
  'health',
  'fitness',
  'nature',
  'nutrition',
  'digital_wellness',
  'posture',
  'eye_health',
  'productivity',
  'mental_fitness',
  'social',
  'relaxation',
  'sleep_hygiene',
];

const CATEGORY_BADGE: Record<string, string> = {
  mindfulness:     'bg-purple-100 text-purple-700',
  health:          'bg-blue-100 text-blue-700',
  fitness:         'bg-orange-100 text-orange-700',
  nature:          'bg-green-100 text-green-700',
  nutrition:       'bg-yellow-100 text-yellow-700',
  digital_wellness:'bg-pink-100 text-pink-700',
  posture:         'bg-cyan-100 text-cyan-700',
  eye_health:      'bg-teal-100 text-teal-700',
  productivity:    'bg-indigo-100 text-indigo-700',
  mental_fitness:  'bg-violet-100 text-violet-700',
  social:          'bg-rose-100 text-rose-700',
  relaxation:      'bg-sky-100 text-sky-700',
  sleep_hygiene:   'bg-slate-100 text-slate-700',
};

const SLOT_BADGE: Record<string, string> = {
  'Morning (6am-9am)':     'bg-amber-100 text-amber-700',
  'Mid-Day (9am-2pm)':     'bg-yellow-100 text-yellow-700',
  'Afternoon (2:30pm-6pm)':'bg-orange-100 text-orange-700',
  'Evening (7pm-10pm)':    'bg-indigo-100 text-indigo-700',
  'Weekend':               'bg-green-100 text-green-700',
};

// ── blank form ────────────────────────────────────────────────────────────────

const blankForm = (): Omit<ActivityDoc, 'id'> => ({
  name: '',
  category: 'health',
  subtitle: '',
  timeSlot: 'Morning (6am-9am)',
  timeSlotOrder: 0,
  isWellnessActivity: true,
});

// ── component ─────────────────────────────────────────────────────────────────

export default function ActivitiesPage() {
  const [activities, setActivities] = useState<ActivityDoc[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filterSlot, setFilterSlot] = useState('');
  const [filterCat, setFilterCat] = useState('');

  // modal state
  const [modalOpen, setModalOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<ActivityDoc | null>(null);
  const [form, setForm] = useState(blankForm());
  const [saving, setSaving] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<ActivityDoc | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');

  // ── load ───────────────────────────────────────────────────────────────────

  const load = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'activities'), orderBy('timeSlotOrder'));
      const snap = await getDocs(q);
      setActivities(
        snap.docs.map(d => ({ id: d.id, ...(d.data() as Omit<ActivityDoc, 'id'>) }))
      );
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, []);

  // ── filtered list ──────────────────────────────────────────────────────────

  const filtered = activities.filter(a => {
    const s = search.toLowerCase();
    const matchSearch =
      !s ||
      a.name.toLowerCase().includes(s) ||
      a.subtitle?.toLowerCase().includes(s) ||
      a.category.toLowerCase().includes(s);
    const matchSlot = !filterSlot || a.timeSlot === filterSlot;
    const matchCat  = !filterCat  || a.category === filterCat;
    return matchSearch && matchSlot && matchCat;
  });

  // ── open modal ─────────────────────────────────────────────────────────────

  const openAdd = () => {
    setEditTarget(null);
    setForm(blankForm());
    setError('');
    setModalOpen(true);
  };

  const openEdit = (a: ActivityDoc) => {
    setEditTarget(a);
    setForm({
      name: a.name,
      category: a.category,
      subtitle: a.subtitle ?? '',
      timeSlot: a.timeSlot,
      timeSlotOrder: a.timeSlotOrder,
      isWellnessActivity: a.isWellnessActivity ?? true,
    });
    setError('');
    setModalOpen(true);
  };

  // ── form helpers ───────────────────────────────────────────────────────────

  const setField = <K extends keyof typeof form>(k: K, v: typeof form[K]) => {
    setForm(f => ({ ...f, [k]: v }));
    if (k === 'timeSlot') {
      const slot = TIME_SLOTS.find(t => t.label === v);
      if (slot) setForm(f => ({ ...f, timeSlot: v as string, timeSlotOrder: slot.order }));
    }
  };

  // ── save ───────────────────────────────────────────────────────────────────

  const save = async () => {
    if (!form.name.trim()) { setError('Activity name is required.'); return; }
    if (!form.subtitle.trim()) { setError('Subtitle is required.'); return; }
    setSaving(true);
    setError('');
    try {
      const payload = {
        name: form.name.trim(),
        category: form.category,
        subtitle: form.subtitle.trim(),
        timeSlot: form.timeSlot,
        timeSlotOrder: form.timeSlotOrder,
        isWellnessActivity: form.isWellnessActivity,
      };
      if (editTarget) {
        await updateDoc(doc(db, 'activities', editTarget.id), payload);
        setActivities(prev =>
          prev.map(a => a.id === editTarget.id ? { ...a, ...payload } : a)
        );
      } else {
        const ref = await addDoc(collection(db, 'activities'), payload);
        setActivities(prev => [...prev, { id: ref.id, ...payload }]);
      }
      setModalOpen(false);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Save failed. Check your admin permissions.');
    } finally {
      setSaving(false);
    }
  };

  // ── delete ─────────────────────────────────────────────────────────────────

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true);
    try {
      await deleteDoc(doc(db, 'activities', deleteTarget.id));
      setActivities(prev => prev.filter(a => a.id !== deleteTarget.id));
      setDeleteTarget(null);
    } catch (e: unknown) {
      alert(e instanceof Error ? e.message : 'Delete failed.');
    } finally {
      setDeleting(false);
    }
  };

  // ── render ─────────────────────────────────────────────────────────────────

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Activities</h1>
          <p className="text-gray-500 mt-1">
            {activities.length} activit{activities.length !== 1 ? 'ies' : 'y'} · shown to all users daily
          </p>
        </div>
        <button
          onClick={openAdd}
          className="inline-flex items-center gap-2 px-5 py-2.5 bg-primary-600 hover:bg-primary-700 text-white text-sm font-medium rounded-xl shadow-sm transition"
        >
          <Plus className="w-4 h-4" />
          Add Activity
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search activities…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
          />
        </div>

        <div className="relative">
          <select
            value={filterSlot}
            onChange={e => setFilterSlot(e.target.value)}
            className="appearance-none pl-3 pr-8 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 outline-none bg-white"
          >
            <option value="">All Time Slots</option>
            {TIME_SLOTS.map(t => <option key={t.label}>{t.label}</option>)}
          </select>
          <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
        </div>

        <div className="relative">
          <select
            value={filterCat}
            onChange={e => setFilterCat(e.target.value)}
            className="appearance-none pl-3 pr-8 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 outline-none bg-white"
          >
            <option value="">All Categories</option>
            {CATEGORIES.map(c => (
              <option key={c} value={c}>{c.replace(/_/g, ' ')}</option>
            ))}
          </select>
          <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
        </div>

        {(search || filterSlot || filterCat) && (
          <button
            onClick={() => { setSearch(''); setFilterSlot(''); setFilterCat(''); }}
            className="inline-flex items-center gap-1 px-3 py-2 text-sm text-gray-500 hover:text-gray-900 border border-gray-200 rounded-xl"
          >
            <X className="w-3.5 h-3.5" /> Clear
          </button>
        )}
      </div>

      {/* Table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center py-20">
            <Loader2 className="w-8 h-8 animate-spin text-primary-500" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-gray-400">
            <Activity className="w-12 h-12 mb-3 opacity-30" />
            <p className="font-medium">No activities found</p>
            {(search || filterSlot || filterCat) && (
              <p className="text-sm mt-1">Try clearing the filters</p>
            )}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-100">
                  <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500 uppercase tracking-wide">Activity</th>
                  <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500 uppercase tracking-wide">Category</th>
                  <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500 uppercase tracking-wide">Time Slot</th>
                  <th className="text-right py-3 px-5 text-xs font-semibold text-gray-500 uppercase tracking-wide">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50">
                {filtered.map(a => (
                  <tr key={a.id} className="hover:bg-gray-50 transition-colors">
                    <td className="py-3.5 px-5">
                      <p className="text-sm font-medium text-gray-900">{a.name}</p>
                      {a.subtitle && (
                        <p className="text-xs text-gray-500 mt-0.5">{a.subtitle}</p>
                      )}
                    </td>
                    <td className="py-3.5 px-5">
                      <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium ${CATEGORY_BADGE[a.category] ?? 'bg-gray-100 text-gray-600'}`}>
                        {a.category.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="py-3.5 px-5">
                      <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium ${SLOT_BADGE[a.timeSlot] ?? 'bg-gray-100 text-gray-600'}`}>
                        {a.timeSlot}
                      </span>
                    </td>
                    <td className="py-3.5 px-5 text-right">
                      <div className="inline-flex items-center gap-1">
                        <button
                          onClick={() => openEdit(a)}
                          className="p-2 text-gray-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg transition"
                          title="Edit"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => setDeleteTarget(a)}
                          className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ── Add / Edit Modal ───────────────────────────────────────────────── */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg">
            {/* modal header */}
            <div className="flex items-center justify-between px-6 py-4 border-b">
              <h2 className="text-lg font-semibold text-gray-900">
                {editTarget ? 'Edit Activity' : 'Add Activity'}
              </h2>
              <button
                onClick={() => setModalOpen(false)}
                className="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* modal body */}
            <div className="px-6 py-5 space-y-4">

              {/* name */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Activity Name <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={form.name}
                  onChange={e => setField('name', e.target.value)}
                  placeholder="e.g. Body Scan Meditation"
                  className="w-full px-3.5 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
              </div>

              {/* subtitle */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Subtitle <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  value={form.subtitle}
                  onChange={e => setField('subtitle', e.target.value)}
                  placeholder="e.g. Practice mindfulness"
                  className="w-full px-3.5 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 focus:border-primary-500 outline-none"
                />
              </div>

              {/* category + time slot in a row */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                  <div className="relative">
                    <select
                      value={form.category}
                      onChange={e => setField('category', e.target.value)}
                      className="appearance-none w-full pl-3.5 pr-8 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 outline-none bg-white"
                    >
                      {CATEGORIES.map(c => (
                        <option key={c} value={c}>{c.replace(/_/g, ' ')}</option>
                      ))}
                    </select>
                    <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Time Slot</label>
                  <div className="relative">
                    <select
                      value={form.timeSlot}
                      onChange={e => {
                        const slot = TIME_SLOTS.find(t => t.label === e.target.value);
                        setForm(f => ({ ...f, timeSlot: e.target.value, timeSlotOrder: slot?.order ?? 0 }));
                      }}
                      className="appearance-none w-full pl-3.5 pr-8 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-primary-500 outline-none bg-white"
                    >
                      {TIME_SLOTS.map(t => (
                        <option key={t.label} value={t.label}>{t.label}</option>
                      ))}
                    </select>
                    <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 pointer-events-none" />
                  </div>
                </div>
              </div>

              {/* isWellnessActivity toggle */}
              <div className="flex items-center justify-between p-3.5 bg-gray-50 rounded-xl">
                <div>
                  <p className="text-sm font-medium text-gray-800">Wellness Activity</p>
                  <p className="text-xs text-gray-500 mt-0.5">Shows action button (Practice / Explore / Diet / Measure) on the card</p>
                </div>
                <button
                  onClick={() => setField('isWellnessActivity', !form.isWellnessActivity)}
                  className={`relative w-11 h-6 rounded-full transition-colors ${form.isWellnessActivity ? 'bg-primary-500' : 'bg-gray-300'}`}
                >
                  <span
                    className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${form.isWellnessActivity ? 'translate-x-5' : 'translate-x-0'}`}
                  />
                </button>
              </div>

              {/* category → special button hint */}
              <div className="text-xs text-gray-500 -mt-2 pl-1">
                {form.category === 'nutrition' && '→ Will show "Diet" button'}
                {['mindfulness'].includes(form.category) && '→ Will show "Practice" button'}
                {['nature'].includes(form.category) && '→ Will show "Explore" button'}
                {(form.name.toLowerCase().includes('lux') || form.name.toLowerCase().includes('light intensity')) && '→ Will show "Measure" button'}
                {form.name.toLowerCase() === 'mindfulness bell reminder' && '→ Will open Bell Reminder screen'}
              </div>

              {error && (
                <p className="text-sm text-red-600 bg-red-50 px-4 py-2.5 rounded-xl">{error}</p>
              )}
            </div>

            {/* modal footer */}
            <div className="flex justify-end gap-3 px-6 py-4 border-t bg-gray-50 rounded-b-2xl">
              <button
                onClick={() => setModalOpen(false)}
                className="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-xl hover:bg-gray-100 transition"
              >
                Cancel
              </button>
              <button
                onClick={save}
                disabled={saving}
                className="inline-flex items-center gap-2 px-5 py-2 text-sm font-medium text-white bg-primary-600 hover:bg-primary-700 rounded-xl transition disabled:opacity-60"
              >
                {saving && <Loader2 className="w-4 h-4 animate-spin" />}
                {editTarget ? 'Save Changes' : 'Add Activity'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Delete Confirmation ────────────────────────────────────────────── */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 space-y-4">
            <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto">
              <Trash2 className="w-6 h-6 text-red-600" />
            </div>
            <div className="text-center">
              <h2 className="text-lg font-semibold text-gray-900">Delete Activity?</h2>
              <p className="text-sm text-gray-500 mt-1">
                "<span className="font-medium text-gray-700">{deleteTarget.name}</span>" will be permanently removed and will no longer appear in the app.
              </p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => setDeleteTarget(null)}
                className="flex-1 px-4 py-2.5 text-sm text-gray-700 border border-gray-300 rounded-xl hover:bg-gray-100 transition"
              >
                Cancel
              </button>
              <button
                onClick={confirmDelete}
                disabled={deleting}
                className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-xl transition disabled:opacity-60"
              >
                {deleting && <Loader2 className="w-4 h-4 animate-spin" />}
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
