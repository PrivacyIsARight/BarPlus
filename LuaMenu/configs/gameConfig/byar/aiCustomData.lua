local customProfiles = {
	['BARb'] = {
		{
			key  = 'hard_aggressive',  -- must conform to directory name
			name = 'Hard | Aggressive',  -- human readable name displayed in a list
			desc = 'Difficulty: Hard | Playstyle: Aggressive | Made by Flaka, tweaked by Corosus',
		},
		{
			key  = 'hard',
			name = 'Hard | Balanced',
			desc = 'Difficulty: Hard |Playstyle: Balanced |Made by Flaka',
		},
		{
			key  = 'medium',
			name = 'Medium | Lazy',
			desc = 'Difficulty: Medium |Playstyle: Learning mechanics',
		},
		{
			key  = 'easy',
			name = 'Easy | Slow',
			desc = 'Difficulty: Easy |Playstyle: First launch',
		},
		{
			key  = 'dev',
			name = 'Testing AI',
			desc = 'Testing config',
		},
	},
}

function CustomAiProfiles(name, items)
	local customs = customProfiles[name]
	if customs then
		for _, v in ipairs(customs) do
			table.insert(items, v)
		end
	end
end

return {
	CustomAiProfiles = CustomAiProfiles
}
