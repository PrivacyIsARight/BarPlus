
function widget:GetInfo()
	return {
		name	= "Disable NonBar Widgets",
		desc	= "What it says on the tin",
		author	= "Beherith",
		date	= "2021 june",
		license	= "GNU GPL, v2 or later",
		layer	= 100000000, -- last to load
		handler = true, -- otherwise it cant disable other widgets
		enabled	= true	--	loaded by default?
	}
end

--------------------------------------------------------------------

function widget:Initialize()
	widgetHandler:EnableWidget("Rapid Pool Cache")
end

