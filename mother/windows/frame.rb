# frozen_string_literal: true

class Frame
  include Curses

  LEFT_TOP_CORNER = '┌'
  RIGHT_TOP_CORNER = '┐'
  LEFT_BOTTOM_CORNER = '└'
  RIGHT_BOTTOM_CORNER = '┘'
  HORIZONTAL_LINE = '─'
  VERTICAL_LINE = '│'

  BORDER_SPACE = 2

  attr_reader :window, :title

  def initialize(window, title)
    @window = window
    @title = title
  end

  def framed_window
    draw_horizontal_borders
    draw_vertical_borders
    window.attrset(A_NORMAL)
    window
  end

  private

  def dashes_count
    ((window.maxx - 2 - title.length) / 2)
  end

  def offset_count
    title.bytesize.odd? ? 1 : 0
  end

  def draw_horizontal_borders
    window.addstr(LEFT_TOP_CORNER + HORIZONTAL_LINE * dashes_count.floor + title + HORIZONTAL_LINE * (dashes_count.ceil + offset_count) + RIGHT_TOP_CORNER)
    window.setpos(window.maxy - 1, 0)
    window.addstr(LEFT_BOTTOM_CORNER + HORIZONTAL_LINE * (window.maxx - BORDER_SPACE) + RIGHT_BOTTOM_CORNER)
  end

  def draw_vertical_borders
    (1..window.maxy - BORDER_SPACE).each do |row|
      window.setpos(row, 0)
      window.addstr(VERTICAL_LINE)
      window.setpos(row, window.maxx - 1)
      window.addstr(VERTICAL_LINE)
    end
  end
end
