# windows/chat.rb

module Windows
  class Chat < Base
    attr_reader :window

    def initialize(main_window, agents_subwindow)
      super(main_window)

      @offset = 0
      @agents_subwindow = agents_subwindow
      @window = create_chat_subwindow
    end

    def refresh
      @window.refresh
    end

    private

    def create_chat_subwindow
      chat_window_width = @main_window.maxx - (INTERNAL_PADDING * BORDER_SPACE)
      chat_window_height = @main_window.maxy - @agents_subwindow.maxy - (PADDING_HEIGHT + INTERNAL_PADDING + BORDER_WIDTH) * 2 + 3
      window = @main_window.subwin(chat_window_height, chat_window_width, @agents_subwindow.maxy - 1 + PADDING_HEIGHT * 2 + INTERNAL_PADDING, INTERNAL_PADDING + PADDING_WIDTH)
      Frame.new(window, ' CHAT ').framed_window
    end
  end
end
