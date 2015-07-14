#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
#
# Programm entstanden im Rahmen der Modellierungswoche 2009.
# Berechnet alle Lösungen eines 3D-Puzzles.
#
# == Usage
#
# Usage: solve_puzzle.rb [switches] grid_file cube_file
#
# Parameter:
#    cube_file      Die Definitionsdatei der Würfelteile
#    grid_file      Die Gitter-Definitions-Datei.
#                   Beschreibt die Bedingungen, die
#                   jeder Lösungskandidat erfüllen muss
#    -r             Bewerte die Schwierigkeit des Puzzles
#    -t             Auch Lösungen akzeptieren, die sich durch
#                   Rotation oder Umdrehen von Teilen
#                   ineinander überführen lassen
#    -c             Compact mode -- Ergebnis als CSV ausgeben
#    -v             Verbose mode -- Alle gefunden Lösungen
#                   ausgeben

require 'puzzle_lib'
require 'yaml'
#require 'rdoc/usage'

def usage
  #$stderr.puts RDoc::usage
  exit 1
end

# we are called from command line :)
if __FILE__ == $0
  use_all_transformations = false
  compact = false
  rate = false
  verbose = false

  args = []
  flags = {
    'r' => lambda { rate = true },
    't' => lambda { use_all_transformations = true },
    'c' => lambda { compact = true },
    'v' => lambda { verbose = true },
  }
  ARGV.each do |a|
    if a =~ /^-(.*)/
      if flags.keys.include? $1
        flags[$1].call
      else
        usage
      end
    else
      args << a
    end
  end

  usage if args.size != 2

  # load definitions
  grid   = Puzzle::Helpers::load_grid_definition(args.shift)
  pieces = Puzzle::Helpers::load_cube_definition(args.shift)

  # start the back-tracking algorithm
  solver = Puzzle::Solver.new(grid)
  context = solver.solve(pieces, use_all_transformations) do |solution|
    p Puzzle::Solver.inspect_slots(solution) if verbose
  end

  # collect run-time statistics
  stats = context.stats

  # Calculate our difficulty rate
  stats[:rating] = 'n/a'
  if rate
    rater = Puzzle::DifficultyRater.new(solver, pieces)
    stats[:rating] = rater.rate(context)
  end

  # Compact mode -- CSV output for statistical needs
  if compact
    puts "%f,%i,%i,%f,%i,%s" % [stats[:average_depth],
                                stats[:recursions],
                                stats[:checks],
                                stats[:checks_per_solution],
                                stats[:solution_count],
                                stats[:rating]]
  else  # Human mode ;)
    puts "Statistics:"
    puts "  Average depth: %f"       % stats[:average_depth]
    puts "  Consistency checks: %i"  % stats[:checks]
    puts "  Recursions: %i"          % stats[:recursions]
    puts "  Checks per solution: %i" % stats[:checks_per_solution]
    puts "  Solutions: %i"           % stats[:solution_count]
    puts "  Rating: %s"              % stats[:rating]
  end
end
