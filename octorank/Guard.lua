--[[--------------------------------------------------------------------
	pfUI Octo: OctoRanks (made by tools\Sync-OctoRank.ps1 - do not edit)

	OctoRank built into pfUI. Every file here starts with
	"if ORANK_SKIP then return end": with WhoDidIt or the separate OctoRank
	add-on loaded (pfUI.toc's OptionalDeps load them first) this copy does
	nothing at all - no second channel, board or logger. They are one
	network (channel WDIBoard), and modules\octorank.lua keeps the times
	of all three in step.
----------------------------------------------------------------------]]

ORANK_SKIP = (IsAddOnLoaded("WhoDidIt") or IsAddOnLoaded("OctoRank")) and true or false
ORANK_PFUI = not ORANK_SKIP