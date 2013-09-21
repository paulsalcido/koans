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
#
class Hash
  def as_dice_array
    puts self.inspect
    map { |k, v| (v % 3).times.map { k } }.flatten.sort
  end
end

class Greed
  class DiceSet
    attr_reader :values

    def initialize(values)
      @values = values 
    end

    def score
      @values.score
    end

    def nonscoring_dice
      @values.grouped_roll.
          keep_if { |k, v| (not [1, 5].include?(k)) and (v % 3) > 0 }.
          map { |k, v| (v % 3).times.map { k } }.flatten.sort
    end

    def reroll
      if not has_scoring_dice then
        raise IllegalRollError
      else
        Greed::DiceSet.new(
          if not has_nonscoring_dice then
            Greed::DiceSet.roll_array(5)
          else
            scoring_dice + Greed::DiceSet.roll_array(5 - scoring_dice.length)
          end
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

    def has_scoring_dice
      scoring_dice.length > 0
    end

    def has_nonscoring_dice
      nonscoring_dice.length > 0
    end

    class << self
      def roll
        Greed::DiceSet.new(roll_array(5))
      end

      def roll_array(size)
        size.times.map { |x| 1 + rand(6) }
      end
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

  def test_has_scoring_dice
    assert_equal true,Greed::DiceSet.new([1, 2, 2, 3, 3]).has_scoring_dice
    assert_equal false,Greed::DiceSet.new([4, 2, 2, 3, 3]).has_scoring_dice
    assert_equal true,Greed::DiceSet.new([5, 2, 2, 3, 3]).has_scoring_dice
    assert_equal true,Greed::DiceSet.new([2, 2, 2, 3, 3]).has_scoring_dice
  end

  def test_reroll_dice
    def check_reroll_values(diceset,previous_diceset,depth)
      unless previous_diceset.nil? then
        diceset.scoring_dice.grouped_roll.each do |k, v|
          assert_equal true, diceset.scoring_dice.grouped_roll[k] >= ( previous_diceset.scoring_dice.grouped_roll[k] || 0 )
        end
      end
      return unless depth > 0
      if diceset.scoring_dice.length == 0 then
        check_reroll_values(Greed::DiceSet.roll,nil,depth - 1)
      elsif diceset.scoring_dice.length == 5 then
        check_reroll_values(diceset.reroll,nil,depth - 1)
      else
        check_reroll_values(diceset.reroll,diceset,depth - 1)
      end
    end

    check_reroll_values(Greed::DiceSet.roll,nil,100)
  end
end
