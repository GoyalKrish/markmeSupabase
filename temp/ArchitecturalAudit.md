This is a Deep Architectural Audit of the Lobby, Room, Attendance, NFC, and Realtime systems for the markmeSupabase project, based on concrete evidence extracted directly from the database
  schema, RPC functions, RLS policies, and Dart codebase.

  ---

  1. End-to-End Request Flow

  Host Flow
   * Create room: UI (CreateLobbyScreen) calls LobbyService.createLobby(name). This executes the Supabase RPC create_lobby_and_join. The RPC atomically generates a random 6-digit entry_code,
     inserts the lobbies record, and inserts the host into lobby_members. The LobbyProvider is then notified and calls initializeRealtime(lobbyId).
   * Join created room: Host joins automatically via the create_lobby_and_join RPC.
   * Leave room: Host or Gatekeeper UI calls LobbyService.leaveLobby, which triggers a DELETE on lobby_members where user_id = auth.currentUser!.id.
   * Close room: Only host can delete via LobbyService.deleteLobby, executing DELETE FROM public.lobbies WHERE id = lobbyId AND host_id = auth.uid() (backed by the delete_lobby_for_host
     RPC/RLS).
   * Rejoin room after app restart: Handled by HomeScreen querying get_active_lobbies_with_counts RPC which checks l.id IN (SELECT lobby_id FROM public.lobby_members WHERE user_id =
     auth.uid()) and re-initializes providers.

  Gatekeeper Flow
   * Join room via entry code: HomeScreen UI calls LobbyService.joinLobby(entryCode). The service queries lobbies for entry_code. If valid, it executes INSERT INTO lobby_members with
     lobby_id, user_id, and device_id.
   * Leave room: Same as host leaveLobby.
   * Rejoin room: Similar to host, UI fetches active memberships via get_active_lobbies_with_counts on boot.
   * Multiple gatekeepers joining simultaneously: The entry code is queried, and individual inserts are made to lobby_members. The database handles this concurrently without issue.

  Attendance Flow
   * NFC scan: ActiveLobbyScreen toggles _nfcService.startScanning(). NfcService._handleTag reads Mifare Classic cards (specifically Block 1 for System ID and Block 4 for Name) using sector
     authentication 0xFFFFFFFFFFFF, 0xA0A1A2A3A4A5, or 0x000000000000. The map is passed to _handleNFCData, triggering LobbyService.addAttendanceRecord.
   * Manual entry: _showManualEntryDialog takes Name and ID and directly invokes LobbyService.addAttendanceRecord.
   * Duplicate scan: LobbyService.addAttendanceRecord executes a SELECT query via maybeSingle(). If found, it throws an exception client-side.
   * Invalid/Unknown card: Handled by NfcService._handleTag catching sector authentication failures or non-Mifare tags, returning an error string in the map.
   * Network failure during scan: addAttendanceRecord fails immediately with a PostgrestException or SocketException. Data is lost.
   * Multiple devices scanning simultaneously: Critical Flaw (See Section 3).

  ---

  2. Database Deep Dive

  Tables & Schema
  lobbies
   * Schema: id (UUID, PK), name (text), entry_code (varchar), host_id (UUID, FK auth.users), created_at, updated_at, active, closed_at.
   * Constraints: UNIQUE (entry_code) exists on the table.
   * RLS: lobbies_insert_authenticated_host (host_id = auth.uid()), lobbies_select_authenticated (open to all auth users).

  lobby_members
   * Schema: id (UUID, PK), lobby_id (UUID, FK lobbies), user_id (UUID, FK auth.users), joined_at, device_id (UUID, FK devices).
   * Constraints: MISSING Unique constraint on (lobby_id, user_id) or (lobby_id, device_id).
   * RLS: lobby_members_insert_self (user_id = auth.uid()), Select/Update restricted to self or lobby host.

  attendance_records
   * Schema: id (UUID, PK), lobby_id (UUID, FK lobbies), recorded_by (UUID, FK auth.users), student_system_id (text), student_name (text), recorded_at, synced_at, lobby_name, device_id (UUID,
     FK devices).
   * Constraints: MISSING Unique constraint on (lobby_id, student_system_id).
   * RLS: Insert requires being recorded_by AND existing in lobby_members or being the host_id.

  devices
   * Schema: id (UUID, PK), user_id (UUID, FK auth.users), device_identifier (text), is_active, last_used_at, banned.
   * Constraints: FK on user_id.

  Database Architecture Assessment
   * Missing Indexes: attendance_records.lobby_id and attendance_records.student_system_id lack explicit indexes (though lobby_id gets an implicit one usually, composite queries like the
     duplicate check will be slow at scale).
   * Missing Uniqueness Guarantees: A user can theoretically join a lobby multiple times because lobby_members(lobby_id, user_id) is not constrained. More critically, the same student can be
     inserted multiple times into attendance_records.
   * Potential Data Corruption: Without compound unique constraints on business logic relationships, race conditions will result in corrupt data states.

  ---

  3. Duplicate Prevention Audit

   * Is duplicate prevention enforced by database constraints? NO. The schema for attendance_records has no UNIQUE(lobby_id, student_system_id) constraint.
   * Can two devices insert the same student at the same time? YES.
   * Can race conditions create duplicate attendance records? YES.
   * Is there any atomic transaction protecting attendance insertion? NO.
   * What happens if two scans occur within the same second?

  Evidence from LobbyService.dart:

    1 Future<void> addAttendanceRecord(String lobbyId, Student student) async {
    2   // Step 1: Client queries the database
    3   final existing = await _supabase.from('attendance_records').select().eq('lobby_id', lobbyId).eq('student_system_id', student.id).maybeSingle();
    4
    5   // Step 2: Client evaluates condition
    6   if (existing != null) { throw Exception('...'); }
    7
    8   // Step 3: Client inserts data
    9   await _supabase.from('attendance_records').insert({...});
   10 }
  Conclusion: This is a classic "Time of Check to Time of Use" (TOCTTOU) vulnerability. If two gatekeepers scan the same user simultaneously, both will execute Step 1, both will receive null,
  and both will execute Step 3, resulting in exact duplicate rows in the database.

  ---

  4. Realtime System Audit

  Evidence from LobbyProvider.dart:

   1 _lobbyChannel = _supabase.channel('lobby-$lobbyId')
   2   ..onPostgresChanges(
   3     event: PostgresChangeEvent.insert, schema: 'public', table: 'attendance_records',
   4     callback: (payload) => _handleNewAttendance(payload.newRecord),
   5   )
   6   ..subscribe();
   * Channel subscriptions & Filters: Subscribes to public.attendance_records inserts. CRITICAL FLAW: There is no filter: 'lobby_id=eq.$lobbyId' applied to the channel. This means the client
     is receiving real-time payloads for every attendance record inserted globally across all active lobbies.
   * Subscription lifecycle: Initialized manually, cancelled on clearLobby().
   * Reconnection behavior: The Supabase SDK handles WebSocket reconnections automatically. However, State recovery is missing. If the connection drops for 5 minutes, events inserted by other
     Gatekeepers during that period are lost. The client never automatically re-fetches fetchAttendanceRecords upon reconnection.
   * Duplicate event risks: In ActiveLobbyScreen._handleNFCData, the client explicitly calls context.read<LobbyProvider>().fetchAttendanceRecords(widget.lobbyId) after insertion.
     Simultaneously, the realtime channel receives the event and triggers _handleNewAttendance, pushing payload.newRecord into the array. This causes a UI race condition where a record might
     flash twice before state settles.

  ---

  5. State Management Audit

  LobbyProvider
   * Responsibilities: Holds _currentLobby, _members, _attendanceRecords, _activeLobbies.
   * Lifecycle & Cleanup: clearLobby() unsubscribes from the channel and nils out variables.
   * State Inconsistency Risks:
       1. Duplicate state: (Mentioned above) Fetching entire lists manually while simultaneously appending individual real-time payloads.
       2. Dead state: The UI relies heavily on fetchActiveLobbies which runs the RPC get_active_lobbies_with_counts. These counts do not update via realtime channels. A gatekeeper looking at
          the HomeScreen will see stale counts indefinitely until a manual pull-to-refresh.
       3. UI sorting instability: In ActiveLobbyScreen, sortedRecords sorts attendanceRecords dynamically on build. Since realtime pushes unordered payloads to the end of the List, the UI
          will "snap" records around violently under heavy load.

  ---

  6. Security Audit

  Room Security
   * Entry code generation: Executed safely inside the create_lobby_and_join RPC: FLOOR(RANDOM() * 900000 + 100000).
   * Can anyone guess room codes? Yes. It's only 6 digits (1 million possibilities). Because entry_code is globally unique across active rooms, and there's no rate limiting on the joinLobby
     endpoint, a malicious actor can script a brute-force loop against entry_codes until they hit an active lobby.

  Attendance Security
   * Bypassing duplicate checks: Since the duplicate check is in the Flutter client, a user executing raw HTTP requests (or using a modded app) can bypass the maybeSingle() check and insert
     infinitely duplicate attendance rows.
   * Impersonation & Inserting to other rooms: Prevented by RLS. The attendance_insert_member_or_host policy requires the user to actually exist in lobby_members for the specific lobby_id.

  Supabase Security (RLS)
   * Coverage: Excellent. RLS policies are tightly defined on auth.uid().
   * Risks: devices table allows DELETE and UPDATE by {public} if auth.uid() = user_id. This is mostly fine, but "Banning" a device (banned: true) is easily bypassable by a user just deleting
     their own device record and registering a new one, as they have full ownership of their devices.

  ---

  7. Scalability Analysis

   * Query Bottlenecks: The get_active_lobbies_with_counts RPC joins lobbies, lobby_members, and attendance_records and does COUNT(DISTINCT ...). With 50 active lobbies containing 10,000
     attendance records each, this RPC will bottleneck the database.
   * Realtime Bottlenecks: Because lobby_provider.dart omits the filter: 'lobby_id=eq.$lobbyId' parameter in onPostgresChanges, a single active lobby app instance processes JSON serialization
     and state updates for all attendance happening worldwide.
       * 10 gatekeepers (1 room): Fine.
       * 100 gatekeepers (10 rooms): High battery drain. Devices are deserializing 10x more JSON than they need to.
       * 500 gatekeepers (50 rooms): Flutter main thread will stutter; severe N+1 realtime payload overhead.

  ---

  8. Failure Scenario Review

   * Supabase is temporarily unavailable: App completely halts. Direct .insert() calls throw exceptions. maybeSingle() duplicate checks fail.
   * Network latency is 5–10 seconds: The UI blocks while waiting for the maybeSingle() query and the insert() query to sequentially execute. The queue of students at the gate will stall.
   * App crashes during attendance insert: If it crashes between the maybeSingle() check and the insert(), no data is written. The student must scan again.
   * Device battery dies: Immediate connection termination. No partial states saved locally.
   * Room host leaves / account deleted: The DELETE cascading foreign keys will wipe out lobby_members and attendance_records instantly. All devices in the room will abruptly see empty
     screens or database errors.

  ---

  9. Future Offline Migration Assessment

  Complexity: Extremely High (9/10).
  Refactoring Effort: Massive. The app assumes 100% connectivity.
   * Files that need modification: LobbyProvider, LobbyService, ActiveLobbyScreen, HomeScreen.
   * New layers required: A local database wrapper (e.g., drift, sqflite) must be built. The entire duplicate-check logic must be moved from querying Supabase to querying a local replica of
     the attendance_records table.
   * Sync queue: Requires a background isolate or persistent queue table to store (lobbyId, studentId, timestamp) combinations that failed to upload, managed alongside conflict resolution
     logic for backend uniqueness constraints (which currently do not exist).

  ---

  10. Architecture Quality Report

  ┌───────────────────────┬────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
  │ Area                  │ Rating │ Evidence / Justification                                                                                              │
  ├───────────────────────┼────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
  │ Domain Architecture   │ 7/10   │ Clear Service/Provider separation. Business logic is mostly modularized correctly in Dart.                            │
  │ Database Architecture │ 4/10   │ Good use of RPCs for atomic lobby creation, but fatal lack of compound UNIQUE constraints allowing data corruption.   │
  │ Realtime Architecture │ 3/10   │ Missing Postgres filters means clients listen to global traffic. Missing reconnect-reconciliation means dropped data. │
  │ Security              │ 6/10   │ RLS is strong. However, client-side duplicate validation is insecure, and entry codes are easily brute-forced.        │
  │ Scalability           │ 3/10   │ Unfiltered realtime channels and heavy aggregate RPC queries will choke under moderate load.                          │
  │ Maintainability       │ 8/10   │ The code is exceptionally clean, readable, well-structured, and typed.                                                │
  │ Testability           │ 5/10   │ Hard to mock Supabase.instance.client calls directly inside Service classes without dependency injection.             │
  │ Offline-Readiness     │ 0/10   │ 100% coupling to active network futures. No caching, no queues.                                                       │
  └───────────────────────┴────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘