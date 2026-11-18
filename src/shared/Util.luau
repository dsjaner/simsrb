--[[
	Util — small helpers shared by server and client.
]]

local Util = {}

-- Create an anchored, smooth part from a property table.
-- Pass ClassName = "WedgePart" / "Seat" etc. to make other part types.
function Util.part(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		(part :: any).Shape = props.Shape
	end
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

-- CFrame at `pos` whose +Z (our "front") faces `target` on the horizontal plane.
function Util.facing(pos: Vector3, target: Vector3): CFrame
	local flatTarget = Vector3.new(target.X, pos.Y, target.Z)
	if (flatTarget - pos).Magnitude < 1e-3 then
		return CFrame.new(pos)
	end
	return CFrame.lookAt(pos, pos + (pos - flatTarget))
end

-- Put a big, readable text label on one face of a part.
function Util.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SurfaceText"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(0.1, 0.1, 0.1)
	label.Text = text
	label.Parent = gui

	gui.Parent = part
	return label
end

function Util.formatPesos(amount: number?): string
	local n = math.floor(amount or 0)
	local digits = tostring(math.abs(n))
	local withCommas = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if withCommas:sub(1, 1) == "," then
		withCommas = withCommas:sub(2)
	end
	return (if n < 0 then "-₱" else "₱") .. withCommas
end

function Util.formatClock(clockTime: number): string
	local hour = math.floor(clockTime) % 24
	local minute = math.floor((clockTime - math.floor(clockTime)) * 60)
	local suffix = if hour < 12 then "AM" else "PM"
	local hour12 = hour % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return string.format("%d:%02d %s", hour12, minute, suffix)
end

function Util.formatHour(hour: number): string
	hour = hour % 24
	local suffix = if hour < 12 then "AM" else "PM"
	local hour12 = hour % 12
	if hour12 == 0 then
		hour12 = 12
	end
	return hour12 .. suffix
end

-- Filipino part-of-day label for the clock.
function Util.timeOfDay(clockTime: number): string
	if clockTime < 5 then
		return "Madaling-araw"
	elseif clockTime < 11 then
		return "Umaga"
	elseif clockTime < 13 then
		return "Tanghali"
	elseif clockTime < 18 then
		return "Hapon"
	end
	return "Gabi"
end

function Util.inHours(clockTime: number, hours: { number }?): boolean
	if not hours then
		return true
	end
	local open, close = hours[1], hours[2]
	if open < close then
		return clockTime >= open and clockTime < close
	end
	return clockTime >= open or clockTime < close -- wraps past midnight
end

function Util.averageNeeds(source: Instance, needOrder: { string }): number
	local total = 0
	for _, id in needOrder do
		total += source:GetAttribute("Need_" .. id) or 100
	end
	return total / #needOrder
end

return Util
