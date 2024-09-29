# windows/agent.rb

module Windows
  class Main
    include Curses

    BORDER_WIDTH = 1
    PADDING_WIDTH = 2
    PADDING_HEIGHT = 1
    INTERNAL_PADDING = 2
    CHILD_PADDING = 1
    BORDER_SPACE = 2

    attr_reader :window

    def initialize
      @window = create_main_window
    end

    def refresh
      @window.refresh
    end

    private

    def create_main_window
      init_pair(1, COLOR_WHITE, COLOR_BLACK)
      main_window_width = cols - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2) - 1
      main_window_height = lines - (BORDER_WIDTH * 2) - (PADDING_WIDTH * 2)
      window = Curses::Window.new(main_window_height, main_window_width, PADDING_WIDTH, PADDING_WIDTH)
      window.attron(color_pair(1))
      Frame.new(window, '').framed_window
    end
  end
end
