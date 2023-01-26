$:.unshift File.join(File.dirname(__FILE__), "../src")
require "minitest/autorun"
require "parser/current"
require "CodeGenerator"

CONFIG = {
    "rootDir" => "./",
    "sourceDir" => "src",
    "outDir" => "out",
    "debugging" => false
}

class CodeGeneratorTest < Minitest::Test
    def test_hello_world
        source = "puts 'Hello, world!'"
        expected_output = "local ruby = require(game.ReplicatedStorage.RubyLib)\n\nprint(\"Hello, world!\")"
        transpiler = CodeGenerator.new(CONFIG, source)
        assert_equal(expected_output, transpiler.generate)
    end
    def test_lava_bricks
        source = open_example("lava_brick", "test", "src")
        expected_output = open_example("lava_brick", "test", "out")
        transpiler = CodeGenerator.new(CONFIG, source)
        assert_equal(expected_output, transpiler.generate)
    end
    def open_example(example_name, file_name, folder = "src")
        File.read(File.join(File.dirname(__FILE__), "../examples/#{example_name}/#{folder}/client/#{file_name}.#{folder == "src" ? "rb" : "lua"}"))
    end
end
