<a href="https://github.com/R-unic/RoGems/tree/master/spec">
  <img src="https://github.com/R-unic/RoGems/actions/workflows/main.yml/badge.svg" alt="build_ci">
</a>
<a href="https://badge.fury.io/rb/rogems">
  <img src="https://badge.fury.io/rb/rogems.svg" alt="Gem Version">
</a>

# RoGems
RoGems is a Ruby to Lua transpiler written for use with Roblox (like roblox-ts)
It is **unfinished**.

## Examples
See <a href="https://github.com/R-unic/RoGems/tree/master/examples">examples</a> for more

### Lava Bricks
Ruby Source
```rb
collection = game.GetService("CollectionService")
lava_bricks = collection.GetTagged("Lava")

lava_bricks.each do |lava|
    lava.Touched.Connect do |hit|
        parent = hit.Parent
        humanoid = parent.FindFirstChildOfClass("Humanoid")
        if !humanoid.nil? then
            humanoid.TakeDamage(humanoid.Health)
        end
    end
end
```

Lua Output
```lua
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
```
