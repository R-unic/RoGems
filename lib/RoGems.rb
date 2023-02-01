$:.unshift File.join(File.dirname(__FILE__), "rogems")
require "yaml"
require "CLI"
require "rogems/compiler_types"

module RoGems
    CONFIG_PATH = File.join(File.dirname(__FILE__), "../rogems.config.yml")
    ROGEMS_CONFIG = YAML.load_file(CONFIG_PATH)
    raise MissingGlobalConfig.new unless !ROGEMS_CONFIG.nil?

    CLI::MainCommand.new
end
