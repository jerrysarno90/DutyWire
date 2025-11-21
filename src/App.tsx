import { useEffect, useMemo, useState } from 'react';
import { generateClient } from 'aws-amplify/data';

const client = generateClient();

type IsoDateTime = string;

type CalendarEventModel = {
  id: string;
  orgId: string;
  ownerId: string;
  title: string;
  category: string;
  color: string;
  notes?: string | null;
  startsAt: IsoDateTime;
  endsAt: IsoDateTime;
  reminderMinutesBefore?: number | null;
  createdAt?: IsoDateTime | null;
  updatedAt?: IsoDateTime | null;
};

type RosterEntryModel = {
  id: string;
  orgId: string;
  badgeNumber: string;
  shift?: string | null;
  notes?: string | null;
  startsAt: IsoDateTime;
  endsAt: IsoDateTime;
  createdAt?: IsoDateTime | null;
  updatedAt?: IsoDateTime | null;
};

type ModelListOptions = {
  filter?: Record<string, unknown>;
};

type ModelListResult<T> = Promise<{
  data?: T[] | null;
}>;

type ModelListApi<T> = {
  list(options: ModelListOptions): ModelListResult<T>;
};

const models = client.models as unknown as {
  CalendarEvent: ModelListApi<CalendarEventModel>;
  RosterEntry: ModelListApi<RosterEntryModel>;
};

const sortByStart = (a: CalendarEventModel, b: CalendarEventModel) =>
  new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime();

const sortRoster = (a: RosterEntryModel, b: RosterEntryModel) =>
  new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime();

export default function App() {
  const [orgIdInput, setOrgIdInput] = useState('');
  const [ownerIdInput, setOwnerIdInput] = useState('');
  const [orgId, setOrgId] = useState<string | null>(null);
  const [ownerId, setOwnerId] = useState<string | null>(null);

  const [events, setEvents] = useState<CalendarEventModel[]>([]);
  const [roster, setRoster] = useState<RosterEntryModel[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!orgId) {
      setEvents([]);
      setRoster([]);
      return;
    }

    setLoading(true);
    setError(null);

    const calendarFilter = ownerId
      ? {
          and: [
            { orgId: { eq: orgId } },
            { ownerId: { eq: ownerId } },
          ],
        }
      : { orgId: { eq: orgId } };

    const rosterFilter = {
      orgId: { eq: orgId },
    };

    Promise.all([
      models.CalendarEvent.list({ filter: calendarFilter }),
      models.RosterEntry.list({ filter: rosterFilter }),
    ])
      .then(([calendarResult, rosterResult]) => {
        setEvents((calendarResult.data ?? []).sort(sortByStart));
        setRoster((rosterResult.data ?? []).sort(sortRoster));
      })
      .catch((cause) => {
        const message =
          cause instanceof Error ? cause.message : 'Unable to load calendar data.';
        console.error('Failed to load calendar models', cause);
        setError(message);
      })
      .finally(() => setLoading(false));
  }, [orgId, ownerId]);

  const upcomingEvents = useMemo(
    () => events.filter((event) => new Date(event.endsAt) >= new Date()),
    [events],
  );

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trimmedOrg = orgIdInput.trim();
    const trimmedOwner = ownerIdInput.trim();

    setOrgId(trimmedOrg.length > 0 ? trimmedOrg : null);
    setOwnerId(trimmedOwner.length > 0 ? trimmedOwner : null);
  };

  return (
    <div className="app-shell">
      <header>
        <h1>ShiftLink Calendar Debugger</h1>
        <p>Preview roster and personal events pulled from the Amplify Data API.</p>
      </header>

      <section className="panel">
        <form className="filters" onSubmit={handleSubmit}>
          <label>
            <span>Organization ID</span>
            <input
              value={orgIdInput}
              onChange={(event) => setOrgIdInput(event.target.value)}
              placeholder="custom:orgID"
              required
            />
          </label>
          <label>
            <span>Calendar Owner (optional)</span>
            <input
              value={ownerIdInput}
              onChange={(event) => setOwnerIdInput(event.target.value)}
              placeholder="Cognito user id or email"
            />
          </label>
          <button type="submit">Load</button>
        </form>
      </section>

      {loading && (
        <section className="panel">
          <p>Loading schedules…</p>
        </section>
      )}

      {error && (
        <section className="panel error">
          <strong>Something went wrong</strong>
          <p>{error}</p>
        </section>
      )}

      {orgId && !loading && !error && (
        <div className="grid">
          <section className="panel">
            <h2>Roster Entries</h2>
            {roster.length === 0 ? (
              <p className="muted">No active assignments for this org.</p>
            ) : (
              <ul className="list">
                {roster.map((entry) => (
                  <li key={entry.id}>
                    <span className="primary">{entry.shift ?? 'Assigned Shift'}</span>
                    <span className="secondary">
                      {new Date(entry.startsAt).toLocaleString()} →{' '}
                      {new Date(entry.endsAt).toLocaleString()}
                    </span>
                    <span className="secondary">Badge / Computer #: {entry.badgeNumber}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          <section className="panel">
            <h2>Calendar Events</h2>
            {upcomingEvents.length === 0 ? (
              <p className="muted">
                {ownerId
                  ? 'No upcoming events for this owner.'
                  : 'No upcoming events for this organization.'}
              </p>
            ) : (
              <ul className="list">
                {upcomingEvents.map((event) => (
                  <li key={event.id}>
                    <span className="badge">{event.category}</span>
                    <span className="primary">{event.title}</span>
                    <span className="secondary">
                      {new Date(event.startsAt).toLocaleString()} →{' '}
                      {new Date(event.endsAt).toLocaleString()}
                    </span>
                    {event.notes && <span className="notes">{event.notes}</span>}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
