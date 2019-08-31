require_relative 'crawler'
require 'dotenv'

if __FILE__ == $PROGRAM_NAME
  Dotenv.load
  crawler = GoldenLeagueCrawler.new(ENV['COOKIE_VALUE'], ENV['HEADLESS_CHROME'], ENV['WEBDRIVER'], 3)
  crawler.run

  p crawler.tweet_text
end
