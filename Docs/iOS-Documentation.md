# Municipal Elections Companion: iOS Documentation

COMP4977 Assignment 2 (SwiftUI client)

## 1. Deployment information

| Item | Value |
| --- | --- |
| Azure API URL | https://mems-api-afisher-ane9a7cmfpb9b9at.canadacentral-01.azurewebsites.net |
| GitHub repository (iOS) | https://github.com/AlexanderFisher-tech/MunicipalElectionsCompanion-Code |
| Firebase project ID | `appleios-5e236` |
| iOS bundle ID | `ca.example.Municipal-Elections-Companion` |
| Municipality used for development and testing | **Burnaby** (Surrey was used to test switching cities) |

## 2. Architecture diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                     SwiftUI Application (iOS / iPadOS)               │
│                                                                      │
│   Views ──▶ ViewModels (@MainActor, @Observable) ──▶ Services        │
│                                                                      │
│   ┌──────────────────┐  ┌───────────────────┐  ┌──────────────────┐  │
│   │  API services     │  │  Auth services     │  │ Firebase services│  │
│   │  APIClient        │  │  AuthService       │  │ SelectionService │  │
│   │  ElectionService  │  │  AuthAPIService    │  │ UserProfileSvc   │  │
│   │  (URLSession)     │  │  KeychainService   │  │ FirebaseAuthSvc  │  │
│   └────────┬─────────┘  └───┬───────────┬───┘  └────────┬─────────┘  │
└────────────┼────────────────┼───────────┼───────────────┼────────────┘
             │ HTTPS + JWT    │ login /   │ email/password│ Firestore SDK
             │ ?city=Burnaby  │ register  │ sign-in       │
             ▼                ▼           ▼               ▼
   ┌────────────────────────────────┐   ┌────────────────────────────────┐
   │     Azure App Service           │   │           Firebase              │
   │  ┌──────────────────────────┐  │   │  ┌──────────────────────────┐  │
   │  │  ASP.NET Core Web API     │  │   │  │  Firebase Authentication │  │
   │  │  - /api/auth (JWT)        │  │   │  └────────────┬─────────────┘  │
   │  │  - /api/elections         │  │   │               │ identity for    │
   │  │  - /api/offices           │  │   │               ▼ security rules  │
   │  │  - /api/candidates        │  │   │  ┌──────────────────────────┐  │
   │  └──────────────────────────┘  │   │  │  Cloud Firestore          │  │
   │   accounts + election data      │   │  │  - CandidateSelections    │  │
   └────────────────────────────────┘   │  │  - UserProfiles           │  │
                                         │  └──────────────────────────┘  │
                                         └────────────────────────────────┘
```

**What each part does**

- **ASP.NET Core Web API (on Azure App Service):** the system of record for user accounts and election data. It issues the JWT used for authorized requests.
- **Firebase Authentication:** signs the user in with the same email and password as the Web API. It exists only so the Firestore security rules can identify the user.
- **Cloud Firestore:** stores each user's candidate selections and chosen municipality.
- **Keychain:** stores the JWT and session details on the device.

**Project folders (MVVM)**

| Folder | Contents |
| --- | --- |
| `Models/` | `Codable` API models (`Municipality`, `Position`, `Candidate`, `Election`), Firestore models (`CandidateSelection`, `UserProfile`), auth request and response types |
| `Services/API/` | `APIClient` (URLSession, async/await, error mapping, central 401 handling), `ElectionService` |
| `Services/Auth/` | `AuthService` (coordinates Web API, Firebase Auth and Keychain), `AuthAPIService`, `KeychainService`, `JWTDecoder` |
| `Services/Firebase/` | `FirebaseAuthService`, `SelectionService` (CRUD), `UserProfileService`, `FirebaseErrorMapper` |
| `ViewModels/` | `SessionViewModel`, `SelectionsViewModel`, `AppRouter`, screen view models |
| `Views/` | `Auth/`, `Main/`, `Candidates/`, `Selections/`, `Profile/`, `Components/` |
| `Utilities/` | Form validation and `SelectionValidator` |

Views never call URLSession or Firestore directly. They go through ViewModels, which use the service protocols.

## 3. Maintenance report (Assignment 1 → Assignment 2)

| # | Issue in Assignment 1 | Fix in Assignment 2 |
| --- | --- | --- |
| 1 | No app icon | Added an app icon. |
| 2 | Networking code lived inside views | Moved into protocol-based services. Added MVVM ViewModels and split folders into Auth, API, Firebase, ViewModels and Views. |
| 3 | JWT stored in `@AppStorage` (UserDefaults), which isn't secure | JWT and session now stored in the Keychain. |
| 4 | Users could select more candidates than allowed (for example, two mayors) | Seat limits are enforced per office per city, using the API's `seatsAvailable`. |
| 5 | An "All municipalities" filter showed data from every city | Removed. Every election-data request is scoped to the user's city. |
| 6 | Search URLs were built by string concatenation | URLs are built with `URLComponents`, so query values are encoded correctly. |
| 7 | Errors were generic or unhandled | Server messages are shown. Added friendly messages for offline, timeout and Firestore errors. 401 responses are handled centrally. |
| 8 | Selections stored through the voting guide API (`/api/savedcandidates`) | Replaced with Firestore CRUD, including notes. |
| 9 | Website and email weren't tappable, and a layout bug in `MunicipalityView` | Website and email are links. Fixed the layout bug (a `Spacer` placed directly in a `NavigationStack`). |
| 10 | Firestore was in test mode (open to anyone, expiring) | Deployed owner-only security rules (see section 6). |

## 4. Authentication (JWT)

- **Register:** `POST /api/auth/register`, then a matching Firebase Auth account is created.
- **Login:** `POST /api/auth/login`, then Firebase sign-in. If an Assignment 1 account has no Firebase user yet, one is created automatically.
- **Secure storage:** the JWT, email and name are saved in the Keychain. Emails are lowercased everywhere.
- **Authorized requests:** `APIClient` adds `Authorization: Bearer <JWT>` to authorized requests.
- **User identity:** the logged-in user's email (from the login response and JWT) identifies the user in Firestore.
- **Token expiry:** the session is cleared and the user returns to the login screen with "Your session has expired" when:
  - the JWT's `exp` claim has passed when the app launches;
  - an authorized API call returns 401;
  - Firestore reports the user is unauthenticated.
- **Logout:** signs out of Firebase and clears the Keychain.

## 5. Municipality configuration

**How the municipality is stored:** on first login the user picks a city. It's saved in Firestore at `UserProfiles/{email}` and loaded from there on each login, so it follows the user across devices.

**API filtering:** every election-data request includes the city:

```
GET /api/elections?city=Burnaby
GET /api/offices?city=Burnaby
GET /api/candidates?city=Burnaby
GET /api/candidates/search?city=Burnaby&...
GET /api/candidates/{id}?city=Burnaby   (returns 404 for another city's candidate)
```

The client also filters results by city as a second safeguard.

**Displaying the city:** "City: Burnaby" appears as the navigation subtitle on every screen, in the iPad sidebar, on the Home screen and on the Profile screen.

**Changing the city (Profile screen):**
1. The new city is saved to Firestore.
2. The election, offices and candidates reload automatically.
3. Navigation resets.
4. Selections from the previous city are no longer shown. Firestore queries filter on both the user's email and the city.

## 6. Firebase

### Firestore collections

**`CandidateSelections`:** one document per saved candidate. The document ID is `{userEmail}_{candidateId}`, so the same user can't save the same candidate twice.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | Same as the document ID |
| `userEmail` | String | Lowercased. Identifies the owner. |
| `candidateId` | Int | |
| `candidateName` | String | |
| `positionId` | Int | Added, to count seat limits |
| `positionName` | String | |
| `municipalityId` | Int | Added, the municipality identifier |
| `municipalityName` | String | City name as returned by the API |
| `photoUrl` | String (optional) | Added, so the list shows photos without an API call |
| `notes` | String | Maximum 500 characters |
| `dateCreated` | Timestamp | |
| `dateModified` | Timestamp | |

The app queries with `userEmail == <me> AND municipalityName == <city>`, so it only shows the current user's selections for the current city.

**`UserProfiles`:** one document per user. The document ID is the lowercased email.

| Field | Type | Notes |
| --- | --- | --- |
| `email` | String | |
| `city` | String | Chosen municipality |
| `municipalityId` | Int | |
| `lastSync` | Timestamp | Shown on the Profile screen |

### Security rules

Deployed from `firestore.rules` in the repository. Each signed-in user can only read and write their own profile and their own selections. Signed-out users can't access anything.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function myEmail() {
      return request.auth != null && request.auth.token.email != null
        ? request.auth.token.email.lower() : null;
    }

    match /UserProfiles/{email} {
      allow read, write: if myEmail() != null && myEmail() == email;
    }

    match /CandidateSelections/{id} {
      allow read, delete: if myEmail() != null && resource.data.userEmail == myEmail();
      allow create: if myEmail() != null && request.resource.data.userEmail == myEmail();
      allow update: if myEmail() != null
                    && resource.data.userEmail == myEmail()
                    && request.resource.data.userEmail == myEmail();
    }
  }
}
```

**Verification (Nov 19, 2026):** signed in as a test account and sent requests directly to Firestore:

| Test | Result |
| --- | --- |
| Read a profile while signed out | Denied |
| Read own profile | Allowed |
| Read another user's profile | Denied |
| Query own selections | Allowed |
| Query all selections | Denied |
| Query another user's selections | Denied |
| Create a selection under another user's email | Denied |
| Create own selection | Allowed |
| Change own selection's owner to another user | Denied |
| Delete own selection | Allowed |

### Firebase screenshots

- [ ] Firebase project overview (`appleios-5e236`)
- [ ] Firestore data showing the `CandidateSelections` and `UserProfiles` collections
- [ ] Firestore Rules tab showing the rules above

## 7. Candidate selections (CRUD)

| Operation | Where | How |
| --- | --- | --- |
| **Create** | Candidate Details → **Add Selection** | Saves the candidate, user email, office, city and optional notes. |
| **Read** | **My Candidate Selections** screen | Shows photo, name, position, municipality, notes and date saved. Supports pull to refresh. |
| **Update** | Candidate Details → **Edit Selection**, or swipe / context menu in My Candidate Selections | Edits the notes. Updates `dateModified`. |
| **Delete** | Candidate Details → **Delete Selection**, or swipe / context menu in My Candidate Selections | Asks for confirmation, then removes the row immediately. |

**Validation**

- **Duplicates:** blocked. The document ID is unique per user and candidate.
- **Notes:** limited to 500 characters.
- **Required fields:** checked before saving.
- **Seat limits:** checked against a fresh server read just before saving. For example, "You can only choose 1 Mayor in Burnaby."
- **City:** a candidate from another city can't be saved.

The spec's example says Pitt Meadows has 5 councillors. The Web API returns 6 councillor seats, so the app follows the API's `seatsAvailable` value.

**Error handling:** user-friendly messages are shown for:
- Firestore connection errors;
- authentication errors and token expiry (returns to login);
- network failures and timeouts;
- invalid Firebase responses.

**Profile screen:** shows the user's email, the city (with a Change button), total saved selections for the current city and the last sync time.

## 8. Adaptive user interface

| Screen | iPhone portrait | iPhone landscape | iPad portrait | iPad landscape |
| --- | --- | --- | --- | --- |
| Navigation | Tab bar, `NavigationStack` per tab | Same | `NavigationSplitView` with sidebar | Same |
| Candidate directory | Single-column list grouped by office | Wider rows with extra details (biography, email) | Card grid (2 columns) | Card grid (3 columns) |
| Candidate details | Photo above info | Photo and info side by side | Side by side | Side by side |
| My Candidate Selections | Scrolling list | Same, no clipping | Same | Same |

**Techniques used:**
- size classes (`horizontalSizeClass`, `verticalSizeClass`) to choose layouts and navigation;
- `NavigationSplitView` on iPad, `NavigationStack` on iPhone;
- adaptive `LazyVGrid` columns (`GridItem(.adaptive(minimum:))`);
- `@ScaledMetric` sizes that respect Dynamic Type.

**Orientation changes:** navigation, login and loaded Firestore data are kept in app-level objects (`AppRouter`, `SessionViewModel`, `SelectionsViewModel`), so rotating doesn't lose them. Text being edited in the selection editor also survives rotation.

## 9. Implemented features

- Registration and login through the ASP.NET Core Web API, with the JWT stored in the Keychain
- Automatic logout with a message when the session expires
- First-login municipality selection, saved to Firestore
- Change municipality from the Profile screen, which reloads all city data automatically
- Every election API request scoped to the user's city
- "City: <name>" shown throughout the app
- Home screen with the election and offices for the city
- Candidate directory with search and pull to refresh
- Candidate details with Add, Edit and Delete Selection buttons
- My Candidate Selections screen with full Firestore CRUD, pull to refresh, swipe actions and delete confirmation
- Validation: duplicates, 500-character notes, required fields, per-office seat limits
- Profile screen: email, city, total selections, last sync time, logout
- Owner-only Firestore security rules
- Adaptive layouts for iPhone and iPad in portrait and landscape
- User-friendly error messages for network, auth and Firestore failures

## 10. Screen captures

Take these on the iPhone 16 and iPad Air simulators, while logged in with Burnaby selected:

- [ ] Login
- [ ] Registration
- [ ] Candidate Directory (only Burnaby candidates)
- [ ] Candidate Details
- [ ] Create Selection
- [ ] Edit Selection
- [ ] Selection List (My Candidate Selections)
- [ ] Firebase Firestore data
- [ ] iPhone Portrait
- [ ] iPhone Landscape
- [ ] iPad Portrait
- [ ] iPad Landscape
- [ ] City-specific data: the Candidate Directory for Burnaby, then for Surrey after switching, showing that only that city's data appears

## 11. Known limitations

- **Offline saving:** with no connection, Save waits until the connection returns before finishing.
- **Selection count:** the Profile screen's total counts only the current city's selections, since other cities' selections are hidden.
- **Tests:** there are no automated unit tests yet.
