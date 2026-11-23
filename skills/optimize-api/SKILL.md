---
name: optimize-api
description: Use this skill to enforce API evolution conventions when changing an existing API that released clients already call. Triggers on mentions of "add an API", "new endpoint", "extend the API", "change the API", "new parameter", "rename the endpoint", "response field", "backward compatible", "old client", "deprecate the endpoint", or whenever adding or changing an endpoint, its parameters or its response.
---

An API is a contract with clients that are already released and cannot be changed: an old app stays on people's phones. So an API change only adds, never replaces; whatever the change supersedes is marked deprecated and deleted when its date comes. Write every deprecation note as `optimize-comment` rule 4 says (since-date, removal date, replacement).

Before changing an API, answer these:

- Which clients call it (app, website, bot, older released versions)?
- Does a client that never updates get the same result as before?
- Does the name still say what it does?
- Did a path, a default or a field just become something only old clients use? Is it marked deprecated?

## 1. Extend Before Adding

When a client needs something an existing endpoint almost gives, extend that endpoint — an optional parameter, an extra response field — rather than writing a second one beside it.

- **Correct:** `record/my-identifier-stats/` only returned the caller's own stats; another player's stats came from adding an optional `?user=<id>` to the same view.
- **Incorrect:** a new view that copies the query and differs only in whose rows it reads.

## 2. A New Parameter's Default Is the Old Behaviour

A new parameter is optional, and a request without it must answer exactly as it did before the change, for the clients that will never send it. Handle the empty value on purpose too: a filter that skips an empty value turns "mine" into "everyone's".

When the new client code never relies on that default — it always sends the parameter — the default is only a compatibility layer: mark it deprecated, and make the parameter required once it expires. Whether to do so depends on the case; it is not a hard rule.

- **Correct:** no `?user=`, or an empty one, is still the caller; a test pins the empty case.
- **Incorrect:** making `user` required, or letting `?user=` fall through to an unfiltered query.

## 3. When the Name Stops Fitting, Add a Path and Keep the Old One as an Alias

If the extension makes the path's name misleading, serve the same endpoint under a name that fits, and keep the old path as an alias marked deprecated.

- **Correct:** `record/identifier-stats/` is the endpoint; `record/my-identifier-stats/` routes to it and carries the deprecation note.
- **Incorrect:** `record/my-identifier-stats/?user=123` as the documented way to read someone else's stats.

## 4. Response Fields Are Added, Never Changed

Adding a field is safe. To change a field's name, type or meaning, add a new field and mark the old one deprecated; remove it when it expires, so responses do not carry fields nobody reads forever.

- **Correct:** add `best_seconds` beside `best`, deprecate `best`, delete it after its date.
- **Incorrect:** changing what `best` holds in place, or keeping both fields with no end date.

A field that keeps its meaning but loses its use — the feature behind it is gone — is different: it stays in the response, marked potentially deprecated with no removal date (`optimize-comment` rule 6). Taking it out is a breaking change for every released client that parses the response.

## 5. One Implementation, Several Entrances

The old and the new path route to one view or handler; they do not each get a copy. Where a backend has more than one implementation of the endpoint (e.g. Django and a Go port), each of them serves both paths from its own single handler.

- **Correct:** two `url()` lines naming the same view class.
- **Incorrect:** a second view kept "for old clients", which drifts.

## 6. New Client Code Uses Only the New

Once the new path or field exists, every client being changed moves to it in the same piece of work. The deprecated one stays only for clients that have not updated, and appears nowhere in new code.

- **Correct:** the app's model endpoint is changed to `record/identifier-stats/`, for its own stats too.
- **Incorrect:** the new page calls the new path while the existing page keeps calling the old one.

## 7. Backend First, Clients After

Deploy the backend before any client that needs the change, and confirm it is live before the client ships: the backend serves old and new clients at once, a client only knows one side.

- **Correct:** deploy the backend, wait for it to report the new revision, then release the website and the app.
- **Incorrect:** releasing a client that calls a path production does not serve yet.
