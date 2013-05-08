### I solved this challenge by breaking up the problem into 3 sub-problems...

#### 1: Given all the letters available on the board, find all the words in the dictionary which could be created using those letters (ignoring whether a valid path actually exists on the board).

I created a dictionary object which parsed the dictionary file and then stored, for each word, the frequency of each letter of that word.

For example, the word 'UNRISEN' is stored as: 

````ruby
Challenge7::DICTIONARY.fetch 'UNRISEN'
 => {:U=>1, :N=>2, :R=>1, :I=>1, :S=>1, :E=>1}`
````

Here is the complete Dictionary class:
````ruby
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
````

Next, I enumerated through all the words in the dictionary. For each letter of each word, I checked if the board contained at least its frequency. If it did, I considered the word a possible valid word for the board.

Listing possible valid words:
````ruby
@possible_words = []
DICTIONARY.each_with_index do |word, index|
  if index.all? { |char, count| self.board.fetch_char_index(char) >= count }
    @possible_words << word
  end
end
````

#### 2: Given this set of possible words, find all the valid word paths on the board.

I created a Path class, which given a word and board, created all possible paths (being sure not to repeat cells). A *Path* instance contained the cells used to create the word, and the score and input time. Here is the *redacted* Path class, with the path finding code left in.

````ruby
class Path
  # returns array of Path instances for given word
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
end
````

Next, I took the list of possible word, and created an array of valid word paths.
````ruby
@possible_word_paths ||= self.possible_words.map do |word|
  Path.find_paths(self.board, self.letter_values, word)
end.flatten.compact
```

#### 3: Given this set of possible word paths, find the combination of paths which maximizes score yet remains under or at the allowed time.

This problem is the [0-1 Knapsack problem](http://en.wikipedia.org/wiki/Knapsack_problem), which I solved using the following method:

````ruby
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
  matrix # matrix.last.last returns the max score possible
end
````

I'm not sure what would have happened if there had been words with multiple paths of varying value/input time. 