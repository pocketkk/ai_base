# windows/chat.rb

module Windows
  class Input < Base
    attr_reader :window

    def initialize(main_window)
      super(main_window)

      @window = create_chat_subwindow
    end

    def refresh
      @window.setpos(1, 1)
      @window.refresh
    end

    private

    def create_chat_subwindow
      input_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
      input_window_height = PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH - 1
      window = @main_window.subwin(input_window_height, input_window_width, @main_window.maxy + 2 - (PADDING_HEIGHT + INTERNAL_PADDING) - 1, INTERNAL_PADDING + PADDING_WIDTH)
      window = Frame.new(window, ' INPUT ').framed_window
      window.setpos(1, 1)
      window.refresh
      window
    end
  end
end
