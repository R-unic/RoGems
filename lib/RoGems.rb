$:.unshift File.join(File.dirname(__FILE__), "rogems")
require "yaml"
require "CLI"

module RoGems
    CONFIG_PATH = File.join(File.dirname(__FILE__), "../rogems.config.yml")
    ROGEMS_CONFIG = YAML.load_file(CONFIG_PATH)
    CLI::MainCommand.new
end
