$:.unshift File.join(File.dirname(__FILE__), "rogems")
require "CLI"

cli_interface = RoGems::CLI.new
