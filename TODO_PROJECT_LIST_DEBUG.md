# TODO_PROJECT_LIST_DEBUG

## Goal
Fix: “failed to load projects” when opening the Project List screen.

## Steps
- [ ] 1) Add defensive Firestore parsing in `ProjectModel.fromFirestore` (avoid runtime type casts throwing).
- [ ] 2) Improve `ProjectProvider.loadProjects()` debug logging and error propagation.
- [ ] 3) Show `provider.error` details on the Project List screen.
- [ ] 4) Remove/avoid double-loading (`initState` + `didChangeDependencies`) unless refresh is requested.
- [ ] 5) Run and verify: open Project List screen and confirm no error UI; check logs if still failing.

