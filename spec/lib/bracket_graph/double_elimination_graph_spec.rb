require 'spec_helper'

describe BracketGraph::DoubleEliminationGraph do
  it 'creates a graph composed by winner and loser graphs' do
    subject = described_class.new 8
    expect(subject.winner_graph).to be_a BracketGraph::Graph
    expect(subject.loser_graph).to be_a BracketGraph::LoserGraph
  end

  it 'creates both the sub-graphs with the same size' do
    subject = described_class.new 8
    expect(subject.winner_graph.size).to eq 8
    expect(subject.loser_graph.size).to eq 8
  end

  it 'creates a real final node' do
    subject = described_class.new 8
    expect(subject.root).to be_a BracketGraph::Seat
  end

  it 'binds both the sub-graph roots as children of the real final node' do
    subject = described_class.new 8
    expect(subject.winner_graph.root.to).to eq subject.root
    expect(subject.loser_graph.root.to).to eq subject.root
    expect(subject.root.from).to eq [subject.winner_graph.root, subject.loser_graph.root]
  end

  it 'creates the final node with doubled size as position' do
    subject = described_class.new 8
    expect(subject.root.position).to eq 16
  end

  it 'creates the final node in the last round' do
    subject = described_class.new 8
    expect(subject.root.round).to eq 6
  end

  it 'syncs the rounds of the winner bracket' do
    subject = described_class.new 16
    memo = subject.winner_graph.seats.inject(Hash.new { |h, k| h[k] = [] }) do |m, s|
      m[s.round] << s
      m
    end
    expect(memo[0].count).to eq 16
    expect(memo[1].count).to eq 8
    expect(memo[2].count).to eq 4
    expect(memo[3].count).to be_zero
    expect(memo[4].count).to eq 2
    expect(memo[5].count).to be_zero
    expect(memo[6].count).to eq 1
  end

  it 'syncs the rounds of the loser bracket' do
    subject = described_class.new 16
    memo = subject.loser_graph.seats.inject(Hash.new { |h, k| h[k] = [] }) do |m, s|
      m[s.round] << s
      m
    end
    expect(memo[0].count).to be_zero
    expect(memo[1].count).to eq 8
    expect(memo[2].count).to eq 8
    expect(memo[3].count).to eq 4
    expect(memo[4].count).to eq 4
    expect(memo[5].count).to eq 2
    expect(memo[6].count).to eq 2
    expect(memo[7].count).to eq 1
  end

  it 'after the sync the winner final is one round behind the real final' do
    subject = described_class.new 16
    expect(subject.loser_graph.root.round).to eq 7
    expect(subject.winner_graph.root.round).to eq 6
  end

  describe '#size' do
    it 'returns the right size' do
      subject = described_class.new 8
      expect(subject.size).to eq 8
    end
  end

  describe '#starting_seats' do
    it 'returns the sum of starting seats' do
      subject = described_class.new 8
      expect(subject.starting_seats).to match_array subject.winner_graph.starting_seats + subject.loser_graph.starting_seats
    end
  end

  describe '#seats' do
    it 'returns the sum of seats' do
      subject = described_class.new 8
      expect(subject.seats).to match_array [subject.root] + subject.winner_graph.seats + subject.loser_graph.seats
    end

    it 'returns the root node too' do
      subject = described_class.new 8
      expect(subject.seats).to include subject.root
    end
  end

  describe '#seed' do
    it 'delegates to the winner graph' do
      subject = described_class.new 8
      allow(subject.winner_graph).to receive(:seed).and_return 'foo'
      expect(subject.seed).to eq 'foo'
    end
  end

  it 'correctly dumps to json' do
    subject = described_class.new(4).as_json
    expect(subject).to be_a Hash
    expect(subject[:from]).to be_a Array
  end

  it 'correctly saves and restores' do
    data = Marshal::dump described_class.new(4)
    subject = Marshal::load data
    expect(subject.starting_seats.count).to eq 7
  end

  it 'assigns a loser to to each match' do
    subject = described_class.new 16
    candidates = subject.winner_seats - subject.winner_starting_seats
    expect(candidates.select(&:loser_to).count).to eq candidates.count
  end

  it 'assigns only loser starting seats in the loser relationship' do
    subject = described_class.new 16
    candidates = subject.winner_seats - subject.winner_starting_seats
    expect(candidates.map(&:loser_to)).to match_array subject.loser_starting_seats
  end

  it 'assigns each loser_to to a different seat' do
    subject = described_class.new 16
    candidates = subject.winner_seats - subject.winner_starting_seats
    expect(candidates.map(&:loser_to).uniq.count).to eq candidates.count
  end

  describe 'assigning the loser_to links' do
    let(:candidates) { (subject.winner_seats - subject.winner_starting_seats).sort_by(&:position) }

    def candidates_for_round round_index
      candidates.select { |s| s.round == round_index }.map(&:loser_to).map(&:position)
    end

    context 'when the looser_seeding_style is set to :classic' do
      subject { described_class.new 16 }

      it 'the :classic way is to use a different order based on the round oddity' do
        (1..subject.winner_root.round).each do |round|
          round_candidates_positions = candidates_for_round(round)
          if round.odd?
            expect(round_candidates_positions).to eq round_candidates_positions.sort.reverse
          else
            expect(round_candidates_positions).to eq round_candidates_positions.sort
          end
        end
      end
    end

    context 'when the looser_seeding_style is set to :swap_in_pair' do
      subject { nil }
      let(:expected_loser_positions) { nil }

      context 'with 16 teams' do
        subject { described_class.new(16, loser_seeding_style: :alternate_half_reverse) }
        let(:expected_loser_positions) do
          [
            [1, [62, 61, 60, 59, 58, 57, 56, 55]],
            [2, [50, 47, 54, 51]],
            [3, []],
            [4, [41, 39]],
            [5, []],
            [6, [35]]
          ]
        end

        it 'swap looser position in pair every round' do
          expected_loser_positions.each do |round, expected_positions|
            round_candidates_positions = candidates_for_round(round)
            expect(round_candidates_positions).to eq expected_positions
          end
        end
      end

      context 'with 32 teams' do
        subject { described_class.new(32, loser_seeding_style: :alternate_half_reverse) }
        let(:expected_loser_positions) do
          [
            [1, [118, 117, 116, 115, 114, 113, 112, 111, 126, 125, 124, 123, 122, 121, 120, 119]],
            [2, [110, 108, 105, 103, 102, 100, 97, 95]],
            [3, []],
            [4, [82, 79, 86, 83]],
            [5, []],
            [6, [73, 71]],
            [7, []],
            [8, [67]]
          ]
        end

        it 'swap looser position in pair every round' do
          expected_loser_positions.each do |round, expected_positions|
            round_candidates_positions = candidates_for_round(round)
            expect(round_candidates_positions).to eq expected_positions
          end
        end
      end
    end
  end
end
