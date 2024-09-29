# window_base.rb

module Windows
  class Base
    include Curses

    BORDER_WIDTH = 1
    PADDING_WIDTH = 2
    PADDING_HEIGHT = 1
    INTERNAL_PADDING = 2
    CHILD_PADDING = 1
    BORDER_SPACE = 2

    def initialize(main_window)
      @main_window = main_window
    end

    def refresh!
      @window.refresh
    end

    private

    def create_window(height, width, top, left, title='')
      window = @main_window.subwin(height, width, top, left)
      Frame.new(window, title).framed_window
    end
  end
end
