-- local ruby = require(game.ReplicatedStorage.RubyLib)

--classdef
local Lib = {} do
    Lib.value = "hello world"
    Lib.foo = "bar"
    function Lib.new()
        local include = {}
        local idxMeta = setmetatable(Lib, { __index = {} })
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
        
        self.private.instance = "yes"
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Lib[k]
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
print(Lib.value)