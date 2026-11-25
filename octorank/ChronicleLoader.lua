if ORANK_SKIP then return end
--[[--------------------------------------------------------------------
	OctoRank - built-in Chronicle logger

	The copy of ChronicleCompanion (by Emyrk) that WhoDidIt ships, in Chronicle\.
	It logs nothing until the player says yes (Logs.lua asks when they enter a raid)
	and keeps its settings in OctoRank's own saved variables. A separate
	ChronicleCompanion that's running makes this copy stand down.
----------------------------------------------------------------------]]

WDI_CHRON_SKIP = IsAddOnLoaded("ChronicleCompanion") and true or false

-- the version Chronicle writes into its log header and shows in /chronicle
function WDI_ChronVersion()
	return WDI_CHRON_VERSION or ""
end
