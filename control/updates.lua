local function on_nth_tick(data)
	entity_on_nth_tick(data)
	gui_on_nth_tick(data)
end

script.on_nth_tick(10, on_nth_tick)
