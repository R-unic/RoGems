lava = script.Parent

lava.Touched.Connect do |hit|
    parent = hit.Parent
    humanoid = parent.FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.TakeDamage(humanoid.Health)
    end
end
