#!/usr/bin/env ruby

require 'puzzle_lib'

if __FILE__ == $0
  if ARGV.size != 1
    $stderr.puts "Usage: #{$0} grid_definition"
    exit 1
  end

  grid = Puzzle::Helpers::load_grid_definition(ARGV.shift)
  generator = Puzzle::Generator.new(grid)


#   all = 10000.times.map do
#     generator.generate_random_bits(6, false, true, false).map { |x| x ? 1 : 0 }
#   end
#   all = all.uniq.sort
#   p all
#   p all.all? { |x| x.any? { |y| y==1 } && x.any? { |y| y==0 } }

  res = generator.generate(3..6) do |slots|
    p slots
  end
end
