#!/usr/bin/env ruby

require 'puzzle_lib'
require 'yaml'

if __FILE__ == $0
  unless (1..2).include? ARGV.size
    $stderr.puts "Usage: #{$0} cube_definition [orientation]"
    exit 1
  end

  orientation = if ARGV.size < 2
                  0 
                else
                  ARGV.pop.to_i
                end

  pieces = YAML.load(open(ARGV.shift, 'r'))
  pieces.each do |piece|
    piece.find_symmetries
    piece.orientation = orientation
    p piece
  end
end
