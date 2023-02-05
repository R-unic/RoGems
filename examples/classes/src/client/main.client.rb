# Example 1: Simple class with a method
class Dog
  def bark
    puts "Woof!"
  end
end

# Example 2: Class with a constructor
class Car
  def initialize(make, model)
    @make = make
    @model = model
  end

  def display
    puts "The car is a #{@make} #{@model}"
  end
end

# Example 3: Class with class level variable
class Counter
  @@count = 0

  def initialize
    @@count += 1
  end

  def self.get_count
    @@count
  end
end
