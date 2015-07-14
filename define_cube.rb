#!/usr/bin/env ruby

require 'puzzle_lib'
require 'yaml'
require 'ostruct'

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "Usage: #{$0} output_file"
    exit 1
  end

  pieces = []
  puts "Puzzleteile definieren: "
  puts "="*30

  i = 0
  loop do
    print "Geben Sie ein neues Puzzleteil ein (leere Zeile terminiert die Eingabe): "
    line = STDIN.gets
    break if line.nil? || line.strip.empty?
    meta = OpenStruct.new
    meta.index = i
    pieces << (piece = Puzzle::Piece.new(line.chomp, 0, meta))
    piece.find_symmetries
    p piece
    i += 1
  end

  open(ARGV.shift, 'w+') { |f| YAML.dump(pieces, f) }
end
