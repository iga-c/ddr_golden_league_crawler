require 'aws-sdk-kms'
require 'base64'
require 'slack-notifier'
require 'twitter'
require_relative 'crawler'

COOKIE_VALUE = Aws::KMS::Client.new
                               .decrypt(ciphertext_blob: Base64.decode64(ENV['COOKIE_VALUE']))
                               .plaintext
WEBHOOK_URL = Aws::KMS::Client.new
                              .decrypt(ciphertext_blob: Base64.decode64(ENV['WEBHOOK_URL']))
                              .plaintext
CONSUMER_KEY = Aws::KMS::Client.new
                               .decrypt(ciphertext_blob: Base64.decode64(ENV['CONSUMER_KEY']))
                               .plaintext
CONSUMER_SECRET = Aws::KMS::Client.new
                                  .decrypt(ciphertext_blob: Base64.decode64(ENV['CONSUMER_SECRET']))
                                  .plaintext
TOKEN = Aws::KMS::Client.new
                        .decrypt(ciphertext_blob: Base64.decode64(ENV['TOKEN']))
                        .plaintext
TOKEN_SECRET = Aws::KMS::Client.new
                               .decrypt(ciphertext_blob: Base64.decode64(ENV['TOKEN_SECRET']))
                               .plaintext

def lambda_handler(event:, context:)
  crawler = GoldenLeagueCrawler.new(COOKIE_VALUE, '/opt/bin/headless-chromium', '/opt/bin/chromedriver', 3)
  crawler.run
  tweet(crawler.tweet_text) if crawler.tweet_text
rescue => e
  notifier = Slack::Notifier.new(WEBHOOK_URL)
  notifier.ping e.message
end

def tweet(tweet_text)
  @client = Twitter::REST::Client.new do |config|
    config.consumer_key        = CONSUMER_KEY
    config.consumer_secret     = CONSUMER_SECRET
    config.access_token        = TOKEN
    config.access_token_secret = TOKEN_SECRET
  end

  @client.update(tweet_text)
end
