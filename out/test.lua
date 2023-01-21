--classdef
local Animal = {} do
    function Animal.new(_name)
        local include = {}
        local idxMeta = setmetatable(Animal, { __index = {} })
        for _, mixin in pairs(include) do
            for k, v in pairs(mixin) do
                idxMeta[k] = v
            end
        end
        local self = setmetatable({}, { __index = idxMeta })
        self.attr_accessor = setmetatable({}, { __index = idxMeta.attr_accessor or {} })
        self.attr_reader = setmetatable({}, { __index = idxMeta.attr_reader or {} })
        self.attr_writer = setmetatable({}, { __index = idxMeta.attr_writer or {} })
        self.writable = {}
        self.private = {}
        
        self.attr_accessor.name = _name
        self.writable.name = true
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Animal[k]
            end,
            __newindex = function(t, k, v)
                if t.writable[k] or self.writable[k] or idxMeta.writable[k] then
                    if self.attr_writer[k] then
                        self.attr_writer[k] = v
                    elseif self.attr_accessor[k] then
                        self.attr_accessor[k] = v
                    end
                else
                    error("Attempt to write to un-writable attribute '"..k.."'")
                end
            end
        })
    end
    
    function Animal:move()
        print("i am moving")
    end
end
--moduledef
local Eater = {} do
    function Eater:eat()
        print("i am eating")
    end
end
--classdef
local Dog = {} do
    function Dog.new(name)
        local include = {Eater}
        local idxMeta = setmetatable(Dog, { __index = Animal.new(name) })
        for _, mixin in pairs(include) do
            for k, v in pairs(mixin) do
                idxMeta[k] = v
            end
        end
        local self = setmetatable({}, { __index = idxMeta })
        self.attr_accessor = setmetatable({}, { __index = idxMeta.attr_accessor or {} })
        self.attr_reader = setmetatable({}, { __index = idxMeta.attr_reader or {} })
        self.attr_writer = setmetatable({}, { __index = idxMeta.attr_writer or {} })
        self.writable = {}
        self.private = {}
        
        
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Dog[k]
            end,
            __newindex = function(t, k, v)
                if t.writable[k] or self.writable[k] or idxMeta.writable[k] then
                    if self.attr_writer[k] then
                        self.attr_writer[k] = v
                    elseif self.attr_accessor[k] then
                        self.attr_accessor[k] = v
                    end
                else
                    error("Attempt to write to un-writable attribute '"..k.."'")
                end
            end
        })
    end
    
    function Dog:bark()
        print("i am barking")
    end
end
local dog = Dog.new("fido")
print(type(dog.name) == "function" and dog:name() or dog.name)
local _ = type(dog.move) == "function" and dog:move() or dog.move
local _ = type(dog.bark) == "function" and dog:bark() or dog.bark
local _ = type(dog.eat) == "function" and dog:eat() or dog.eat
dog.name = "rex"
print(type(dog.name) == "function" and dog:name() or dog.name)