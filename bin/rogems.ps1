# Check if Ruby is installed
if (!(Get-Command ruby -ErrorAction SilentlyContinue)) {
    Write-Output "Error: Ruby is not installed. Please install Ruby and try again."
    exit 1
}

# Get the script's current directory
$current_dir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Run the RoGems.rb script
& ruby "$current_dir/../src/RoGems.rb" $args
