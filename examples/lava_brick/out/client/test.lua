local ruby = require(game.ReplicatedStorage.RubyLib)

local lava = script.Parent
return (type(lava.Touched) == "function" and lava:Touched() or lava.Touched).Connect(function(hit)
    local parent = (type(hit.Parent) == "function" and hit:Parent() or hit.Parent)
    local humanoid = parent.FindFirstChildOfClass"Humanoid"
    if humanoid then    
        humanoid.TakeDamage(type(humanoid.Health) == "function" and humanoid:Health() or humanoid.Health)
    end
end)