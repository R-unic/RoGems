require "CodeGenerator"

RUNTIME_IMPORT = "local ruby = require(game.ReplicatedStorage.Ruby.Runtime)\n\n";
CONFIG = {
    "rootDir" => "./",
    "sourceDir" => "src",
    "outDir" => "out",
    "debugging" => false,
    "useTS" => false
}

def open_example(example_name, file_name, folder = "src")
    File.read(File.join(File.dirname(__FILE__), "../examples/#{example_name}/#{folder}/client/#{file_name}.#{folder == "src" ? "rb" : "lua"}"))
end

def compile_example(example_name, file_name)
    source = open_example(example_name, file_name, "src")
    expected_output = open_example(example_name, file_name, "out")
    codegen = RoGems::CodeGenerator.new(CONFIG, source)
    expect(codegen.generate).to eq(expected_output)
    codegen.destroy
end

RSpec.describe RoGems::CodeGenerator, "#generate" do
    context "transpiles examples" do
        it "hello world" do
            source = "puts 'Hello, world!'"
            expected_output = "print(\"Hello, world!\")"
            codegen = RoGems::CodeGenerator.new(CONFIG, source)
            expect(codegen.generate).to eq(RUNTIME_IMPORT + expected_output)
            codegen.destroy
        end

        it "lava bricks" do
            compile_example("lava_brick", "test")
        end

        it "classes & inheritance" do
            compile_example("classes", "main.client")
        end
    end

    context "transpiles literals" do
        it "strings" do
            str_src = "puts 'foo', 'bar'"
            str_codegen = RoGems::CodeGenerator.new(CONFIG, str_src)
            expect(str_codegen.generate).to eq(RUNTIME_IMPORT + "print(\"foo\", \"bar\")")
            str_codegen.destroy
        end

        it "numbers" do
            num_src = "puts 12345, 0x112233"
            num_codegen = RoGems::CodeGenerator.new(CONFIG, num_src)
            expect(num_codegen.generate).to eq(RUNTIME_IMPORT + "print(12345, 1122867)")
            num_codegen.destroy
        end

        it "arrays" do
            arr_src = "puts [5, 'foo', 100, []]"
            arr_codegen = RoGems::CodeGenerator.new(CONFIG, arr_src)
            expect(arr_codegen.generate).to eq(RUNTIME_IMPORT + "print({5, \"foo\", 100, {}})")
            arr_codegen.destroy
        end

        it "hashes" do
            hash_src = "puts({\"isWorking\" => true, epicness => 1000})"
            hash_codegen = RoGems::CodeGenerator.new(CONFIG, hash_src)
            expect(hash_codegen.generate).to eq(RUNTIME_IMPORT + "print({\n    [\"isWorking\"] = true,\n    epicness = 1000\n})")
            hash_codegen.destroy
        end
    end

    context "transpiles method aliases" do
        it "'nil?' -> '== nil'" do
            source = "'hello'.nil?"
            expected_output = "\"hello\" == nil"
            codegen = RoGems::CodeGenerator.new(CONFIG, source)
            expect(codegen.generate).to eq(RUNTIME_IMPORT + expected_output)
            codegen.destroy
        end
    end
end
