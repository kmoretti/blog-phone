# Friend Link API Contract Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the blog-phone friend-link forms, models, requests, and all audited endpoints with the real routes and request models implemented by `E:\kmoretti-github\blog_api\api`.

**Architecture:** Keep public friend-link application payloads separate from authenticated admin payloads. Treat the API project's registered routes and Go request models as the only contract. Add the existing API `snapshot` field end-to-end, correct the three known client endpoint mismatches, and add contract tests that assert paths and JSON payloads without inventing new server endpoints.

**Tech Stack:** Flutter/Dart, Riverpod, Dio, Flutter test, existing `ApiClient`, Go API route registry as read-only contract source.

---

## File Map

- Modify `lib/features/friends/data/friend_links_api.dart`: add `snapshot`, add a public application payload/API client, and correct public list routing.
- Modify `lib/features/friends/presentation/friend_links_screen.dart`: add the API-backed snapshot field, distinguish admin `feed`/`rss`, and keep health-check controls admin-only.
- Modify `lib/features/rss/data/rss_api.dart`: correct public RSS list and refresh endpoints.
- Modify `test/features/friends/friend_links_test.dart`: assert public route, snapshot parsing/serialization, admin payload, and application payload.
- Modify or create `test/features/rss/rss_api_test.dart`: assert public RSS list trailing slash and public refresh route.
- Add a focused endpoint contract test if the existing test structure cannot cover all production endpoint strings without brittle source inspection.
- Do not modify `E:\kmoretti-github\blog_api\api`; it is the source contract and remains read-only.

## Contract Rules

The implementation must use these existing API routes and fields:

```text
GET  /api/public/friend/
POST /api/public/friend/apply
GET  /api/public/rss/
POST /api/public/rss/refresh
```

Public application JSON fields:

```json
{
  "name": "...",
  "link": "...",
  "avatar": "...",
  "description": "...",
  "email": "...",
  "snapshot": "...",
  "friend_link_page": "...",
  "feed": "...",
  "enable_rss": true
}
```

Admin friend-link JSON fields may include the API model fields already supported by `/api/action/friend`, including `snapshot`, `feed`, `rss`, and `skip_health_check`.

---

### Task 1: Add failing API contract tests for friend links

**Files:**
- Modify: `test/features/friends/friend_links_test.dart`
- Modify: `lib/features/friends/data/friend_links_api.dart`

- [ ] **Step 1: Update the public list expectation to the API route**

Change the existing expectation from:

```dart
expect(
  adapter.request?.uri.toString(),
  'https://api.test/api/friend/?page=1&page_size=20',
);
```

to:

```dart
expect(
  adapter.request?.uri.toString(),
  'https://api.test/api/public/friend/?page=1&page_size=20',
);
```

- [ ] **Step 2: Add a snapshot parsing assertion**

Add `snapshot` to the fixture and assert it:

```dart
'snapshot': 'https://site.test/cover.png',
```

```dart
expect(item.snapshot, 'https://site.test/cover.png');
```

- [ ] **Step 3: Add a public application payload test before implementation**

Add a test that expects the public application payload to contain only API application fields:

```dart
test('serializes the API public friend application payload', () {
  const payload = FriendLinkApplyPayload(
    name: '站点',
    link: 'https://site.test',
    avatar: 'https://site.test/a.png',
    description: '描述',
    email: 'owner@site.test',
    snapshot: 'https://site.test/cover.png',
    friendLinkPage: 'https://site.test/friends',
    feed: 'https://site.test/feed.xml',
    enableRss: true,
  );

  expect(payload.toJson(), const {
    'name': '站点',
    'link': 'https://site.test',
    'avatar': 'https://site.test/a.png',
    'description': '描述',
    'email': 'owner@site.test',
    'snapshot': 'https://site.test/cover.png',
    'friend_link_page': 'https://site.test/friends',
    'feed': 'https://site.test/feed.xml',
    'enable_rss': true,
  });
});
```

- [ ] **Step 4: Run the focused friend tests and confirm the new tests fail**

Run:

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart --reporter expanded
```

Expected: compile failures for missing `snapshot` and `FriendLinkApplyPayload`, plus the old public route assertion failure until implementation is added.

---

### Task 2: Implement API friend-link models and requests

**Files:**
- Modify: `lib/features/friends/data/friend_links_api.dart`

- [ ] **Step 1: Add `snapshot` to `FriendLinkDto`**

Add it to the constructor, fields, `fromJson`, and `toJson`:

```dart
required this.snapshot,
...
final String snapshot;
...
snapshot: _string(json['snapshot']),
...
'snapshot': snapshot,
```

- [ ] **Step 2: Add snapshot to the admin payload**

Add nullable `snapshot` to `FriendLinkPayload` and submit it using the API model field name:

```dart
this.snapshot,
...
final String? snapshot;
...
if (snapshot != null) 'snapshot': snapshot,
```

Keep `skip_health_check`, `feed`, and `rss` unchanged for admin requests.

- [ ] **Step 3: Add a separate public application payload**

Implement:

```dart
class FriendLinkApplyPayload {
  const FriendLinkApplyPayload({
    required this.name,
    required this.link,
    required this.avatar,
    required this.email,
    this.description = '',
    this.snapshot = '',
    this.friendLinkPage = '',
    this.feed = '',
    this.enableRss = false,
  });

  final String name;
  final String link;
  final String avatar;
  final String email;
  final String description;
  final String snapshot;
  final String friendLinkPage;
  final String feed;
  final bool enableRss;

  Map<String, dynamic> toJson() => {
    'name': name,
    'link': link,
    'avatar': avatar,
    'description': description,
    'email': email,
    'snapshot': snapshot,
    'friend_link_page': friendLinkPage,
    'feed': feed,
    'enable_rss': enableRss,
  };
}
```

Do not include `skip_health_check`, `status`, `rejection_reason`, `color`, `tags`, or admin `rss` in this payload.

- [ ] **Step 4: Add the public application API call**

Add to `FriendLinksApi`:

```dart
Future<void> apply(FriendLinkApplyPayload payload) async {
  await client.post('public/friend/apply', data: payload.toJson());
}
```

This uses the already registered API route; no API route is created.

- [ ] **Step 5: Correct the public friend list endpoint**

Change:

```dart
admin ? 'action/friend' : 'friend/'
```

to:

```dart
admin ? 'action/friend' : 'public/friend/'
```

- [ ] **Step 6: Run friend tests and verify they pass**

Run:

```powershell
flutter test --no-pub test/features/friends/friend_links_test.dart --reporter expanded
```

Expected: all friend API contract tests pass.

---

### Task 3: Add snapshot and correct friend form semantics

**Files:**
- Modify: `lib/features/friends/presentation/friend_links_screen.dart`
- Modify: `test/features/friends/friend_links_test.dart` if widget-level field assertions are needed

- [ ] **Step 1: Add the snapshot controller**

Extend the `fields` map with:

```dart
'snapshot': TextEditingController(text: item?.snapshot ?? ''),
```

- [ ] **Step 2: Add the website cover field**

Place it after the icon field and use the API's existing name:

```dart
_field(fields['snapshot']!, '网站封面'),
```

The field sends `snapshot`; do not call it `cover_url` or add a new model field with that name.

- [ ] **Step 3: Rename the admin RSS labels to distinguish API fields**

Use:

```dart
_field(fields['feed']!, 'Feed 地址'),
_field(fields['rss']!, 'RSS 备用地址'),
```

Do not merge or rename the payload fields.

- [ ] **Step 4: Add a health-check explanation without changing API behavior**

Replace the current admin switch title with a tooltip or supporting text that explains:

```text
开启后，系统不会自动检查该友链的可访问性。仅管理员使用。
```

Keep the submitted key exactly `skip_health_check`.

- [ ] **Step 5: Pass snapshot into `FriendLinkPayload`**

Add:

```dart
snapshot: fields['snapshot']!.text.trim(),
```

to the existing admin payload construction.

- [ ] **Step 6: Run widget and friend tests**

Run:

```powershell
flutter test --no-pub test/features/friends --reporter expanded
```

Expected: friend list and form tests pass.

---

### Task 4: Correct RSS endpoints and add contract tests

**Files:**
- Modify: `lib/features/rss/data/rss_api.dart`
- Modify: or create `test/features/rss/rss_api_test.dart`

- [ ] **Step 1: Add failing route assertions**

Assert the public list request is:

```text
https://api.test/api/public/rss/?page=1&page_size=20
```

Assert refresh uses:

```text
https://api.test/api/public/rss/refresh
```

- [ ] **Step 2: Correct the public list endpoint**

Change:

```dart
client.get('public/rss', ...)
```

to:

```dart
client.get('public/rss/', ...)
```

- [ ] **Step 3: Correct the refresh endpoint**

Change:

```dart
client.post('rss/refresh')
```

to:

```dart
client.post('public/rss/refresh')
```

- [ ] **Step 4: Run RSS tests**

Run:

```powershell
flutter test --no-pub test/features/rss --reporter expanded
```

Expected: all RSS API tests pass.

---

### Task 5: Audit all production endpoints against the API route registry

**Files:**
- Inspect: `lib/**/*.dart`
- Inspect: `E:\kmoretti-github\blog_api\api\src\cmd\router\register.go`
- Modify: only files with verified path, method, or request-body mismatches
- Test: `test/features/**`

- [ ] **Step 1: Extract every production `ApiClient` endpoint**

Search:

```powershell
Get-ChildItem -Recurse lib -Filter *.dart | Select-String -Pattern "client\.(get|post|put|delete|postMultipart)\("
```

Record method, endpoint, and payload shape for each result.

- [ ] **Step 2: Compare each endpoint to the API registration**

Use the route groups in:

```text
E:\kmoretti-github\blog_api\api\src\cmd\router\register.go
```

Verify exact prefix (`public/`, `action/`, `verify/`), HTTP method, path parameters, and trailing slash where API registers one.

- [ ] **Step 3: Fix only confirmed mismatches**

Confirmed fixes in this plan are:

```dart
'friend/'       -> 'public/friend/'
'rss/refresh'   -> 'public/rss/refresh'
'public/rss'    -> 'public/rss/'
```

If the audit identifies another mismatch, add a focused failing test first and only change the client to an endpoint present in `register.go`. Do not create or modify API routes.

- [ ] **Step 4: Add a report test or checked fixture for the audited paths**

Keep tests focused on behavior and endpoint contracts. Do not assert undocumented routes. For every corrected endpoint, assert the complete URL and HTTP method using the existing Dio adapter pattern.

- [ ] **Step 5: Run the feature test suites**

Run:

```powershell
flutter test --no-pub test/features/friends test/features/rss --reporter expanded
```

Expected: zero failures.

---

### Task 6: Final verification

**Files:**
- Inspect: all changed files

- [ ] **Step 1: Run formatting on changed Dart files**

Run:

```powershell
dart format lib/features/friends/data/friend_links_api.dart lib/features/friends/presentation/friend_links_screen.dart lib/features/rss/data/rss_api.dart test/features/friends/friend_links_test.dart test/features/rss/rss_api_test.dart
```

Expected: formatter exits successfully.

- [ ] **Step 2: Run focused tests**

Run:

```powershell
flutter test --no-pub test/features/friends test/features/rss --reporter expanded
```

Expected: all focused tests pass.

- [ ] **Step 3: Run static analysis**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`.

- [ ] **Step 4: Check whitespace and working tree**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only intended files changed.

- [ ] **Step 5: Review for invented API calls or fields**

Search changed files for:

```text
cover_url
rss_url
/api/friend
/api/rss
```

Expected: no newly introduced endpoint or field outside the API contract. Existing `friend_rss.rss_url` may appear only when representing the API's existing RSS resource model, not as a friend application field.

- [ ] **Step 6: Commit only after explicit commit approval**

Do not commit or push as part of implementation unless the user explicitly asks for it. If approved, use a conventional message such as:

```text
fix(friends): align mobile forms with API contract
```
