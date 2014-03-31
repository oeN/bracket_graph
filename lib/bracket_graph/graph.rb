module BracketGraph
  class Graph
    attr_reader :root

    def initialize size
      raise ArgumentError, 'the given size is not a power of 2' if Math.log2(size) % 1 != 0
      build_tree size
    end

    private

    def build_tree size
      @root = Seat.new
      current_nodes = [@root]
      while current_nodes.size < size
        current_nodes = current_nodes.inject([]) do |memo, current_node|
          memo.concat current_node.build_input_match.build_input_seats
        end
      end
    end
  end
end
