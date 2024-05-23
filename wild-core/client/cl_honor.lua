
function AddPlayerName()
	EnableControlAction(0, `INPUT_OPEN_WHEEL_MENU`, false)
	AnimpostfxStop("WheelHUDIn")

	local mpRankBar = DatabindingAddDataContainerFromPath("", "mp_rank_bar")
	DatabindingAddDataString(mpRankBar, "rank_header_text", GetPlayerName(PlayerId()))
	DatabindingAddDataString(mpRankBar, "rank_text", "1")
	DatabindingAddDataFloat(mpRankBar, "xp_bar_minimum", 0.0)
	DatabindingAddDataFloat(mpRankBar, "xp_bar_maximum", 100.0)
	DatabindingAddDataFloat(mpRankBar, "xp_bar_value", 55.0)

	-- Honor Level
	local RPGStatusIcons = DatabindingAddDataContainerFromPath("", "RPGStatusIcons")
	local honorIcon = DatabindingAddDataContainer(RPGStatusIcons, "HonorIcon")
	DatabindingAddDataInt(honorIcon, "State", 3) -- 1:lowest honor, 16:highest honor
end
AddPlayerName()