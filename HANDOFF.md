# Handoff: Municipal Elections Companion (iOS), COMP4977 Assignment 2

State as of **Nov 19, 2026**. Due **Fri Nov 20, 2026, 11:59 pm**.

The SwiftUI app is feature-complete for Assignment 2. It was verified end to end against the deployed Web API and Firestore on iPhone (iPhone 18 Pro) and iPad (iPad Air 11" M4) simulators, in portrait and landscape. The backend (ASP.NET Core on Azure) is finished and unchanged.

## 1. Architecture

```
SwiftUI Views ──▶ ViewModels (@MainActor @Observable) ──▶ Services (protocols)
                                                           ├─ API services ──▶ ASP.NET Core Web API (Azure App Service)
                                                           ├─ Auth services ─▶ Web API (JWT) + Firebase Auth + Keychain
                                                           └─ Firebase services ─▶ Cloud Firestore
```

- **Web API** (`https://mems-api-afisher-ane9a7cmfpb9b9at.canadacentral-01.azurewebsites.net`) is the system of record for accounts and election data.
- **Firebase Auth** exists only so Firestore security rules know who the user is. It uses the same email and password as the API.
- **Firestore** stores candidate selections and the user's chosen municipality.

### Folder layout (`Municipal Elections Companion/`)

| Folder | Contents |
| --- | --- |
| `Models/` | `Municipality`, `Position`, `Candidate`, `Election` (API, `Codable`); `CandidateSelection`, `UserProfile` (Firestore); auth request/response types; `StoredSession` |
| `Services/API/` | `APIClient` (URLSession, `URLComponents`, error mapping, 401 hook, date decoding), `APIError`, `ElectionService` |
| `Services/Auth/` | `AuthService` (coordinates API + Firebase + Keychain), `AuthAPIService`, `KeychainService`, `JWTDecoder` |
| `Services/Firebase/` | `FirebaseAuthService`, `SelectionService` (CRUD), `UserProfileService`, `FirebaseErrorMapper` (user-friendly messages) |
| `Services/AppServices.swift` | Builds the service graph once; ViewModels receive it (injectable for tests) |
| `ViewModels/` | `SessionViewModel` (auth + city, app-wide), `SelectionsViewModel` (Firestore selections, app-wide), `AppRouter` (navigation state), screen ViewModels |
| `Views/` | `Auth/`, `Main/` (root, adaptive shell, home, city picker), `Candidates/`, `Selections/`, `Profile/`, `Components/` |
| `Utilities/Validation.swift` | Form validation plus `SelectionValidator` (duplicates, notes ≤ 500, seat limits, city match) |

Views never call `URLSession` or Firestore directly.

## 2. Authentication flow

- **Register:** `POST /api/auth/register`, then `Auth.auth().createUser`. An existing Firebase user isn't treated as an error. The app then signs out of Firebase, and the user logs in.
- **Login:** `POST /api/auth/login`, then Firebase `signIn`. If the Firebase user doesn't exist (an account from Assignment 1), it's created automatically.
- **Storage:** the JWT, email and name are saved in the **Keychain** as a `StoredSession`, never in UserDefaults. Emails are lowercased everywhere.
- **Expiry:** the session is cleared and the user returns to login with "Your session has expired" when any of these happen:
  - the JWT's `exp` claim has passed at launch;
  - the Firebase user is missing at launch;
  - an authorized API call returns a 401;
  - Firestore reports `unauthenticated`.
- **Logout:** signs out of Firebase and clears the Keychain.

## 3. Municipality (city)

- **First login:** the user picks a city. It's saved to Firestore at `UserProfiles/{email}` as `{ email, city, municipalityId, lastSync }`.
- **API filtering:** every election-data request sends `?city=<name>`: `/api/elections`, `/api/offices`, `/api/candidates` and `/api/candidates/search`. Details use `/api/candidates/{id}?city=`, which returns 404 for another city's candidate. The client also filters results by city as a backstop.
- **Changing city (Profile):** the new city is saved to Firestore first. Then the election, offices and candidates reload, navigation resets, and the previous city's selections are cleared.
- **Display:** "City: X" appears as the navigation subtitle on every screen, as well as in the iPad sidebar and on the Home screen.
- **City used during development and testing:** **Burnaby**. Surrey was used to test switching.

## 4. Firestore

### `CandidateSelections`

The document ID is `"{userEmail}_{candidateId}"`, which makes duplicates impossible.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | Same as the document ID |
| `userEmail` | String | Lowercased |
| `candidateId` | Int | |
| `candidateName` | String | |
| `positionId` | Int | Added, so seat limits can be counted |
| `positionName` | String | |
| `municipalityId` | Int | Added (the spec asks for a municipality identifier) |
| `municipalityName` | String | The city name exactly as the API returns it |
| `photoUrl` | String? | Added, so the list needs no API call |
| `notes` | String | ≤ 500 characters |
| `dateCreated` | Timestamp | |
| `dateModified` | Timestamp | |

**Queries** use `userEmail == me AND municipalityName == city`. These are equality filters only, so no composite index is needed.

**Validation before a write** (`SelectionValidator`):
- no duplicates;
- notes ≤ 500 characters;
- required fields present;
- the candidate belongs to the current city;
- the seat limit isn't exceeded (`seatsAvailable` per office per city).

Seat limits are checked against a **fresh server read** just before the write. The error message reads, for example, "You can only choose 1 Mayor in Burnaby."

The spec says Pitt Meadows has 5 councillors, but the API returns 6 for every city. The app follows the API's `seatsAvailable`.

### Security rules (deployed)

Users can read, update and delete only documents where `userEmail == request.auth.token.email`. Creates must have the user's own email and notes ≤ 500 characters. `UserProfiles/{email}` is readable and writable only by that email. The full rules are in the original handoff (§5).

## 5. Adaptive UI

| Screen | iPhone portrait | iPhone landscape | iPad portrait / landscape |
| --- | --- | --- | --- |
| Navigation | Tab bar, one `NavigationStack` per tab | Same | `NavigationSplitView` with sidebar (size-class based) |
| Candidate directory | Single-column list grouped by office | Two-column wide rows with biography and email | Adaptive card grid: 2 columns portrait, 3 landscape |
| Candidate detail | Stacked | Photo and info side by side | Side by side |
| My Candidate Selections | Inset list, swipe/context menu to edit or delete, pull to refresh | Same | Same |

- **Sizing:** sizes use `@ScaledMetric` and adaptive grids rather than hard-coded layouts.
- **Rotation:** navigation and session state live in `AppRouter`, `SessionViewModel` and `SelectionsViewModel` at the app root, so they survive rotation. Editor drafts are `@State` on the sheet, so they survive too.

## 6. Running and testing

- **Firebase setup:** open the `.xcodeproj`. Firebase comes via SPM, with only **FirebaseAuth**, **FirebaseCore** and **FirebaseFirestore** linked. `GoogleService-Info.plist` is in the app folder (Firebase project `appleios-5e236`).
- **Test account:** one exists for verification (Burnaby, no selections). Ask Alexander for the credentials. They're deliberately not stored in the repo.
- **Smoke test, on each device and orientation:**
  1. Register and log in, then choose Burnaby.
  2. In Candidates, open a Mayor and use Add Selection with a note.
  3. Add a second Mayor; you should see the seat-limit alert.
  4. In My Selections, edit the note, rotating mid-edit to confirm the text survives.
  5. In Profile, change to Surrey: candidates should be Surrey-only and the list empty. Switch back to Burnaby and the selection returns.
  6. Delete the selection, confirming in the alert.
- **Tooling:** `.mcp.json` registers the Firebase MCP server for Claude Code, using the local `firebase login`. Use it for read-only inspection unless changes are explicitly approved.

## 7. Known limitations / remaining work

- **Rules isolation:** a second account hasn't yet been tested against the rules (that user A can't read B's selections). Use the console's Rules Playground or the Firebase MCP.
- **Expired-token path:** the code handles it, but it hasn't been triggered live, because the JWT lasts 7 days.
- **Offline writes:** an `await` on a Firestore write waits for server acknowledgement, so with no connection the Save spinner keeps spinning until the connection returns.
- **Saved-selection count:** Profile's "Total saved selections" counts the **current city** only, by design, since other cities' selections are hidden.
- **Cosmetic:**
  - a gap between the map-pin icon and the city name in selection rows;
  - the iPad search placeholder is truncated;
  - the text column on iPad portrait candidate detail is narrow.
- **Tests:** there's no unit test target yet. `SelectionValidator` and `JWTDecoder` are pure functions and are the easiest candidates.
- **Documentation PDF (to do):** see §8.

## 8. Maintenance report (Assignment 1 → 2)

1. **App icon:** added (it was missing in Assignment 1).
2. **Modularity:** networking moved out of views into protocol-based services. MVVM ViewModels were added, and the folders are split into Auth / API / Firebase / ViewModels / Views.
3. **Secure token storage:** the JWT moved from `@AppStorage` (UserDefaults) to the Keychain.
4. **Seat limits:** selections are now enforced per office per city. Assignment 1 allowed, for example, two mayors.
5. **City filtering:** removed the "All municipalities" filter and the screen listing every city. All requests are now city-scoped.
6. **URL building:** search URLs are built with `URLComponents` instead of string concatenation.
7. **Error handling:** server `{message}` text is shown, friendly offline, timeout and Firestore messages were added, and 401s are handled centrally.
8. **Selections storage:** the Assignment 1 voting guide (`/api/savedcandidates`) was replaced by Firestore CRUD with notes.
9. **Small fixes:** website and email are now tappable links, and a layout bug in `MunicipalityView` (a `Spacer` sitting directly in a `NavigationStack`) is gone.
