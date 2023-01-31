class Entity
    attr_accessor :position, :health
    @position = 0
    @health = 100
end

class Player < Entity
    attr_accessor :name
    attr_reader :id, :character

    def initialize(name)
        @name = name
        @id = 1
        @character = Character.new
    end

    def kill
        @health = 0
        @character.destroy
    end
end

plr = Player.new("John")
plr.kill
puts plr.health
