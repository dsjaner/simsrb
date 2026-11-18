--[[
	Theme — colours, fonts and a tiny `create` helper for building UI in code.
	Palette borrows from the Philippine flag (blue, red, sun-yellow) over warm wood tones.
]]

local C = Color3.fromRGB

local Theme = {
	bg = C(38, 30, 26),
	bgLight = C(62, 50, 42),
	panelTransparency = 0.12,
	text = C(250, 245, 235),
	textDim = C(200, 188, 170),
	yellow = C(252, 209, 22),
	red = C(206, 17, 38),
	blue = C(0, 56, 168),
	green = C(70, 190, 110),
	font = Enum.Font.GothamMedium,
	fontBold = Enum.Font.GothamBold,
	fontTitle = Enum.Font.FredokaOne,
	toast = {
		info = C(0, 56, 168),
		good = C(40, 150, 80),
		warn = C(210, 140, 20),
		bad = C(190, 30, 45),
	},
}

function Theme.create(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			if key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke(color: Color3?, thickness: number?): UIStroke
	return Theme.create("UIStroke", {
		Color = color or Theme.yellow,
		Thickness = thickness or 1.5,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Theme.create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

-- Standard dark rounded panel.
function Theme.panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.bg
	props.BackgroundTransparency = props.BackgroundTransparency or Theme.panelTransparency
	props.BorderSizePixel = 0
	local frame = Theme.create("Frame", props)
	Theme.corner(12).Parent = frame
	Theme.stroke().Parent = frame
	return frame
end

function Theme.label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Theme.text
	props.Font = props.Font or Theme.font
	props.TextSize = props.TextSize or 16
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return Theme.create("TextLabel", props)
end

function Theme.button(props: { [string]: any }): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.bgLight
	props.TextColor3 = props.TextColor3 or Theme.text
	props.Font = props.Font or Theme.fontBold
	props.TextSize = props.TextSize or 16
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	local button = Theme.create("TextButton", props)
	Theme.corner(10).Parent = button
	return button
end

return Theme
