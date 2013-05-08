#!/usr/bin/env ruby

module Challenge6
  def self.solve(input = $stdin.read)
    lines = input.split("\n")
    num_inputs = lines.shift.to_i
    solvers = num_inputs.times.map do
      width, height, speed, wait_time = lines.shift.split(' ').map(&:to_i)
      board = [].tap { |a| height.times { a << lines.shift } }
      Solver.new(width, height, speed, wait_time, board)
    end
    raise "Unmatched inputs, #{num_inputs} expected #{solvers.count} parsed" unless num_inputs == solvers.count

    solvers.map(&:to_s).join("\n")
  end

  class Path
    attr_reader :value, :positions, :board, :new_position_cost, :movement_cost
    def initialize(board, positions, value = 0.0, new_position_cost, movement_cost)
      @board = board
      @positions = positions
      @value = value
      @new_position_cost = new_position_cost
      @movement_cost = movement_cost
    end

    def clone
      self.class.new(self.board.clone, self.positions.clone, self.value, self.new_position_cost, self.movement_cost)
    end

    def unexplored_paths
      self.possible_next_positions.map do |x, y|
        self.clone.tap { |new_path| new_path.add_position([x, y]) }
      end
    end

    def possible_next_positions
      self.board.possible_paths(*self.position).tap do |a|
        a.delete(self.previous_position) if self.previous_position
      end
    end

    def moves
      self.positions.count - 1
    end

    def previous_position
      self.positions[-2]
    end

    def position
      self.positions[-1]
    end

    def distance(a, b)
      (a[0] - b[0]).abs + (a[1] - b[1]).abs
    end

    def heuristic_value
      self.value + (self.distance_to_exit * self.movement_cost) + self.new_position_cost
    end

    def distance_to_exit
      self.distance(self.position, self.board.exit_position)
    end

    def add_position(new_position)
      @positions << new_position
      @value += self.new_position_cost
      @value += self.distance(self.previous_position, self.position).to_f / self.movement_cost.to_f
    end
  end

  class Board
    KEY = {
      '·' => :ice,
      'X' => :start,
      'O' => :exit,
      '#' => :obstacle
    }
    KEY_I = KEY.invert
    attr_reader :width, :height
    attr_accessor :values
    def initialize(width, height, rows = nil)
      @width, @height = width, height
      if rows
        @values = rows.map { |row| row.chars.map{|char| KEY.fetch(char) } }
      end
    end

    def start_position
      @start_position ||= self.find_start_position
    end

    def exit_position
      @exit_position ||= self.find_exit_position
    end

    def find_start_position
      self.values.each_index { |y| x = self.values[y].index(:start); return [x, y] if x }
    end

    def find_exit_position
      self.values.each_index { |y| x = self.values[y].index(:exit); return [x, y] if x }
    end

    def fetch(x, y)
      @values.fetch(y).fetch(x)
    end

    def in_bounds?(x, y)
      @x_range ||= (0..self.width - 1)
      @y_range ||= (0..self.height - 1)
      @x_range.include?(x) && @y_range.include?(y)
    end

    def is_path?(x, y)
      self.in_bounds?(x, y) && self.fetch(x, y) != :obstacle #[:exit, :ice, :start].include?(self.fetch(x, y))
    end

    def possible_paths(x, y)
      [].tap do |a|
        yy = y + 1
        if self.is_path?(x, yy)
          yy += 1 while self.is_path?(x, yy)
          a << [x, yy - 1]
        end

        yy = y - 1
        if self.is_path?(x, yy)
          yy -= 1 while self.is_path?(x, yy)
          a << [x, yy + 1]
        end

        xx = x + 1
        if self.is_path?(xx, y)
          xx += 1 while self.is_path?(xx, y)
          a << [xx - 1, y]
        end

        xx = x - 1
        if self.is_path?(xx, y)
          xx -= 1 while self.is_path?(xx, y)
          a << [xx + 1, y]
        end
      end
    end

    def inspect
      @center_padding ||= KEY_I.values.max { |v| v.length }.length + 2
      ''.tap do |s|
        s << '  ' + (0..width - 1).map { |i| i.to_s.center(@center_padding, ' ') }.join('') + "\n"
        (0..height - 1).each do |y|
          s << y.to_s.rjust(2, ' ')
          (0..width - 1).each do |x|
            s << KEY_I[fetch(x, y)].center(@center_padding, ' ')
          end
          s << "\n"
        end
      end
    end

    def clone
      self.class.new(self.width, self.height).tap do |i|
        i.values = @values.map { |a| a.clone }
      end
    end
  end

  class Solver
    attr_reader :board, :movement_cost, :new_position_cost, :exit_position, :start_position
    def initialize(width, height, movement_cost, new_position_cost, board)
      @board = Board.new(width, height, board)
      @movement_cost = movement_cost
      @new_position_cost = new_position_cost
      @start_position = self.board.start_position
      @exit_position = self.board.exit_position
    end

    def search
      initial_path = Path.new(self.board, [self.start_position], 0.0, self.new_position_cost, self.movement_cost)
      @open_paths = initial_path.unexplored_paths
      until @open_paths.any? { |path| path.position == self.exit_position }
        min_value = @open_paths.map(&:heuristic_value).min
        min_value_paths = @open_paths.select { |path| path.heuristic_value == min_value }
        @open_paths -= min_value_paths
        @open_paths += min_value_paths.map { |path| path.unexplored_paths }.flatten

      end
      @open_paths.select{ |path| path.position == self.exit_position}.min_by { |path| path.value }
    end

    def print_paths(*paths)
      paths.flatten.each do |path|
        puts "#{path.value.to_s.rjust(2, ' ')}:#{path.heuristic_value.to_s.rjust(2, ' ')} #{path.positions.map{|x,y| "#{x},#{y}" }.join(' - ')}"
      end
      puts '==' * 50
    end

    def to_s
      if (min_path = self.search)
        min_path.value.round.to_s
      else
        'error'
      end
    end
  end
end

puts Challenge6.solve