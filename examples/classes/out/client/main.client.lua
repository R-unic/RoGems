local ruby = require(game.ReplicatedStorage.Ruby.Runtime)

--classdef
local Entity = {} do
    function Entity.new()
        local include = {}
        local idxMeta = setmetatable(Entity, { __index = {} })
        idxMeta.__type = "Entity"
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
        
        self.private.position = 0
        self.private.health = 100
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Entity[k]
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
local Player = {} do
    function Player.new(name)
        local include = {}
        local idxMeta = setmetatable(Player, { __index = Entity.new() })
        idxMeta.__type = "Player"
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
        
        self.attr_accessor.name = name
        self.writable.name = true
        self.attr_reader.id = 1
        self.private.character = Character.new()
        
        return setmetatable(self, {
            __index = function(t, k)
                if not self.attr_reader[k] and not self.attr_accessor[k] and self.private[k] then
                    return nil
                end
                return self.attr_reader[k] or self.attr_accessor[k] or Player[k]
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
local plr = Player.new("John")
local _ = (type(plr.kill) == "function" and plr:kill() or plr.kill)
return print(plr.health)