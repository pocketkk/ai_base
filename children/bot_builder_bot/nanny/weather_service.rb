#weather_service.rb

class WeatherService
  def initialize(logger)
    @logger = logger
  end

  def kelvin_to_fahrenheit(temp)
    (temp * 9 / 5 - 459.67).round(0)
  end

  def format_weather_message(json_data, n_days)
    data = json_data

    # Get current weather information
    current_weather = data['current']
    current_temp = kelvin_to_fahrenheit(current_weather['temp'])
    current_description = current_weather['weather'][0]['description']

    # Get forecast for the next N days
    forecast = data['daily'].take(n_days)

    message = "#{data['location']}\n\nCurrent Weather: #{current_temp}°F #{weather_emoji(current_description)}, #{current_description}\n\nForecast for the next #{n_days} days:\n"

    forecast.each do |day|
      date = Time.at(day['dt']).strftime('%a - %b %e')
      min_temp = kelvin_to_fahrenheit(day['temp']['min'])
      max_temp = kelvin_to_fahrenheit(day['temp']['max'])
      description = day['weather'][0]['description']
      message += "#{date}: Min #{min_temp}°F, Max #{max_temp}°F #{weather_emoji(description)}  #{description}\n"
    end

    message += "\nAlerts:\n"

    alerts = data['alerts']
    if alerts.nil? || alerts.empty?
      message += "No alerts at the moment."
    else
      alerts.each do |alert|
        sender_name = alert['sender_name']
        event = alert['event']
        start_time = Time.at(alert['start']).strftime('%Y-%m-%d %H:%M:%S')
        end_time = Time.at(alert['end']).strftime('%Y-%m-%d %H:%M:%S')
        description = alert['description']

        message += "Sender: #{sender_name}\nEvent: #{event}\nStart Time: #{start_time}\nEnd Time: #{end_time}\nDescription: #{description}\n\n"
      end
    end

    message
  end

  def weather_emoji(description)
    case description.downcase
    when 'clear sky'
      ' ☀️ '
    when 'few clouds'
      ' 🌤️ '
    when 'scattered clouds'
      ' ⛅'
    when 'broken clouds', 'overcast clouds'
      ' ☁️ '
    when 'shower rain', 'rain', 'light rain', 'moderate rain'
      ' 🌧️ '
    when 'thunderstorm'
      ' ⛈️ '
    when 'snow', 'light snow', 'light shower snow'
      ' ❄️ '
    when 'mist', 'haze', 'fog'
      ' 🌫️ '
    else
      ''
    end
  end

  def geo(location)
    # Get geocoding for location city, state from openweathermap.org
    url = URI("https://api.openweathermap.org/geo/1.0/direct?q=#{location}&limit=1&appid=#{ENV['OPEN_WEATHER_API_KEY']}")
    response = Net::HTTP.get(url)
    geo_data = JSON.parse(response)

    @logger.info("GeoService: #{geo_data}")

    unless geo_data.empty?
      lat = geo_data[0]['lat']
      long = geo_data[0]['lon']
      "The latitude and longitude for #{location} is #{lat}, #{long}."
    else
      "Unable to fetch the latitude and longitude for #{location}."
    end

    [lat, long]
  end

  def get_weather(location = 'Brush Prairie,WA,USA')
    lat, long = geo(location)

    @logger.info("WeatherService: #{lat}, #{long}")

    url = URI("https://api.openweathermap.org/data/3.0/onecall?lat=#{lat}&lon=#{long}&appid=#{ENV['OPEN_WEATHER_API_KEY']}")
    response = Net::HTTP.get(url)
    weather_data = JSON.parse(response)
    weather_data['location'] = location

    @logger.info("WeatherDataa: #{weather_data}")

    @logger.info("WeatherService: #{response}")

    unless weather_data.empty?
      format_weather_message(weather_data, 5)
    else
      "Unable to fetch the forecast for #{location}."
    end

  rescue => e
    @logger.error("WeatherService: #{e.message}")
    @logger.error(e.backtrace.join("\n"))
    raise e
  end
end
