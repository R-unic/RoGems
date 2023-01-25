collection = game.GetService("CollectionService")
lava_bricks = collection.GetTagged("Lava")

lava_bricks.each_with_index do |lava, i|
    lava.Touched.Connect do |hit|
        parent = hit.Parent
        humanoid = parent.FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.TakeDamage(humanoid.Health)
        end
    end
end
