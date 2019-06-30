import twitter
import yaml
from crawler import GoldenLeagueCrawler


if __name__ == "__main__":
    f = open("config.yml", "r+")
    data = yaml.safe_load(f)
    crawler = GoldenLeagueCrawler(data["cookie_value"], data["webdriver_path"], '' if data["binary_location"] is None else data["binary_location"])
    crawler.crawl()
    
    auth = twitter.OAuth(consumer_key=data["consumer_key"],
                     consumer_secret=data["consumer_secret"],
                     token=data["token"],
                     token_secret=data["token_secret"])

    t = twitter.Twitter(auth=auth)
    t.statuses.update(status=crawler.tweet_text())
