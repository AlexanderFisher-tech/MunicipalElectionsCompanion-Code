# Municipal Elections Companion: iOS Documentation

COMP4977 Assignment 2 (SwiftUI client)

## 1. Deployment information

| Item | Value |
| --- | --- |
| Azure API URL | https://mems-api-afisher-ane9a7cmfpb9b9at.canadacentral-01.azurewebsites.net |
| GitHub repository (iOS) | https://github.com/AlexanderFisher-tech/MunicipalElectionsCompanion-Code |
| Firebase project ID | `appleios-5e236` |
| Firebase config file | `GoogleService-Info.plist` is not in the GitHub repo. It's included in the source code copy submitted to the instructor; place it in the `Municipal Elections Companion` app folder to build. |
| iOS bundle ID | `ca.example.Municipal-Elections-Companion` |
| Municipality used for development and testing | **Burnaby** (Surrey was used to test switching cities) |
| Simulators used for screenshots | iPhone 17e and iPad Air 11-inch (M4), iOS 27.2 |

## 2. Architecture diagram

![Architecture: SwiftUI app, ASP.NET Core Web API on Azure App Service, Firebase Auth and Cloud Firestore](architecture.svg)

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
| 11 | Users could choose 6 councillors (the API's value), but the spec allows 5 | The app limits every city to 5 councillors (`SeatLimitOverrides` in `ElectionService`). |

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

### Stored data

These documents belong to the test account after the screenshots in section 10 were taken. They were read directly from Firestore.

```
UserProfiles/mec.verify.20261119@example.com
{
  "email": "mec.verify.20261119@example.com",
  "city": "Burnaby",
  "municipalityId": 3,
  "lastSync": "2026-11-20T06:37:36Z"
}

CandidateSelections/mec.verify.20261119@example.com_14
{
  "id": "mec.verify.20261119@example.com_14",
  "userEmail": "mec.verify.20261119@example.com",
  "candidateId": 14,
  "candidateName": "Adrian Solano",
  "positionId": 7,
  "positionName": "Mayor",
  "municipalityId": 3,
  "municipalityName": "Burnaby",
  "photoUrl": ".../images/demo-candidates/demo-adrian-solano.jpg",
  "notes": "Strong platform on transit and housing. Attended debate.",
  "dateCreated": "2026-11-20T06:32:17Z",
  "dateModified": "2026-11-20T06:32:53Z"
}

CandidateSelections/mec.verify.20261119@example.com_15
{
  "id": "mec.verify.20261119@example.com_15",
  "userEmail": "mec.verify.20261119@example.com",
  "candidateId": 15,
  "candidateName": "Mei Tanaka",
  "positionId": 8,
  "positionName": "Councillor",
  "municipalityId": 3,
  "municipalityName": "Burnaby",
  "photoUrl": ".../images/demo-candidates/demo-mei-tanaka.jpg",
  "notes": "Focused on parks and community safety.",
  "dateCreated": "2026-11-20T06:33:27Z",
  "dateModified": "2026-11-20T06:33:27Z"
}
```

### Firebase console screenshots

![Firebase project overview (appleios-5e236)](screenshots/firebase-project.png)

![Firebase Authentication users (email/password sign-in)](screenshots/firebase-auth.png)

![Firestore data: a CandidateSelections document](screenshots/firestore-selections.png)

![Firestore data: a UserProfiles document](screenshots/firestore-userprofiles.png)

![Firestore security rules](screenshots/firestore-rules.png)

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

**Councillor limit:** following the spec's Pitt Meadows example, a resident can choose at most 1 mayor, 5 councillors and 2 school trustees. The Web API reports 6 councillor seats, so `ElectionService` applies a limit of 5 councillors in every city (`SeatLimitOverrides`). This limit is used everywhere seats are shown or checked.

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
| Candidate directory | Single-column list grouped by office | Wider rows with extra details (biography, email) | Card grid | Card grid; the number of columns adapts to the available width |
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

Taken on the iPhone 17e and iPad Air 11-inch (M4) simulators with the test account, city Burnaby.

### Login and registration

![Login](screenshots/iphone-login.png)
![Registration](screenshots/iphone-register.png)
![Home (City: Burnaby)](screenshots/iphone-home.png)

### Candidate directory and details

![Candidate Directory (iPhone portrait)](screenshots/iphone-directory-portrait.png)
![Candidate Details](screenshots/iphone-detail-portrait.png)
![Candidate Details when saved (Edit / Delete Selection)](screenshots/iphone-detail-saved.png)

### Candidate selections (CRUD)

![Create Selection](screenshots/iphone-create-selection.png)
![Edit Selection](screenshots/iphone-edit-selection.png)
![Selection List](screenshots/iphone-selections-portrait.png)

![Seat limit validation](screenshots/iphone-seat-limit.png)
![Delete confirmation](screenshots/iphone-delete-confirm.png)
![Profile](screenshots/iphone-profile.png)

### Municipality-specific data

After changing the city to Surrey, only Surrey candidates appear and the Burnaby selections are hidden. Compare with the Burnaby directory above.

![Candidate Directory: Surrey](screenshots/iphone-directory-surrey.png)
![Selections: Surrey (empty)](screenshots/iphone-selections-surrey.png)

### iPhone landscape

![Candidate Directory (iPhone landscape)](screenshots/iphone-directory-landscape.png)

![Selection List (iPhone landscape)](screenshots/iphone-selections-landscape.png)

### iPad portrait

![Candidate Directory (iPad portrait)](screenshots/ipad-directory-portrait.png)
![Selection List (iPad portrait)](screenshots/ipad-selections-portrait.png)

### iPad landscape

![Candidate Directory (iPad landscape)](screenshots/ipad-directory-landscape.png)

![Candidate Details (iPad landscape, side by side)](screenshots/ipad-detail-landscape.png)

![Selection List (iPad landscape)](screenshots/ipad-selections-landscape.png)

![Profile (iPad)](screenshots/ipad-profile.png)

## 11. Known limitations

- **First request after idle:** the Azure App Service can take about 15 seconds to wake up, so the first login after a quiet period may time out. Trying again works.
- **Offline saving:** with no connection, Save waits until the connection returns before finishing.
- **Selection count:** the Profile screen's total counts only the current city's selections, since other cities' selections are hidden.
- **Tests:** there are no automated unit tests yet.
