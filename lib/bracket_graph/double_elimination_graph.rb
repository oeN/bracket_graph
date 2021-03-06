module BracketGraph
  class DoubleEliminationGraph
    attr_reader :root
    attr_reader :winner_graph, :loser_graph, :loser_seeding_style

    def initialize root_or_size, options = {}
      @loser_seeding_style = options[:loser_seeding_style] || :classic
      if root_or_size.is_a? Seat
        @root = root_or_size
        @winner_graph = Graph.new @root.from[0]
        @loser_graph = LoserGraph.new @root.from[1]
      else
        @winner_graph = Graph.new root_or_size
        @loser_graph = LoserGraph.new root_or_size
        sync_winner_rounds
        sync_loser_rounds
        build_final_seat
        assign_loser_links
      end
    end

    def [](position)
      return root if position == root.position
      if position < root.position
        winner_graph[position]
      else
        loser_graph[position]
      end
    end

    def size
      winner_graph.size
    end

    %w(winner loser).each do |type|
      define_method "#{type}_starting_seats" do
        send("#{type}_graph").starting_seats
      end

      define_method "#{type}_seats" do
        send("#{type}_graph").seats
      end

      define_method "#{type}_root" do
        send("#{type}_graph").root
      end
    end

    def seats
      [root] + winner_seats + loser_seats
    end

    def starting_seats
      winner_starting_seats + loser_starting_seats
    end

    def seed *args
      winner_graph.seed *args
    end

    def as_json options={}
      @root.as_json options
    end

    private

    def build_final_seat
      @root = Seat.new size * 2, round: loser_graph.root.round + 1
      @root.from.concat [winner_graph.root, loser_graph.root]
      @root.from.each { |s| s.to = @root }
    end

    def sync_winner_rounds
      seats_by_round = winner_seats.inject({}) do |memo, seat|
        memo[seat.round] ||= []
        memo[seat.round] << seat
        memo
      end
      3.upto(winner_root.round) do |round|
        seats_by_round[round].each do |r|
          r.instance_variable_set '@round', 2 + (round - 2) * 2
        end
      end
    end

    def sync_loser_rounds
      loser_graph.seats.each do |s|
        s.instance_variable_set '@round', s.round + 1
      end
    end

    def winner_matches_by_round
      winner_graph.seats.
        reject(&:starting?).
        sort_by(&:position).
        inject({}) do |memo, seat|
          memo[seat.round] ||= []
          memo[seat.round] << seat
          memo
        end
    end

    def loser_starting_seats_by_round
      loser_graph.starting_seats.sort_by(&:position).inject({}) do |memo, seat|
        memo[seat.round] ||= []
        memo[seat.round] << seat
        memo
      end
    end

    def assign_loser_links
      winner_matches = winner_matches_by_round
      loser_candidates = loser_starting_seats_by_round
      winner_matches.each do |round, matches|
        candidates = reorder_loser_candidates(loser_candidates[round], round)
        matches.each do |match|
          match.loser_to = candidates.pop
        end
      end
    end

    def reorder_loser_candidates candidates, round
      if alternate_half_reverse?
        power = Math.log2(candidates.size).ceil
        half = candidates.size / 2
        return candidates if power.odd? || half.zero?
        return candidates.each_slice(half).map(&:reverse).flatten.reverse
      end

      return candidates.reverse if round.even?
      candidates
    end

    def alternate_half_reverse?
      loser_seeding_style == :alternate_half_reverse
    end
  end
end
