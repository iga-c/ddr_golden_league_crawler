import twitter
import yaml
import sys
from crawler import GoldenLeagueCrawler


if __name__ == "__main__":
    f = open("config.yml", "r+")
    data = yaml.safe_load(f)
    crawler = GoldenLeagueCrawler(data["cookie_value"], data["webdriver_path"], '' if data["binary_location"] is None else data["binary_location"], data["retry_count"])
    if not crawler.crawl():
        print("クロールに失敗しました。")
        sys.exit()

    tweet_text = crawler.tweet_text()
    if tweet_text == "":
        sys.exit()
    
    auth = twitter.OAuth(consumer_key=data["consumer_key"],
                     consumer_secret=data["consumer_secret"],
                     token=data["token"],
                     token_secret=data["token_secret"])

    t = twitter.Twitter(auth=auth)
    t.statuses.update(status=crawler.tweet_text())
