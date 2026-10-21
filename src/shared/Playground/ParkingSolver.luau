-- Breadth-first search over legal slides. Used by assistance and solvability tests.
return function(cars, size, limit)
	local function key(board)
		local values = {}
		for _, c in board do
			table.insert(values, tostring(c.x + c.y * size))
		end
		return table.concat(values, ",")
	end
	local queue = { { cars = cars, plan = {} } }
	local seen = { [key(cars)] = true }
	local head = 1
	while head <= #queue and head <= limit do
		local entry = queue[head]
		head += 1
		if entry.cars[1].x == size - entry.cars[1].length then
			return entry.plan
		end
		for index, car in entry.cars do
			for _, direction in { -1, 1 } do
				for distance = 1, size - 1 do
					local x = car.x + (if car.horizontal then direction * distance else 0)
					local y = car.y + (if car.horizontal then 0 else direction * distance)
					local w, h = if car.horizontal then car.length else 1, if car.horizontal then 1 else car.length
					if x < 0 or y < 0 or x + w > size or y + h > size then
						break
					end
					local blocked = false
					for j, other in entry.cars do
						local ow, oh =
							if other.horizontal then other.length else 1, if other.horizontal then 1 else other.length
						if
							j ~= index
							and x < other.x + ow
							and x + w > other.x
							and y < other.y + oh
							and y + h > other.y
						then
							blocked = true
							break
						end
					end
					if blocked then
						break
					end
					local board = {}
					for j, c in entry.cars do
						board[j] = table.clone(c)
					end
					board[index].x, board[index].y = x, y
					local signature = key(board)
					if not seen[signature] then
						seen[signature] = true
						local plan = table.clone(entry.plan)
						table.insert(plan, { from = car.y * size + car.x + 1, to = y * size + x + 1 })
						table.insert(queue, { cars = board, plan = plan })
					end
				end
			end
		end
	end
	return nil
end
