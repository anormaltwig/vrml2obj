local shapeCounter = 0

function ParseFile(filename, offset)
	local file = assert(io.open(filename))
	local content = file:read("*a")

	local shapes = {}

	for transform in string.gmatch(content, "Transform%s*(%b{})") do
		local sx, sy, sz = string.match(transform, "translation%s+(-?%d+%.?%d*)[%s,](-?%d+%.?%d*)[%s,](-?%d+%.?%d*)")
		local rsx, rsy, rsz, ang = string.match(transform, "rotation%s+(-?%d+%.?%d*)[%s,](-?%d+%.?%d*)[%s,](-?%d+%.?%d*)[%s,](-?%d+%.?%d*)")
		local offX, offY, offZ = offset[1] or 0, offset[2] or 0, offset[3] or 0
		if sx then
			offX = tonumber(sx) + offX
			offY = tonumber(sy) + offY
			offZ = tonumber(sz) + offZ
		end

		for inline in string.gmatch(transform, "Inline%s*(%b{})") do
			local subFile = string.match(inline, "url%s*%[?%s*(%b\"\")")
			subFile = string.sub(subFile, 2, #subFile - 1)

			local cwd = string.match(filename, ".+/")
			ParseFile(cwd .. subFile, {offX, offY, offZ})
		end

		for s in string.gmatch(transform, "IndexedFaceSet%s+(%b{})") do
			local points = string.match(s, "point%s+(%b[])")
			local coordIndex = string.match(s, "coordIndex%s+(%b[])")

			local vertices = {}
			for strX, strY, strZ in string.gmatch(points, "(-?%d+%.?%d*)[%s,](-?%d+%.?%d*)[%s,](-?%d+%.?%d*)") do
				local x, y, z = tonumber(strX) or 0, tonumber(strY) or 0, tonumber(strZ) or 0

				if rsx then
					local ca, sa = math.cos(ang), math.sin(ang)
					local x1, y1, z1, x2, y2, z2 = tonumber(rsx), tonumber(rsy), tonumber(rsz), x, y, z

					local length = (x1 * x1 + y1 * y1 + z1 * z1)^0.5
					x1, y1, z1 = x1 / length, y1 / length, z1 / length

					x = (ca + (x1^2) * (1-ca)) * x2 + (x1 * y1 * (1-ca) - z1 * sa) * y2 + (x1 * z1 * (1-ca) + y1 * sa) * z2
					y = (y1 * x1 * (1-ca) + z1 * sa) * x2 + (ca + (y1^2) * (1-ca)) * y2 + (y1 * z1 * (1-ca) - x1 * sa) * z2
					z = (z1 * x1 * (1-ca) - y1 * sa) * x2 + (z1 * y1 * (1-ca) + x1 * sa) * y2 + (ca + (z1^2) * (1-ca)) * z2
				end

				table.insert(vertices, {x + offX, y + offY, z + offZ})
			end

			local indexes = {}
			for n in string.gmatch(coordIndex, "(-?%d+%.?%d*)") do
				table.insert(indexes, n)
			end

			table.insert(shapes, {vertices = vertices, indexes = indexes})
		end
	end

	for _, shape in ipairs(shapes) do
		local obj = "# Converted Vrml2.0 file\n"

		for _, vertex in ipairs(shape.vertices) do
			obj = obj .. string.format("v %f %f %f\n", vertex[1], vertex[2], vertex[3])
		end

		local buf = {}
		for _, coord in ipairs(shape.indexes) do
			if coord ~= "-1" then
				table.insert(buf, tonumber(coord) + 1)
			else
				obj = string.format("%sf %s\n", obj, table.concat(buf, " "))
				buf = {}
			end
		end

		local out = assert(io.open(string.format("objs/%s%x.obj", string.match(filename, "/([^/]+)%..+$"), shapeCounter), "w"))
		out:write(obj)

		shapeCounter = shapeCounter + 1
	end
end

ParseFile("./MIL-coast.wrl", {0, 0, 0})

