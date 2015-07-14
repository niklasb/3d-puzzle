#!/usr/bin/env ruby

require 'yaml'
require 'puzzle_lib'

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "Usage: #{$0} piece_definition"
    exit 1
  end

  pieces = open(ARGV.shift, 'r') { |f| YAML.load(f) }
  puts Puzzle::Algorithms::count_matching_edges(pieces)
end
