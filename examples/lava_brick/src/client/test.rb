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
