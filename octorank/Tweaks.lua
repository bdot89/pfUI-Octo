if ORANK_SKIP then return end
--[[--------------------------------------------------------------------
	OctoRank - WhoDidIt's board without the parts that need its fight tracker
	or chat posts. Board.lua stays WhoDidIt's file; these are switched off here.
----------------------------------------------------------------------]]

local B = OctoRank.Board

-- raid kills are recorded by WhoDidIt's fight tracker, which OctoRank doesn't have, so a
-- raid "run" would never see a boss die: no run in progress, and the run timer is 5-mans only
function B:CurrentRun() return nil end
B.LastRun = nil

-- the rival watch and its taunts: chat posts, not rankings
B.CheckRivals = nil
B.Rivals = nil
