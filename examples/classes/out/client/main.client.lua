local ruby = require(game.ReplicatedStorage.Ruby.Runtime)

--classdef
local Dog = {} do
    function Dog.new()
        local include = {}
        local idxMeta = setmetatable(Dog, { __index = {} })
        idxMeta.__type = "Dog"
        for mixin in ruby.list(include) do
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
end
--classdef
local Car = {} do
    function Car.new(make, model)
        local include = {}
        local idxMeta = setmetatable(Car, { __index = {} })
        idxMeta.__type = "Car"
        for mixin in ruby.list(include) do
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
        
        self.private.make = make
        self.private.model = model
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Car[k]
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
end
--classdef
local Counter = {} do
    Counter.count = 0
    function Counter.new()
        local include = {}
        local idxMeta = setmetatable(Counter, { __index = {} })
        idxMeta.__type = "Counter"
        for mixin in ruby.list(include) do
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
        
        true.count =  += 1
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Counter[k]
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
end
return Counter