#!/usr/bin/env ruby

module Challenge7
  def self.solvers=(x)
    @solvers = x
  end
  def self.solvers
    @solvers
  end
  def self.solve(input = $stdin.read)
    lines = input.split("\n")
    num_inputs = lines.shift.to_i
    self.solvers = num_inputs.times.map do
      scores = lines.shift
      duration = lines.shift.to_i
      height = lines.shift.to_i
      width = lines.shift.to_i
      board = [].tap { |a| height.times { a << lines.shift.split(' ') } }
      Solver.new(scores, duration, width, height, board)
    end
    raise "Unmatched inputs, #{num_inputs} expected #{solvers.count} parsed" unless num_inputs == solvers.count

    solvers.map(&:to_s).join("\n")
  end

  class Dictionary
    attr_reader :words
    def initialize(file_path = 'boozzle-dict.txt')
      @words = File.read(file_path).split("\n")
      @index = @words.each_with_object({}) do |word, h|
        chars = word.chars
        h[word] = chars.uniq.each_with_object({}) { |char, char_h| char_h[char.to_sym] = chars.count(char) }
      end
    end

    def fetch(word)
      @index[word]
    end

    def each_with_index(&block)
      @words.each do |word|
        block.call(word, self.fetch(word))
      end
    end
  end
  DICTIONARY = Dictionary.new

  class Path
    def self.find_paths(board, letter_values, word)
      chars = word.chars.map(&:to_sym)
      paths = board.find_char_positions(chars.shift).map { |position| self.new(board, letter_values).tap { |path| path.add_position(position) } }
      return nil if paths.empty?
      chars.each do |char|
        paths.map! { |path| path.expanded_paths(char) }.flatten!
        break if paths.empty?
      end
      paths.each { |path| path.word = word }.uniq
    end

    attr_reader :board, :letter_values
    attr_accessor :positions, :word
    def initialize(board, letter_values)
      @board = board
      @letter_values = letter_values
      self.positions = []
    end

    def input_time
      self.length + 1
    end

    def value
      (self.position_values.inject(0,:+) * self.word_values.max) + self.length
    end

    def hash
      [self.value, self.word].hash
    end

    def eql?(other)
      self.word == other.word && self.value == other.value
    end

    def position_values
      self.positions.map do |x, y|
        cell = self.board.fetch(x, y)
        cell.cm * self.letter_values.fetch(cell.character)
      end
    end

    def word_values
      self.positions.map do |x, y|
        self.board.fetch(x, y).wm
      end
    end

    def length
      self.positions.count
    end

    def position
      self.positions[-1]
    end

    def expanded_paths(char)
      self.find_next_positions(char).map do |position|
        self.clone.tap { |new_path| new_path.add_position(position) }
      end
    end

    def find_next_positions(char)
      self.board.neighbors(*self.position).select { |x, y| !self.positions.include?([x, y]) && self.board.fetch(x, y).character == char.to_sym }
    end

    def add_position(new_position)
      self.positions << new_position
    end

    def clone
      super.tap {|c| c.positions = self.positions.clone }
    end

    def inspect
      s = "#{self.word}: Value = #{value} Cost = #{self.input_time}\n #{self.positions.map{|x,y| "([#{x},#{y}],#{self.letter_values.fetch(self.board.fetch(x, y).character)})" }.join(' -> ')}"
      #s << "\n#{self.position_values.join(', ')}"
      #s << "\n#{self.word_values.join(', ')}"
    end
  end

  class Board
    Cell = Struct.new(:character, :multiplier_type, :multiplier_value) do
      def cm
        self.multiplier_type == 1 ? self.multiplier_value : 1
      end
      def wm
        (self.multiplier_type == 2 ? self.multiplier_value : 1)
      end
      def to_s
        "#{self.character}:#{self.multiplier_type}:#{self.multiplier_value}"
      end
    end
    attr_reader :width, :height, :index
    attr_accessor :values
    def initialize(width, height, rows)
      @width, @height = width, height
      @values = rows.map { |row| row.map{|cell_values|
        char, m_type, m_value = *cell_values.chars
        Cell.new(char.to_sym, m_type.to_i, m_value.to_i)
      }}
      characters = @values.flatten.map { |cell| cell.character }
      @index = characters.uniq.each_with_object({}) { |char, h| h[char.to_sym] = characters.count(char) }
    end

    def fetch(x, y)
      self.values.fetch(y).fetch(x)
    end

    def fetch_char_index(char)
      self.index.fetch(char.to_sym, 0)
    end

    def each(&block)
      self.values.each_with_index do |row, y|
        row.each_with_index do |cell, x|
          block.call(cell, [x, y])
        end
      end
    end

    def find_char_positions(char)
      [].tap do |a|
        self.each { |cell, position| a << position if cell.character == char }
      end
    end

    def in_bounds?(x, y)
      @x_range ||= (0..self.width - 1)
      @y_range ||= (0..self.height - 1)
      @x_range.include?(x) && @y_range.include?(y)
    end

    def neighbors(x, y)
      [
        [x + 1, y],
        [x - 1, y],
        [x, y + 1],
        [x, y - 1],
        [x + 1, y + 1],
        [x - 1, y + 1],
        [x + 1, y - 1],
        [x - 1, y - 1]
      ].select { |x, y| self.in_bounds?(x, y) }
    end

    def inspect
      @center_padding ||= 7
      ''.tap do |s|
        #s << '  ' + (0..width - 1).map { |i| i.to_s.center(@center_padding, ' ') }.join('') + "\n"
        (0..height - 1).each do |y|
          #s << y.to_s.rjust(2, ' ')
          (0..width - 1).each do |x|
            s << fetch(x, y).to_s.center(@center_padding, ' ')
          end
          s << "\n"
        end
      end
    end
  end

  class Solver
    attr_reader :letter_values, :duration, :board
    def initialize(scores, duration, width, height, board)
      @letter_values = scores.scan(/\'([A-Z])\':\s(\d+),?\s?/).each_with_object({}) { |(k, v), h| h[k.to_sym] = v.to_i }
      @duration = duration
      @board = Board.new(width, height, board)
    end

    def possible_words
      unless @possible_words
        @possible_words = []
        DICTIONARY.each_with_index do |word, index|
          if index.all? { |char, count| self.board.fetch_char_index(char) >= count }
            @possible_words << word
          end
        end
      end
      @possible_words
    end

    def possible_word_paths
      @possible_word_paths ||= self.possible_words.map do |word|
        Path.find_paths(self.board, self.letter_values, word)
      end.flatten.compact
    end

    def duplicate_word_paths
      self.possible_word_paths.select { |path| self.possible_word_paths.count{ |p| p.word == path.word } > 1 }
    end

    def knapsack
      num_items = self.possible_word_paths.count
      matrix = Array.new(num_items) do |row|
        Array.new(self.duration + 1, 0)
      end

      num_items.times do |i|
        (self.duration + 1).times do |j|
          path = self.possible_word_paths[i]
          cost, value = path.input_time, path.value
          matrix[i][j] = if cost > j
            matrix[i - 1][j]
          else
            [
              matrix[i - 1][j],
              (matrix[i - 1][j - cost]) + value
            ].max
           end
        end
      end
      matrix
    end

    def knapsack_paths(matrix)
      i = matrix.size - 1
      current_value = matrix[0].size - 1
      marked = Array.new(matrix.size, 0)

      while i >= 0 && current_value >= 0
        if(i == 0 && matrix[i][current_value] > 0 ) || (matrix[i][current_value] != matrix[i-1][current_value])
          marked[i] = 1
          current_value -= self.possible_word_paths[i].input_time
        end
        i -= 1
      end
      paths = []
      marked.each_with_index do |el, i|
        if el > 0
          paths << self.possible_word_paths[i]
        end
      end
      paths
    end

    def inspect
      puts self.board.inspect
      puts self.letter_values.inspect
      puts '=' * 50
      possible_word_paths.each { |p| puts p.inspect }
    end

    def to_s
      self.knapsack.last.last
    end
  end
end

#puts Challenge7.solve
