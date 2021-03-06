require File.expand_path(File.dirname(__FILE__) + '/neo')
require_relative('about_scoring_project.rb')
require 'set'
# EXTRA CREDIT:
#
# Create a program that will play the Greed Game.
# Rules for the game are in GREED_RULES.TXT.
#
# You already have a DiceSet class and score function you can use.
# Write a player class and a Game class to complete the project.  This
# is a free form assignment, so approach it however you desire.
#

class Hash
  def as_dice_array
    puts self.inspect
    map { |k, v| (v % 3).times.map { k } }.flatten.sort
  end
end

class Greed
  class InteractiveGame
    class << self
      def run(gamestate = Greed::Game.start)
      end
    end
  end

  class Game
    attr_reader :players, :current_player_turn, :previous_game_state, :finished, :rounds

    def initialize(players,current_player_turn = 0,previous_game_state = nil, finished = false, rounds = 10)
      @players = players
      @current_player_turn = current_player_turn
      @previous_game_state = previous_game_state
      @finished = finished
      @rounds = rounds

      puts "initialize: #{@current_player_turn} #{@previous_game_state} #{@finished} #{@rounds}"
    end

    def previous_roll
      if ( current_player.current_roll_depth < 2 ) then
        previous_player.last_diceset
      else
        current_player.previous_diceset
      end
    end

    def current_player
      @players[@current_player_turn]
    end

    def last_roll
      "Previous Roll: #{previous_roll.nil? ? '' : previous_roll.pretty}"
    end

    def pretty
      "#{last_roll}\n#{current_player.pretty}\n#{game_score_string}\n"
    end

    def game_score_string
      players.keys.sort.map { |x| "Player #{x} score: #{@players[x].score}\n" }.join
    end

    def start_turn
      puts 'start_turn'
      update_game_state(current_player.start_turn)
    end

    def finish_turn
      puts 'finish_turn'
      update_game_state(current_player.finish)
    end

    # Find a way to make this force us into the next game state...
    def roll
      puts 'roll'
      update_game_state(current_player.roll).roll_check
    end

    def prepare_player
      puts "prepare_player: #{@current_player_turn}"
      update_game_state(current_player.start_turn,true)
    end

    def num_players
      players.keys.length
    end

    def current_player_stop?
      current_player.finished or current_player.failed?
    end

    def should_finish?
      @current_player_turn == num_players - 1 and current_player_stop? and current_player.turn_depth >= @rounds
    end

    def update_game_state(player,prevent_increment = false)
      unless @finished
        Greed::Game.new(
          players.merge({ @current_player_turn => player }),
          (@current_player_turn + ((current_player_stop? and not prevent_increment and not should_finish?) ? 1 : 0 )) % num_players,
          self,
          should_finish?,
          @rounds)
      else
        self
      end
    end

    def previous_player
      players[previous_player_number]
    end

    def previous_player_number
      current_player_turn == 0 ? players.keys.length - 1 : current_player_turn - 1
    end

    def roll_check
      if current_player.failed? and not @finished then
        finish_turn.prepare_player.roll_check
      else
        self
      end
    end

    class << self
      def start(number_players)
        Greed::Game.new(Hash[ (0 .. number_players - 1).map { |x| [ x , Greed::Player.new(nil,false,x) ] } ])
      end
    end
  end

  class Player
    attr_reader :turn, :finished, :number, :failed

    def initialize(turn = nil, finished = false, number = 0)
      @turn = turn
      @number = number
      @finished = finished
      @failed = turn.nil? ? false : !turn.can_reroll?
    end

    def failed?
      @failed
    end

    def turn_depth
      @turn.nil? ? 0 : @turn.depth
    end

    def current_roll_depth
      @turn.nil? ? 0 : @turn.roll_depth
    end

    def last_diceset
      @turn.nil? ? nil : @turn.diceset
    end

    def previous_diceset
      @turn.nil? ? nil : @turn.previous_diceset
    end

    def pretty
      "Player #{@number}: #{@turn.nil? ? '' : @turn.pretty}"
    end

    def score
      @turn.nil? ? 0 : @turn.accumulated_score
    end

    # TODO make roll, finish and start_turn work together better.
    def start_turn
      Greed::Player.new(Greed::Turn.new(Greed::DiceSet.roll,@turn),false,@number)
    end

    def turn_finished?
      @finished
    end

    def turn_started?
      @turn.nil?
    end

    def roll
      turn_started? ? start_turn : Greed::Player.new(@turn.roll,false,@number)
    end

    def finish
      Greed::Player.new(@turn,true,@number)
    end
  end

  class Turn
    attr_reader :diceset, :previous_turn, :finished

    def initialize(diceset, previous_turn = nil, finished = false)
      @diceset = diceset
      @previous_turn = previous_turn
      @finished = finished
    end

    def roll_depth
      @diceset.nil? ? 0 : @diceset.depth
    end

    def finish
      Greed::Turn.new(@diceset, @previous_turn, true) unless @finished
    end

    def previous_diceset
      @diceset.nil? ? nil : @diceset.previous_diceset
    end

    def score
      @diceset.accumulated_score
    end

    def depth(acc = 1)
      unless @previous_turn
        acc
      else
        @previous_turn.depth(acc + 1)
      end
    end

    def pretty
      "Turn #{depth}: Roll #{roll_depth}: #{@diceset.pretty}"
    end

    def accumulated_score
      score + ( @previous_turn.nil? ? 0 : @previous_turn.accumulated_score )
    end

    def can_reroll?
      @diceset.can_reroll? and not @finished
    end

    def roll
      if can_reroll? then
        Turn.new(@diceset.reroll, @previous_turn)
      else
        raise IllegalRollError
      end
    end

    class << self
      def start(previous_turn = nil)
        Greed::Turn.new(Greed::DiceSet.roll)
      end
    end
  end

  class DiceSet
    attr_reader :values, :previous_diceset

    def initialize(values, previous_diceset=Greed::NullDiceSet.new)
      @values = values 
      @previous_diceset = previous_diceset
    end

    def score
      @values.score
    end

    def depth(acc = 1)
      previous_diceset.depth(acc + 1)
    end

    def accumulated_score
      Greed::DiceSet.accumulated_score(0,self)
    end

    def nonscoring_dice
      @values.grouped_roll.
          keep_if { |k, v| (not [1, 5].include?(k)) and (v % 3) > 0 }.
          map { |k, v| (v % 3).times.map { k } }.flatten.sort
    end

    def pretty
      "DiceSet: " + @values.sort.join(", ")
    end

    def reroll
      if not can_reroll? then
        raise IllegalRollError
      else
        Greed::DiceSet.new(
          if not has_nonscoring_dice? then
            Greed::DiceSet.roll_array(5)
          else
            scoring_dice + Greed::DiceSet.roll_array(5 - scoring_dice.length)
          end, self
        )
      end
    end

    def scoring_dice
      @values.grouped_roll.
          keep_if { |k, v| [1, 5].include?(k) or v >= 3 }.
          map do |k, v|
            if [ 1, 5 ].include?(k) then
              v.times.map { k }
            else
              3.times.map { k }
            end
          end.flatten.sort
    end

    def has_scoring_dice?
      scoring_dice.length > 0
    end

    def has_nonscoring_dice?
      nonscoring_dice.length > 0
    end

    def can_reroll?
      has_scoring_dice? and 
        ( scoring_dice.length > previous_diceset.scoring_dice.length or not previous_diceset.has_nonscoring_dice? )
    end

    class << self
      def roll
        Greed::DiceSet.new(roll_array(5))
      end

      def roll_array(size)
        size.times.map { |x| 1 + rand(6) }
      end

      def accumulated_score(acc, current, start = true)
        if current.nil? then
          acc
        elsif not current.can_reroll? then
          0
        else
          accumulated_score ((start or not current.has_nonscoring_dice?)? current.score : 0) + acc, current.previous_diceset, false
        end
      end
    end
  end

  class NullDiceSet < DiceSet

    # Allow null initialization.
    def initialize
      @values = nil
      @previous_diceset = nil
    end

    def nil?
      true
    end

    def score
      0
    end

    def pretty
      ''
    end

    def can_reroll?
      true
    end

    def scoring_dice
      [ ]
    end

    def nonscoring_dice
      [ ]
    end

    def has_scoring_dice?
      false
    end

    def has_nonscoring_dice?
      false
    end

    def depth(acc = 0)
      acc
    end
  end

  class IllegalRollError < ::StandardError
  end
end

class AboutGreedAssignment < Neo::Koan
  def test_dice_set_creation
    assert_equal [ 1 ], Greed::DiceSet.new([ 1 ]).values
    assert_equal [ ],Greed::DiceSet.new([ ]).values
    assert_equal 5, Greed::DiceSet.roll.values.length
    assert_equal true, Greed::DiceSet.roll.values != Greed::DiceSet.roll.values
    assert_equal true, Greed::DiceSet.roll.is_a?(Greed::DiceSet)
  end

  def test_do_dice_score_already
    assert_equal 1200,Greed::DiceSet.new(5.times.map { 1 }).score
  end

  def test_find_nonscoring_dice
    assert_equal [ ],Greed::DiceSet.new(5.times.map { 1 }).nonscoring_dice
    assert_equal [ ],Greed::DiceSet.new(5.times.map { 5 }).nonscoring_dice
    [2, 3, 4, 6].each do |x|
      assert_equal [ x, x ],
          Greed::DiceSet.new(5.times.map { x }).
            nonscoring_dice
    end
    assert_equal [ 2, 2 ],Greed::DiceSet.new([ 1, 1, 1, 2, 2]).nonscoring_dice
    assert_equal [ 2, 2 ],Greed::DiceSet.new([ 3, 3, 3, 2, 2]).nonscoring_dice
    assert_equal [ 2, 2, 3, 3, 4 ],Greed::DiceSet.new([ 2, 2, 3, 3, 4 ]).nonscoring_dice
    assert_equal [ 2, 4 ],Greed::DiceSet.new([ 2, 3, 3, 3, 4 ]).nonscoring_dice
  end

  def test_find_scoring_dice
    assert_equal 5.times.map{ 1 },Greed::DiceSet.new(5.times.map { 1 }).scoring_dice
    assert_equal 5.times.map{ 5 },Greed::DiceSet.new(5.times.map { 5 }).scoring_dice
    assert_equal [2, 2, 2],Greed::DiceSet.new([2, 2, 2, 3, 3]).scoring_dice
    [2, 3, 4, 6].each do |x|
      assert_equal [ x, x, x ],
          Greed::DiceSet.new(5.times.map { x }).
            scoring_dice
    end
  end

  def test_has_scoring_dice?
    assert_equal true,Greed::DiceSet.new([1, 2, 2, 3, 3]).has_scoring_dice?
    assert_equal false,Greed::DiceSet.new([4, 2, 2, 3, 3]).has_scoring_dice?
    assert_equal true,Greed::DiceSet.new([5, 2, 2, 3, 3]).has_scoring_dice?
    assert_equal true,Greed::DiceSet.new([2, 2, 2, 3, 3]).has_scoring_dice?
  end

  def test_reroll_dice

    def check_reroll_values(diceset,previous_diceset,depth = 100)
      return unless depth > 0
      unless previous_diceset.nil? then
        diceset.scoring_dice.grouped_roll.each do |k, v|
          assert_equal true, diceset.scoring_dice.grouped_roll[k] >= ( previous_diceset.scoring_dice.grouped_roll[k] || 0 )
          assert_equal previous_diceset, diceset.previous_diceset
        end
      end
      if not diceset.can_reroll? then
        check_reroll_values(Greed::DiceSet.roll,nil,depth - 1)
      elsif diceset.scoring_dice.length == 5 then
        check_reroll_values(diceset.reroll,nil,depth - 1)
      else
        check_reroll_values(diceset.reroll,diceset,depth - 1)
      end
    end

    check_reroll_values(Greed::DiceSet.roll,nil)
  end

  def test_accumulated_score
    diceset_item = Greed::DiceSet.new([1, 1, 1, 1, 1])
    assert_equal 1200, diceset_item.accumulated_score
    diceset_item = Greed::DiceSet.new([1, 1, 1, 1, 1],diceset_item)
    assert_equal 2400, diceset_item.accumulated_score
    diceset_item = Greed::DiceSet.new([2, 2, 5, 5, 3],diceset_item)
    assert_equal 2500, diceset_item.accumulated_score
    diceset_item = Greed::DiceSet.new([5, 5, 1, 2, 3],diceset_item)
    assert_equal 2600, diceset_item.accumulated_score
    diceset_item = Greed::DiceSet.new([5, 5, 1, 1, 1],diceset_item)
    assert_equal 3500, diceset_item.accumulated_score
    diceset_item = Greed::DiceSet.new([2, 2, 3, 3, 6],diceset_item)
    assert_equal 0, diceset_item.accumulated_score
  end

  def test_turn_rolling
    def turn_rolling(turn,previous_turn = nil,depth = 100)
      return unless depth > 0
      if ( turn.nil? )
        turn_rolling(Greed::Turn.start,nil,depth - 1)
      else
        if ( previous_turn )
          assert_equal true, previous_turn != turn
        end
        assert_equal turn.score, turn.diceset.accumulated_score
        assert_equal turn.can_reroll?, turn.diceset.can_reroll?
        if turn.can_reroll? then
          assert_equal true, turn.score > 0
          turn_rolling(turn.roll,turn,depth - 1)
        else
          assert_equal true, turn.score == 0
          turn_rolling(Greed::Turn.start,nil,depth - 1)
        end
      end
    end

    turn_rolling(Greed::Turn.start)

    (1 .. 5).each.map { Greed::Turn.new(Greed::DiceSet.roll,nil,true) }.each do |turn|
      assert_equal true, turn.finished
      assert_equal false, turn.can_reroll?
    end

    assert_equal 1100 + 500, Greed::Turn.new(Greed::DiceSet.new([1, 1, 1, 5, 5]),Greed::Turn.new(Greed::DiceSet.new([5, 5, 5, 2, 2]))).accumulated_score
  end

  def test_basic_player
    player = Greed::Player.new

    assert_equal nil, player.turn
    assert_equal false, player.finished
    assert_equal 0, player.number

    # The code is functional, this part is not, so I'm going to have to
    # do this.
    player = player.start_turn
    score = player.turn.diceset.score
    assert_equal score, player.score

    player = player.finish
    player = player.start_turn

    score += player.turn.diceset.score
    assert_equal score, player.score
  end

  def test_basic_game
    game = Greed::Game.start(3)
    def roll_output(game,depth)
      puts game.pretty
      return if game.finished
      roll_output(game.roll,depth - 1) if depth > 0
    end

    roll_output(game,100)
  end
end
