require "CodeGenerator"

RUNTIME_IMPORT = "local ruby = require(game.ReplicatedStorage.Ruby.Runtime)\n\n";
CONFIG = {
    "rootDir" => "./",
    "sourceDir" => "src",
    "outDir" => "out",
    "debugging" => false
}

def open_example(example_name, file_name, folder = "src")
    File.read(File.join(File.dirname(__FILE__), "../examples/#{example_name}/#{folder}/client/#{file_name}.#{folder == "src" ? "rb" : "lua"}"))
end

RSpec.describe CodeGenerator, "#generate" do
    context "transpiles examples" do
        it "hello world" do
            source = "puts 'Hello, world!'"
            expected_output = "print(\"Hello, world!\")"
            codegen = CodeGenerator.new(CONFIG, source)
            expect(codegen.generate).to eq(RUNTIME_IMPORT + expected_output)
            codegen.destroy
        end

        it "lava bricks" do
            source = open_example("lava_brick", "test", "src")
            expected_output = open_example("lava_brick", "test", "out")
            codegen = CodeGenerator.new(CONFIG, source)
            expect(codegen.generate).to eq(expected_output)
            codegen.destroy
        end
    end

    context "transpiles literals" do
        it "strings" do
            str_src = "puts 'foo', 'bar'"
            str_codegen = CodeGenerator.new(CONFIG, str_src)
            expect(str_codegen.generate).to eq(RUNTIME_IMPORT + "print(\"foo\", \"bar\")")
            str_codegen.destroy
        end

        it "numbers" do
            num_src = "puts 12345, 0x112233"
            num_codegen = CodeGenerator.new(CONFIG, num_src)
            expect(num_codegen.generate).to eq(RUNTIME_IMPORT + "print(12345, 1122867)")
            num_codegen.destroy
        end

        it "arrays" do
            arr_src = "puts [5, 'foo', 100, []]"
            arr_codegen = CodeGenerator.new(CONFIG, arr_src)
            expect(arr_codegen.generate).to eq(RUNTIME_IMPORT + "print({5, \"foo\", 100, {}})")
            arr_codegen.destroy
        end

        it "hashes" do
            hash_src = "puts({\"isWorking\" => true, epicness => 1000})"
            hash_codegen = CodeGenerator.new(CONFIG, hash_src)
            expect(hash_codegen.generate).to eq(RUNTIME_IMPORT + "print({\n    [\"isWorking\"] = true,\n    epicness = 1000\n})")
            hash_codegen.destroy
        end
    end
end
