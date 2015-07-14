#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'enumerator'
require 'core_ext'
require 'ostruct'
require 'yaml'

module Puzzle
  class Piece
    EDGE_LENGTH = 4
    BIT_COUNT = 4*EDGE_LENGTH

    attr_reader :bits, :bits_reversed, :meta, :number, :different_orientations
    attr_accessor :orientation

    def initialize(bits = nil, orientation = 0, meta = nil)
      # Falls String als Initialisierungswert,
      # erzeuge Bit-Array
      if bits.is_a? String
        bits = bits.chars.to_a.map { |x| x=='1' ? 1 : 0 }
      end

      @bits = bits || [0]*BIT_COUNT
      @bits_reversed = bits.reverse.rotate(1)
      @orientation = 0
      @different_orientations = (0..7).to_a

      @meta = meta
    end

    def get_edge(i, orientation=nil)
      orientation, flipped = parse_orientation(orientation)
      i = ((i + orientation) * EDGE_LENGTH) % BIT_COUNT
      if flipped
        @bits_reversed[i, EDGE_LENGTH-1]
      else
        @bits[i, EDGE_LENGTH-1]
      end
    end

    def set_edge(i, new, orientation=nil)
      orientation, flipped = parse_orientation(orientation)
      i = ((i + orientation) * EDGE_LENGTH) % BIT_COUNT
      if flipped
        @bits_reversed[i, EDGE_LENGTH-1] = new
        @bits = @bits_reversed.reverse.rotate(-1)
      else
        @bits[i, EDGE_LENGTH-1] = new
        @bits_reversed = @bits.reverse.rotate(1)
      end
    end

    def get_corner(i, orientation=nil)
      orientation, flipped = parse_orientation(orientation)
      i = ((i + orientation + 1) * EDGE_LENGTH - 1) % BIT_COUNT
      if flipped
        @bits_reversed[i]
      else
        @bits[i]
      end
    end

    def set_corner(i, new, orientation=nil)
      orientation, flipped = parse_orientation(orientation)
      i = ((i + orientation + 1) * EDGE_LENGTH - 1) % BIT_COUNT
      if flipped
        @bits_reversed[i] = new
        @bits = @bits_reversed.reverse.rotate(-1)
      else
        @bits[i] = new
        @bits_reversed = @bits.reverse.rotate(1)
      end
    end

    def get_oriented_bits(orientation=nil)
      orientation, flipped = parse_orientation(orientation)
      (flipped ? @bits_reversed : @bits).rotate(orientation*EDGE_LENGTH)
    end

    def inspect
      # TODO generalize
      edges   = (0..3).map { |i| get_edge(i).map { |b| b==1 ? "O" : " " } }
      corners = (0..3).map { |i| get_corner(i)==1 ? "O" : " " }
      info = if @meta.respond_to? :index
               ' ' + @meta.index.to_s
             else
               ''
             end
      str  = "<# Puzzleteil%s>:\n" % info
      str += "bits = %s, reversed = %s\n" % [@bits.join(""), @bits_reversed.join("")]
      str += "different_orientations = %s\n" % [@different_orientations.join(',')]
      str += corners[3]  + " "   + edges[0].join(" ") + " " + corners[0] + "\n"
      str += edges[3][2] + " "*7 + edges[1][0]        + "\n"
      str += edges[3][1] + " "*7 + edges[1][1]        + "\n"
      str += edges[3][0] + " "*7 + edges[1][2]        + "\n"
      str += corners[2]  + " "   + edges[2].reverse.join(" ") + " " + corners[1] + "\n"
      "  " + str.gsub("\n", "\n  ")   # indentation
    end

    def find_symmetries
      # Senkrechte/Waagrechte Symmetrieachse
      count = 0

      # TODO Punktsymmetrie
      conditions = [
                    # Achsensymmetrie (TODO make more generic)
                    lambda { |bits| bits[2..8] == bits[10..16].reverse }, # Senkrecht/Waagrecht
                    lambda { |bits| bits[0..6] == bits[8..14].reverse },  # Diagonalen
                   ]

      # Prüfe mehrere Drehungen, um Redundanz zu vermeiden
      0.upto 1 do |i|
        bits = get_oriented_bits(i)*2

        conditions.each do |c|
          if c.call(bits)
            count += 1
            @different_orientations -= (4..7).to_a
            @different_orientations -= [2,3] if count > 1
            @different_orientations -= [1]   if count > 2
          end
        end
      end
    end

   private

    def parse_orientation(orientation = nil)
      orientation ||= @orientation
      # rotation, flipped
      [orientation, orientation >= 4]
    end
  end

  class Grid
    attr_reader :piece_count, :edges, :corners

    def initialize(piece_count)
      @piece_count = piece_count
      @constraints = []
      @edges, @corners = [], []
    end

    def add_edge(*args)
      @edges << args
      @constraints << GridConstraints::create_edge_constraint(*args)
    end

    def add_corner(*args)
      @corners << args
      @constraints << GridConstraints::create_corner_constraint(*args)
    end

    def check(piece_slots)
      @constraints.all? { |c| c.call(piece_slots) }
    end
  end

  class Solver
    def initialize(grid)
      @grid = grid
    end

    def solve(pieces, use_all_orientations = false, &block)
      piece_slots = [nil] * @grid.piece_count

      # Erstes Teil ist festgelegt
      piece_slots[0] = [pieces[0], 0]

      context = OpenStruct.new
      context.slots = piece_slots

      context.solution_count = 0
      context.checks = 0
      context.sum_of_levels = 0.0
      context.recursions = 0

      available_pieces = pieces[1..-1]
      context.orientations_for_pieces = if use_all_orientations
                                          [0..7]*available_pieces.size
                                        else
                                          available_pieces.map { |p|
                                            p.different_orientations
                                          }
                                        end

      backtrack(context, available_pieces, 1, &block)

      context.stats = {
        :average_depth       => context.sum_of_levels / context.recursions,
        :recursions          => context.recursions,
        :checks              => context.checks,
        :checks_per_solution => context.checks.to_f / context.solution_count,
        :solution_count      => context.solution_count,
        :used_all_transformations => use_all_orientations,
      }
      context
    end

   private

    def backtrack(context, available_pieces, level = 1, &block)
      if available_pieces.empty?
        context.solution_count += 1
        yield context.slots.clone if block_given?
        return
      end

      context.recursions += 1
      context.sum_of_levels += level

      available_pieces.each_with_index do |piece, i|
        context.orientations_for_pieces[i].each do |orientation|
          context.slots[level] = [piece, orientation]

          context.checks += 1
          next unless @grid.check(context.slots)
          backtrack(context, available_pieces - [piece], level+1, &block)
        end
      end

      # clean up!  (TODO make more clear by using an array copy?)
      context.slots[level] = nil
    end

    def self.extract_slot_data(slots)
      slots.map { |slot| [slot[0].meta.index, slot[1]] }
    end

    def self.inspect_simplified_slots(slots)
      slots.map { |x| "%i/%i" % x }
    end

    def self.inspect_slots(slots)
      inspect_simplified_slots(extract_slot_data(slots))
    end
  end

  class DifficultyRater
    def initialize(solver, pieces = nil)
      @solver = solver
      @pieces = pieces
    end

    def rate(context = nil, matching_edges = nil)
      if not context or not context.stats[:used_all_transformations]
        context = @solver.solve(@pieces, true)
      end
      m = matching_edges || Algorithms::count_matching_edges(@pieces)
      r = context.stats[:average_depth]
      s = context.solution_count
      (-m/50.0 - r + 2*Math.log(1/s.to_f)) / 4 + 6
    end
  end

  class Generator
    attr_reader :grid

    def initialize(grid, progress_callback = nil)
      @grid = grid
      @progress_callback = progress_callback
      @solver = Solver.new(grid)
      @rater = DifficultyRater.new(@solver)
    end

#     def generate(difficulty_range)
#       pieces = nil
#       loop do
#         pieces = generate_candidate
#         context = @solver.solve(pieces, true)
#         @progress_callback.call if @progress_callback
#         break
#         next if context.solution_count == 0
#         matching_edges = Algorithms::count_matching_edges(pieces)
#         rating = @rater.rate(context, matching_edges)
#         puts rating
#         break if difficulty_range.include? rating
#       end
#       pieces
#     end

    def generate(difficulty_range, &block)
      slots = [nil]*grid.piece_count
      context = OpenStruct.new

      context.slots = slots
      context.maximum_depth = 5
      context.difficulty_range = difficulty_range

      symmetries = (difficulty_range.last - difficulty_range.first)
      equal = (difficulty_range.last - difficulty_range.first)/6
      generate_backtrack(context, symmetries, &block)
      context
    end

    def generate_backtrack(context, available_symmetries, level = 0, &block)
      puts "   "*level + "entering level %i" % level
      if level > context.maximum_depth
        puts "   "*level + "too high, exiting"
        yield context if block_given?
        return
      end

      slots = context.slots

      symmetries = [available_symmetries, rand(3)+1].min
      puts "   "*level + "using %i symmetrie axes" % symmetries
      new_piece = generate_piece(symmetries)
      new_piece.find_symmetries
      new_piece.different_orientations.each do |orientation|
        puts "   "*level + " checking orientation %i" % orientation
        (0..slots.size-1).to_a.shuffle.each do |i|
          puts "   "*level + " testing position %i" % i
          if slots[i]
            puts "   "*level + " already taken."
            next
          end
          slots[i] = [new_piece, orientation]
          next unless @grid.check(slots)
          generate_backtrack(context, available_symmetries-symmetries, level+1, &block)
          slots[i] = nil
        end
      end
    end

    def generate_random_bits(length, force_different_bits = false,
                             first_has_to_be_set = false,
                             last_has_to_be_set = false)
      first = first_has_to_be_set || rand > 0.5
      last = last_has_to_be_set || rand > 0.5
      inner = (length-2).times.map { rand>0.5 }
      res = [first]+inner+[last]
      if force_different_bits
        if !res.any? { |x| x }   # only false values
          res[rand(res.size)] = true  # set a random bit to 1
        elsif !res.any? { |x| !x } # only true bits
          # consider the constraints
          from = first_has_to_be_set ? 1 : 0
          to   = last_has_to_be_set  ? res.size-1 : res.size
          res[rand(to-from)+from] = false  # set a random bit to 0
        end
      end
      res.map { |x| x ? 1 : 0 }
    end

    def generate_piece(symmetries = 1)
      bits = [0]*Piece::BIT_COUNT
      case symmetries
        when 0
          begin
            # Ecken
            bits[3], bits[7], bits[11], bits[15] = generate_random_bits(4)
            bits[0,3] = generate_random_bits(3, true, false, false)
            bits[4,3] = generate_random_bits(3, true, bits[3]==1 && bits[2]==0)
            bits[8,3] = generate_random_bits(3, true, bits[7]==1 && bits[6]==0)
            bits[12,3] = generate_random_bits(3, true,
                                         bits[11]==1 && bits[10]==0,
                                         bits[15]==1 && bits[0]==0)
          end
        when 1
          if rand > 0.5   # senkrechte Symmetrieachse
            # Ecken
            bits[3] = rand.round
            bits[7] = rand.round

            # Kanten
            bits[1,2] = generate_random_bits(2, true) # für Stabilität:
                                                      # muss eine Lücke oder
                                                      # Noppe enthalten
            bits[8,2] = generate_random_bits(2, true) # ebenso

            # rechte Kante: keine freihängenden Ecken!
            bits[4,3] = generate_random_bits(3, true,
                                             (bits[2] == 0 && bits[3] == 1),
                                             (bits[7] == 1 && bits[8] == 0))

            # Symmetrie sicherstellen
            bits[10,6] = bits[3,6].reverse
            bits[0] = bits[2]
          else   # diagonale Symmetrieachse
            # Ecken
            bits[3]  = rand.round
            bits[7]  = rand.round
            bits[11] = rand.round

            # Kanten
            # oberes Bit muss zu Ecke passen
            bits[4,3] = generate_random_bits(3, true, bits[3]==1)
            # beide Eckbits müssen zu der Vorgabe passen!
            bits[8,3] = generate_random_bits(3, true, bits[6]==0 && bits[7]==1,
                                                      bits[11]==1)

            # Symmetrie
            bits[0,3]  = bits[4,3].reverse
            bits[12,4] = bits[7,4].reverse
          end
        when 2
          begin
            # Ecke
            bits[3] = rand.round

            # Kanten
            bits[1,2] = generate_random_bits(2, true)
            bits[4,2] = generate_random_bits(2, true, bits[3]==1 && bits[2]==0)

            # Symmetrie
            bits[6,4] = bits[1,4].reverse
            bits[10,6] = bits[3,6].reverse
            bits[0] = bits[2]
          end
        when 3,4
          begin
            bits = ['0100010001000100', '1010101010101010'].choice
          end
      end
      Piece.new(bits)
    end

   private

    def generate_edge(length)
      [0,1,rand.round].shuffle
    end

    def generate_candidate
      pieces = grid.piece_count.times.map {
        Piece.new([0]*16)
      }

      grid.edges.each do |e|
        edge1 = generate_edge(3)
        pieces[e[0]].set_edge(e[1], edge1)
        if pieces[e[0]].get_edge(e[1]) != edge1
          puts "TEST!"
        end
        edge2 = edge1.reverse.map { |x| x==1 ? 0 : 1 }
        #pieces[e[2]].set_edge(e[3], edge2)
        p "edge: %s, piece %i,edge %i = %s, piece %i,edge %i = %s" % [e.inspect, e[0], e[1], edge1.inspect, e[2], e[3], edge2.inspect]
      end
      grid.corners.each do |c|
        piece_id = (rand*3).floor
        piece, corner_id = pieces[c[piece_id*2]], c[piece_id*2+1]
        #piece.bits[((corner_id+1)*Piece::EDGE_LENGTH-Piece::BIT_COUNT)%16] = 1
        piece.set_corner(corner_id, 1)
      end
      p pieces
      pieces
    end
  end

  module GridConstraints
    def self.test_edge_compatibility(edge1, edge2, reverse)
      edge2 = edge2.reverse if reverse
      (0..(edge1.size-1)).all? do |i|
        edge1[i] != edge2[i]
      end
    end

    def self.test_corner_compatibility(*corners)
      corners.reduce(:+) == 1
    end

    def self.create_edge_constraint(slot1_index, edge1,
                                    slot2_index, edge2,
                                    reversed = true)
      return lambda { |piece_slots|
        slot1 = piece_slots[slot1_index]
        slot2 = piece_slots[slot2_index]
        if slot1 && slot2
          test_edge_compatibility(slot1[0].get_edge(edge1, slot1[1]),
                                  slot2[0].get_edge(edge2, slot2[1]),
                                  reversed)
        else
          true
        end
      }
    end

    def self.create_corner_constraint(*args)
      case args.count
        when 6 then  create_corner_constraint3(*args)
        when 8 then  create_corner_constraint4(*args)
        when 10 then create_corner_constraint5(*args)
        else
          raise ArgumentError, "Unglültige Eckenspezifikation"
      end
    end

    def self.create_corner_constraint3(slot1_index, corner1,
                                      slot2_index, corner2,
                                      slot3_index, corner3)
      return lambda { |piece_slots|
        slot1, slot2, slot3 = \
                 piece_slots[slot1_index],
                 piece_slots[slot2_index],
                 piece_slots[slot3_index],

        if slot1 && slot2 && slot3
          test_corner_compatibility(slot1[0].get_corner(corner1, slot1[1]),
                                    slot2[0].get_corner(corner2, slot2[1]),
                                    slot3[0].get_corner(corner3, slot3[1]))
        else
          true
        end
      }
    end

    def self.create_corner_constraint4(slot1_index, corner1,
                                       slot2_index, corner2,
                                       slot3_index, corner3,
                                       slot4_index, corner4)
      return lambda { |piece_slots|
        slot1, slot2, slot3, slot4 = \
                 piece_slots[slot1_index],
                 piece_slots[slot2_index],
                 piece_slots[slot3_index],
                 piece_slots[slot4_index]

        if slot1 && slot2 && slot3 && slot4
          test_corner_compatibility(slot1[0].get_corner(corner1, slot1[1]),
                                    slot2[0].get_corner(corner2, slot2[1]),
                                    slot3[0].get_corner(corner3, slot3[1]),
                                    slot4[0].get_corner(corner4, slot4[1]))
        else
          true
        end
      }
    end

    def self.create_corner_constraint5(slot1_index, corner1,
                                       slot2_index, corner2,
                                       slot3_index, corner3,
                                       slot4_index, corner4,
                                       slot5_index, corner5)
      return lambda { |piece_slots|
        slot1, slot2, slot3, slot4, slot5 = \
                 piece_slots[slot1_index],
                 piece_slots[slot2_index],
                 piece_slots[slot3_index],
                 piece_slots[slot4_index],
                 piece_slots[slot5_index],

        if slot1 && slot2 && slot3 && slot4 && slot5
          test_corner_compatibility(slot1[0].get_corner(corner1, slot1[1]),
                                    slot2[0].get_corner(corner2, slot2[1]),
                                    slot3[0].get_corner(corner3, slot3[1]),
                                    slot4[0].get_corner(corner4, slot4[1]),
                                    slot5[0].get_corner(corner5, slot5[1]))
        else
          true
        end
      }
    end

  end

  module Algorithms
    def self.count_matching_edges(pieces)
      count = 0
      pieces.each_with_index do |p1, i|
        pieces[i+1..-1].each do |p2|
          p1_bits = p1.bits*3
          p2_bits = p2.bits*3
          0.upto 3 do |edge1_index|
            0.upto 3 do |edge2_index|
              edge1 = p1_bits[((edge1_index*4-1)+16)..((edge1_index+1)*4-1+16)]
              edge2 = p2_bits[((edge2_index*4-1)+16)..((edge2_index+1)*4-1+16)]
              if Puzzle::GridConstraints::test_edge_compatibility(edge1[1,3], edge2[1,3], true) and \
                    (edge1[0] + edge2[-1] <= 1) and (edge1[-1] + edge2[0] <= 1)
                count += 1
              end
              if Puzzle::GridConstraints::test_edge_compatibility(edge1[1,3], edge2[1,3], false) and \
                    (edge1[0] + edge2[0] <= 1) and (edge1[0] + edge2[0] <= 1)
                count += 1
              end
            end
          end
        end
      end
      count
    end  # count_matching edges
  end

  module Helpers
    def self.load_grid_definition(file)
      load(file)
      $grid
    end

    def self.load_cube_definition(file)
      if file.is_a? String
        open(file, 'r') { |f| YAML.load(f) }
      else
        YAML.load(f)
      end
    end
  end
end
