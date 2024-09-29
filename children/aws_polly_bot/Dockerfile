# Dockerfile

FROM ruby:3.0.2

RUN apt-get update -y && \
    apt-get install -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

RUN bundle install
RUN mkdir /app/logs
RUN mkdir /app/audio_out

CMD ["ruby", "aws_polly_bot.rb"]

VOLUME [ "/app/logs" ]
VOLUME [ "/app/audio_out" ]
