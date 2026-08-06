# Extra.md: Independent Extended Audit (Lobby & Attendance Systems)

**Scope:** Rooms, Membership, Attendance, NFC, Realtime, Offline, Sync.
**Exclusion:** Folder feature (Out of scope).

---

## 1. Verification of Existing Findings

I have cross-referenced the findings in `ArchitecturalAudit.md`, `CodebaseAnalysis.md`, and `SeniourStaffEngineer.md` against the actual implementation in `lib/` and `Backend/`.

| Finding | Status | Auditor's Note |
| :--- | :---: | :--- |
| **TOCTTOU Vulnerability** | ✅ **Verified** | The `maybeSingle()` check in `LobbyService.addAttendanceRecord` is indeed non-atomic and prone to race conditions. |
| **Realtime Filter Missing** | ✅ **Verified** | `LobbyProvider.initializeRealtime` lacks a `filter` for `lobby_id`, causing global payload processing. |
| **Realtime Memory Leak** | ✅ **Verified** | `ActiveLobbyScreen.dispose()` fails to call `LobbyProvider.clearLobby()`. |
| **Brute-force Entry Codes** | ✅ **Verified** | 6-digit `entry_code` is numerically small and lacks rate-limiting. |
| **Missing Uniqueness** | ✅ **Verified** | No `UNIQUE` constraint on `attendance_records(lobby_id, student_system_id)` was found in schema logic. |
| **Offline Mode Absence** | ✅ **Verified** | The system is architected as a purely synchronous network-first application. |

---

## 2. New Critical Findings (Not covered in previous reports)

### 🚨 [CRITICAL] Cross-Lobby State Pollution (State Leakage)
* **Description:** Data from a previous room "leaks" into the next room joined by the same user.
* **Root Cause:** `LobbyProvider` is a singleton `ChangeNotifier`. When a user navigates from `ActiveLobbyScreen` (Room A) to `ActiveLobbyScreen` (Room B), the `_members` and `_attendanceRecords` lists are **not** cleared because `dispose()` in the UI does not trigger `clearLobby()` in the provider.
* **Impact:** A gatekeeper in Room B will see the names and attendance of students from Room A. This is a massive privacy and data integrity failure.
* **Suggested Fix:** Implement `lobbyProvider.clearLobby()` within the `dispose()` method of `ActiveLobbyScreen`.

### 🚨 [HIGH] Membership Initialization Gap (The "Empty Room" Bug)
* **Description:** Users joining a room will see an empty member list until a new person joins.
* **Root Cause:** `LobbyProvider` contains a `_handleNewMember` method (Realtime) but **no method** to perform an initial `fetchMembers` call. 
* **Impact:** Even if 10 people are in a room, a new gatekeeper joining will see "0 Members" until the next `insert` event occurs.
* **Suggested Fix:** Add `fetchMembers(String lobbyId)` to `LobbyProvider` and call it during `initializeRealtime`.

### ⚠️ [MEDIUM] The "Double-Update" Race Condition (UI Flicker)
* **Description:** The UI may show a duplicate record or "stutter" immediately after a scan.
* **Root Cause:** In `ActiveLobbyScreen._handleNFCData`, the code performs an `await addAttendanceRecord(...)` and then *immediately* calls `fetchAttendanceRecords(...)`. Simultaneously, the Supabase Realtime channel triggers `_handleNewAttendance`. 
* **Impact:** The UI receives two updates almost at once: one from the manual fetch and one from the Realtime event. This causes the list to "jump" or momentarily show a duplicate.
* **Suggested Fix:** Rely **solely** on the Realtime stream for updates after the initial fetch. Remove manual `fetchAttendanceRecords` calls after successful insertions.

### ⚠️ [MEDIUM] Missing Gate-Assignment Logic
* **Description:** The business requirement "Each gatekeeper is assigned to a physical entry gate" is unimplemented.
* **Root Cause:** The `lobby_members` table and the `LobbyService` have no concept of a `gate_id` or `assignment`.
* **Impact:** There is no way to track which gate an attendance record was recorded at, making "Gate-wise activity" reports impossible.
* **Suggested Fix:** Add a `gate_id` column to `lobby_members` and update `joinLobby` to accept a gate assignment.

---

## 3. Disagreements & Corrections

* **Correction on "Dead State" (SeniourStaffEngineer.md):** The previous report claims `_members` is "Dead State." I disagree. It is not "dead" (it receives data), but it is **"Incomplete"** because there is no initial fetch mechanism.
* **Clarification on "Sorting Instability":** The previous report claims sorting is unstable. I clarify that this is specifically because `_handleNewAttendance` appends to the end of the list (`[..._attendanceRecords, record]`), and the UI sorts on every build. This is actually a symptom of the "Double-Update" race condition mentioned above.

---

## 4. Unresolved Questions (Insufficient Evidence)

1. **Database Trigger Audit:** Does the `lobbies` table use Postgres Triggers to maintain `memberCount` and `attendanceCount`? If these are updated via the client-side `LobbyService`, the counts will drift significantly if any write fails or if multiple gatekeepers join at once.
2. **NFC Authentication Robustness:** Does the `NfcService` handle "sector authentication failures" gracefully at the OS level, or could a malicious/corrupt tag cause the app to hang or crash?
3. **Realtime Payload Size:** What is the maximum payload size allowed by the Supabase Realtime channel? If an attendance record grows (e.g., adding more metadata), could it exceed the MTU and cause dropped events?

---

## 5. Final Assessment Summary

The current system is a **functional prototype** for an online-only environment, but it is **architecturally unfit** for professional use in its current state. The combination of **State Pollution (Leakage)** and **Membership Initialization Gaps** makes the core user experience unreliable for gatekeepers.

**Priority 1:** Fix State Leakage (LobbyProvider cleanup).
**Priority 2:** Fix Membership Initialization (Initial fetch).
**Priority 3:** Fix Duplicate Prevention (DB Unique Constraints).
**Priority 4:** Implement Offline-First Architecture (Repository Pattern).
