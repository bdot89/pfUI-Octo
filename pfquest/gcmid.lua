if pfQuestOctoSkip then return end
-- pfUI Octo (written by tools\Sync-pfQuest.ps1): the base database is read - clean its read-in garbage now, during
-- the loading screen, before the Turtle data doubles it (out-of-memory crashes in d3d9.dll, 18 Nov 2026)
collectgarbage()
