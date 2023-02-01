-- Compiled with roblox-ts v2.0.4
local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("TS_Include"):WaitForChild("RuntimeLib"))
local Roact = TS.import(script, game:GetService("ReplicatedStorage"), "TS_Include", "node_modules", "@rbxts", "roact", "src")
local element = (Roact.createElement("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
}, {
	Child = Roact.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
	}),
}))
return nil
