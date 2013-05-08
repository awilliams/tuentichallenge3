I tried solving this problem using [A* search](http://en.wikipedia.org/wiki/A*_search_algorithm)

It basically boiled down to this method which I'll explain below
````ruby
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
````

First, create an initial Path starting and ending at the given start point
````ruby
initial_path = Path.new(self.board, [self.start_position], 0.0, self.new_position_cost, self.movement_cost)
````

Next, initialize an array which will contain all the explored paths *@open_paths*. The *Path#unexplored_paths* method returns an array of Path instances expanded one cell in every possible direction (possible means not expanding into any obstacles and not backtracking, which is a legal but never optimal move). 
````ruby
@open_paths = initial_path.unexplored_paths
````

Next, enter into a loop which terminates when any of the @open_paths has reached the exit.
````ruby
until @open_paths.any? { |path| path.position == self.exit_position }
````

For each iteration, determine the minimum heuristic value of all the paths. 
````ruby
min_value = @open_paths.map(&:heuristic_value).min
````
Path#heuristic_value is defined below. It's the value of the path plus a heuristic value being the distance to the exit (ignoring any obstacles) plus a constant (which could be removed i believe). Path#value increasing with every movement, as seen in Path#add_position
````ruby
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
````

Next, expand all paths which have the minimum heuristic value. This part is somewhat contrived in the code, but I'm leaving it the way I submitted
````ruby
min_value_paths = @open_paths.select { |path| path.heuristic_value == min_value }
@open_paths -= min_value_paths
@open_paths += min_value_paths.map { |path| path.unexplored_paths }.flatten
````

Once the loop exists, selected from the paths those which have reached the exit, then select the one(s) with the least value.
````ruby
@open_paths.select{ |path| path.position == self.exit_position}.min_by { |path| path.value }
````