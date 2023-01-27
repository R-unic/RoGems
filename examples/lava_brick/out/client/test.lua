local ruby = require(game.ReplicatedStorage.Ruby.Runtime)

local collection = game:GetService("CollectionService")
local lava_bricks = collection:GetTagged("Lava")
for lava in ruby.list(lava_bricks) do
    (type(lava.Touched) == "function" and lava:Touched() or lava.Touched):Connect(function(hit)    
        local parent = (type(hit.Parent) == "function" and hit:Parent() or hit.Parent)
        local humanoid = parent:FindFirstChildOfClass("Humanoid")
        if humanoid == nil then        
            humanoid:TakeDamage((type(humanoid.Health) == "function" and humanoid:Health() or humanoid.Health))
        end
    end)
end