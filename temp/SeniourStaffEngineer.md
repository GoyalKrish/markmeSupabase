As a Senior Staff Engineer, my primary concern reviewing this architecture before a production launch is the heavy reliance on client-side validation and the lack of robust database
  constraints. This system will fundamentally break down under high traffic, leading to data corruption, duplicate entries, and UI freezing.

  Due to response limits, I have prioritized the Top 10 absolute most critical issues per category (50 total) that will cause catastrophic failures, data loss, or security breaches in
  production.

  ---

  1. Top Bugs (Functional Failures & Data Loss)

  1.1. Unfiltered Global Realtime Subscription (Data Leak & UI Crash)
   * Severity: Critical
   * Files: lib/providers/lobby_provider.dart (initializeRealtime)
   * Repro: Have 10 active lobbies. Gatekeeper in Lobby A scans a card.
   * Root Cause: The onPostgresChanges subscription lacks a filter (filter: 'lobby_id=eq.$lobbyId').
   * Fix: Update channel subscription to filter: 'lobby_id=eq.$lobbyId'.
   * Effort: Low (1 line of code).

  1.2. Complete Data Loss on Temporary Network Disconnect
   * Severity: Critical
   * Files: lib/services/lobby_service.dart (addAttendanceRecord)
   * Repro: Gatekeeper enters a concrete stairwell (loses 4G), scans NFC.
   * Root Cause: No local queue or .catchError offline handling. The insert throws a SocketException, the UI shows an error, and the scanned data is permanently lost.
   * Fix: Implement a local SQLite/Hive queue. Write scans locally first, then sync to Supabase in a background worker.
   * Effort: High (Requires offline-first architecture rewrite).

  1.3. Realtime Channel Drops Are Never Recovered
   * Severity: High
   * Files: lib/providers/lobby_provider.dart
   * Repro: User backgrounds app for 5 minutes (socket drops). User foregrounds app. Other gatekeepers scan 50 cards.
   * Root Cause: Supabase SDK reconnects the socket, but the LobbyProvider never re-runs fetchAttendanceRecords() upon reconnection. The client permanently misses those 50 records.
   * Fix: Listen to Supabase realtime connection state changes channel.on(RealtimeListenTypes.system, ...) and trigger a manual REST fetch on reconnect.
   * Effort: Medium.

  1.4. Manual Entry Double-Submission
   * Severity: Medium
   * Files: lib/screens/active_lobby_screen.dart (_showManualEntryDialog)
   * Repro: User taps "Add" rapidly 3 times on a slow network.
   * Root Cause: The ElevatedButton.onPressed does not disable the button or show a loading state while awaiting lobbyService.addAttendanceRecord.
   * Fix: Add bool _isLoading to the dialog state. Disable button while processing.
   * Effort: Low.

  1.5. NFC Scanning State Deadlock
   * Severity: Medium
   * Files: lib/services/nfc_service.dart
   * Repro: User triggers NFC scan, OS NFC dialog appears, user force-closes the OS dialog.
   * Root Cause: If NfcManager.instance.startSession fails or is interrupted by the OS, _isScanning remains true, permanently disabling future scans until app restart.
   * Fix: Wrap session start in a try/catch/finally and ensure _isScanning = false on OS cancellation.
   * Effort: Low.

  ---

  2. Top Race Conditions (Concurrency & State)

  2.1. TOCTTOU Duplicate Entry Injection
   * Severity: Critical
   * Files: lib/services/lobby_service.dart
   * Repro: Gatekeepers A and B scan the same student's NFC card simultaneously.
   * Root Cause: Time-of-Check-to-Time-Of-Use. The client checks maybeSingle() == null and then inserts. Both clients see null and both insert.
   * Fix: Add UNIQUE(lobby_id, student_system_id) to the database. Handle the resulting 23505 unique violation code in the Flutter catch block.
   * Effort: Low.

  2.2. UI State Duplication (REST + Realtime Collision)
   * Severity: High
   * Files: lib/screens/active_lobby_screen.dart, LobbyProvider
   * Repro: Gatekeeper scans a card.
   * Root Cause: The UI explicitly calls fetchAttendanceRecords after a successful scan. Simultaneously, the realtime socket receives the INSERT payload and appends it via
     _handleNewAttendance. The user sees the record appear twice temporarily.
   * Fix: Stop calling fetchAttendanceRecords after explicit inserts. Let the realtime channel update the UI, or locally mutate the state and ignore self-generated socket payloads via
     device_id.
   * Effort: Low.

  2.3. Ghost Lobby Creation
   * Severity: Medium
   * Files: Backend/RLS_Policies/Full_Functions_of_Policies.json (create_lobby_and_join)
   * Repro: Host creates a lobby, but network drops immediately after the request reaches the server.
   * Root Cause: The server executes the RPC successfully. The client throws a timeout and thinks it failed. The user taps "Create" again, generating two lobbies.
   * Fix: Pass an idempotency key (UUID generated on client) to the RPC and enforce uniqueness on it.
   * Effort: Medium.

  2.4. Host Deletion vs Gatekeeper Insertion
   * Severity: Medium
   * Files: LobbyService
   * Repro: Host deletes lobby. Exactly 10ms prior, Gatekeeper initiates an attendance scan.
   * Root Cause: The gatekeeper's HTTP request arrives right as the cascade delete is occurring.
   * Fix: RLS attendance_insert_member_or_host will fail cleanly if lobby_members is gone, but UI must gracefully handle "Lobby Closed" errors rather than generic exceptions.
   * Effort: Low.

  2.5. Realtime Payload Sorting Jitter
   * Severity: Low
   * Files: ActiveLobbyScreen (_buildStudentList)
   * Repro: High volume of scans occurring globally.
   * Root Cause: Records are appended to _attendanceRecords in LobbyProvider. The UI sorts them on every build students.sort(...). If timestamps are identical (or lack millisecond precision),
     the UI list will furiously snap items back and forth.
   * Fix: Sort by timestamp THEN by id to ensure deterministic sorting.
   * Effort: Low.

  ---

  3. Top Security Vulnerabilities (Auth & RLS)

  3.1. Complete Bypass of Duplicate Attendance Rules
   * Severity: Critical
   * Files: attendance_records (DB Schema)
   * Repro: Malicious authenticated user in a lobby uses Postman or cURL to bypass the Flutter app and spam POST /rest/v1/attendance_records.
   * Root Cause: Zero database-level constraints enforcing the "one entry per student per lobby" business rule. RLS only checks membership, not duplicates.
   * Fix: Add ALTER TABLE public.attendance_records ADD CONSTRAINT unique_attendance UNIQUE (lobby_id, student_system_id);
   * Effort: Low.

  3.2. Entry Code Brute Forcing
   * Severity: High
   * Files: lib/services/lobby_service.dart (joinLobby)
   * Repro: Attacker writes a script iterating 000000 to 999999 calling joinLobby.
   * Root Cause: entry_code is 6 digits (low entropy), globally unique across all active rooms, and the Supabase REST endpoint has no rate limiting configured by default for standard
     authenticated users.
   * Fix: Implement a Supabase Edge Function with rate limiting (e.g., max 5 attempts per minute per user_id) to handle joining lobbies, removing direct table access for joining.
   * Effort: Medium.

  3.3. Banned Device Evasion
   * Severity: High
   * Files: devices RLS Policies
   * Repro: Device is banned by admin (banned = true). User goes to app data, clears it, or deletes their device via API (Users can delete their own devices RLS policy).
   * Root Cause: The RLS policy allows {public} users to DELETE their own rows in the devices table.
   * Fix: Remove the DELETE and UPDATE RLS policies for regular users on the devices table. Devices should be append-only for users, manageable only by admins.
   * Effort: Low.

  3.4. Host Information Disclosure
   * Severity: Medium
   * Files: ActiveLobbyScreen info dialog
   * Repro: Gatekeeper clicks the info icon.
   * Root Cause: Exposing host_id (a Supabase Auth UUID) to standard users provides no UI value and unnecessarily exposes internal auth identifiers.
   * Fix: Remove host_id from the UI. Fetch host_name via a view if display is needed.
   * Effort: Low.

  3.5. Arbitrary Device UUID Injection
   * Severity: Low
   * Files: LobbyService.addAttendanceRecord
   * Repro: Modded client sends a random UUID for device_id that doesn't exist in the devices table.
   * Root Cause: The foreign key exists, but a malicious user could potentially insert a fake device record first (since they can insert devices).
   * Fix: Accept device registration via a secure Edge Function, or enforce device metadata validation.
   * Effort: Medium.

  ---

  4. Top Scalability Issues (Bottlenecks & Overheads)

  4.1. N+1 Join Bottleneck on Home Screen
   * Severity: Critical
   * Files: Backend/Schema/public (get_active_lobbies_with_counts RPC)
   * Repro: 1,000 gatekeepers open the app while assigned to 10 lobbies, each with 50,000 attendance records.
   * Root Cause: The RPC executes COUNT(DISTINCT ar.id) joining against massive tables on every home screen load.
   * Fix: Denormalize counts. Add member_count and attendance_count columns to the lobbies table. Update them via Postgres Database Triggers on INSERT/DELETE.
   * Effort: Medium (Database triggers).

  4.2. Unindexed Foreign Keys
   * Severity: High
   * Files: attendance_records
   * Repro: Room hits 10,000 records. Scans become noticeably slower.
   * Root Cause: PostgreSQL does not automatically index foreign keys. Queries like .eq('lobby_id', lobbyId) require sequential table scans once the table grows large.
   * Fix: Add CREATE INDEX idx_attendance_lobby ON attendance_records(lobby_id);
   * Effort: Low.

  4.3. Realtime Socket Saturation
   * Severity: High
   * Files: LobbyProvider
   * Repro: 100 Gatekeepers across 10 active lobbies scanning 1 card per second.
   * Root Cause: As stated in Bug 1.1, the lack of filter causes Supabase to broadcast 100 messages/sec to every client. 10,000 messages/sec total outbound. This will hit Supabase compute
     tier limits rapidly and drain mobile batteries.
   * Fix: Apply PostgreSQL filters to the channel subscription.
   * Effort: Low.

  4.4. Full Table Payload on Sync
   * Severity: Medium
   * Files: LobbyProvider.fetchAttendanceRecords
   * Repro: ActiveLobbyScreen is opened for a lobby with 5,000 records.
   * Root Cause: The query select().eq('lobby_id', ...) has no pagination (.limit() or .range()). It downloads the entire dataset into memory at once.
   * Fix: Implement cursor-based pagination or infinite scrolling for the UI list.
   * Effort: Medium.

  4.5. Bloated CSV Memory Footprint
   * Severity: Medium
   * Files: ActiveLobbyScreen._shareLobbyData
   * Repro: Host attempts to export a 20,000-record lobby on an older Android device.
   * Root Cause: Dart creates a massive in-memory String array rows.join('\n').
   * Fix: Stream the data directly to the File using IOSink instead of building the entire string in memory.
   * Effort: Low.

  ---

  5. Top Data Consistency Risks (Integrity & Schema)

  5.1. Historical Data Annihilation (Cascade Deletes)
   * Severity: Critical
   * Files: Backend/Schema/foreignKey.json
   * Repro: Event finishes. Host clicks "Delete Lobby" to clean up their dashboard.
   * Root Cause: Lobbies are physically deleted (DELETE FROM public.lobbies). Due to ON DELETE CASCADE (implied by the RPC notes), ALL attendance records and metrics for that event are
     permanently destroyed.
   * Fix: Do not physically delete lobbies. Implement a Soft Delete (active = false, deleted_at = NOW()).
   * Effort: Low.

  5.2. Missing Composite Unique Constraints
   * Severity: Critical
   * Files: lobby_members, attendance_records
   * Repro: Server latency causes multiple client retries.
   * Root Cause: Lack of constraints UNIQUE(lobby_id, user_id) allows the same Gatekeeper to join the room 5 times. Lack of UNIQUE(lobby_id, student_system_id) allows 5 identical attendance
     entries.
   * Fix: Add UNIQUE constraints to both tables immediately.
   * Effort: Low.

  5.3. Ambiguous Sync State (synced_at)
   * Severity: Medium
   * Files: attendance_records
   * Repro: Future offline-mode developers attempt to build a sync queue.
   * Root Cause: synced_at is in the DB but never populated by the Flutter client. recorded_at uses DB now(). If a device scans offline at 1:00 PM and syncs at 5:00 PM, recorded_at will show
     5:00 PM (data falsification).
   * Fix: Client must pass recorded_at explicitly using the device's local timestamp. The database created_at (or synced_at) should default to now().
   * Effort: Low.

  5.4. Unenforced Device Linkage
   * Severity: Medium
   * Files: attendance_records
   * Repro: User logs in on Phone A, joins lobby, copies token to Phone B, scans cards.
   * Root Cause: attendance_insert_member_or_host checks if auth.uid() is in lobby_members, but does not verify that the device_id making the insert matches the device_id that joined the
     lobby.
   * Fix: Update RLS to verify device_id matches the active session's device.
   * Effort: Medium.

  5.5. Missing RLS Update Policies on Lobbies
   * Severity: Medium
   * Files: RLS_Policies.json
   * Repro: Host tries to close a room.
   * Root Cause: There is no UPDATE policy defined for lobbies in RLS_Policies.json. By default, Postgres RLS drops UPDATE if not specified. The host cannot actually change the active status
     to false.
   * Fix: Add lobbies_update_host policy allowing UPDATE where host_id = auth.uid().
   * Effort: Low.