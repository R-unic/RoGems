class Animal
	attr_accessor :name

	def initialize(_name)
		@name = _name
	end

	def move
		puts "i am moving"
	end
end

module Eater
	def eat
		puts "i am eating"
	end
end

class Dog < Animal
	include Eater

	def initialize(name)
		super(name)
	end

	def bark
		puts "i am barking"
	end
end

dog = Dog.new("fido")
puts dog.name
dog.move
dog.bark
dog.eat
dog.name = "rex"
puts dog.name
