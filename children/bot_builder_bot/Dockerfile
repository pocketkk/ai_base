FROM ruby:3.0.2

WORKDIR /app

COPY . /app

RUN bundle install
RUN mkdir /app/logs

CMD ["ruby", "builder_bot.rb"]

VOLUME ["/app/logs"]
