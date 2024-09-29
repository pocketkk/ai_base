FROM ruby:2.7

# Install the necessary dependencies
RUN apt-get update -qq && apt-get install -y \
    libncurses5-dev \
    libncursesw5-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app directory (here we're naming it "app")
RUN mkdir /app

# Set the working directory to /app
WORKDIR /app

COPY Gemfile ./

# Install any needed packages specified in Gemfile
RUN bundle install

# Copy the rest of your app's source code from your host to your image filesystem.
COPY . .

# Define the script we want run once the container boots
CMD ["ruby", "mother.rb"]
