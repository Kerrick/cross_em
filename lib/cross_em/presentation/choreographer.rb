# frozen_string_literal: true

module CrossEm
  module Presentation
    # Turns a Game's events into Motion for the Play screen: each change
    # is shown arriving from where it came from, measured on the screen as
    # it was, and after every move the board is framed again, keeping the
    # letter just placed in view. It remembers which slot is lifted and
    # the order letters were placed, which the rules need not know.
    class Choreographer
      def initialize(play, game, motion)
        @play, @game, @motion = play, game, motion
        @lifted_slot = nil
        @placed = []
        game.subscribe { call(it) }
      end

      # The letter placed last that is still on the board.
      def last_placed = @placed.reverse.find { @game.board.occupied?(it) }

      def call(event)
        case event
        when Events::Selected then selected(event.index)
        when Events::Deselected then deselected(event.index)
        when Events::Placed then placed(event)
        when Events::Returned then returned([event])
        when Events::Reset then returned(event.returns)
        when Events::Shuffled then shuffled(event.order)
        when Events::Checked then @motion.checked(@game.board.bounds, event.check.problems.keys)
        when Events::Won, Events::Lost then ended(event)
        end
      end

      private

      def selected(index)
        @motion.selected(index, @lifted_slot)
        @lifted_slot = index
      end

      def deselected(index)
        @motion.lowered(index)
        @lifted_slot = nil
      end

      def placed(event)
        @placed << event.position
        slot = @play.layout.pool[event.index]
        lift = @play.units.px(Look::METRICS.lift) * @motion.lift(event.index)
        @motion.left(event.index)
        @lifted_slot = nil
        @motion.fly([:cell, event.position], slot.offset(0, -lift.round), :place)
        @play.refit(focus: event.position)
      end

      def returned(returns)
        view = @play.shown_view
        from = returns.to_h { [it.index, view.tile_rect(it.position)] }
        @lifted_slot = nil
        @play.refit
        returns.each_with_index do |back, i|
          @motion.fly([:slot, back.index], from[back.index], :return, delay: i * Motion::STAGGER)
        end
      end

      def shuffled(order)
        @lifted_slot = @game.selected
        @motion.moved_lift(@game.selected)
        order.each_with_index do |old, new|
          @motion.fly([:slot, new], @play.layout.pool[old], :shuffle) if @game.pool.letter?(new) && old != new
        end
      end

      def ended(event)
        @lifted_slot = nil
        event.is_a?(Events::Won) ? @motion.won(@game.board.bounds) : @motion.lost
      end
    end
  end
end
