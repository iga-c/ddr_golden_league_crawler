import time
import re
from selenium import webdriver
from datetime import datetime
from datetime import timedelta
from dateutil.parser import parse


class GoldenLeagueCrawler:

    def __init__(self, cookie_value, webdriver_path, binary_location='', retry_count=3):
        self.cookie_value = cookie_value
        self.webdriver_path = webdriver_path
        self.binary_location = binary_location
        self.retry_count = retry_count
        self.crawl_end = False

    def crawl(self):
        self.generate_selenium_driver()
        self.driver.get("https://p.eagate.573.jp/game/ddr/ddra20/")
        time.sleep(3)
        self.driver.add_cookie({'name': 'M573SSID', 'value': self.cookie_value})
        if not self.detail_crawl(self.retry_count):
            print("クロールに失敗しました。")
            self.driver.close()
            self.driver.quit()
            return False

        if self.start_date < self.now_datetime() <= self.end_date + timedelta(hours=1):
            self.gold_u_border, self.gold_l_border, self.time_text = self.border_crawl(self.ranking_page_url(self.league_count, 3), self.retry_count)
            self.silver_u_border, self.silver_l_border, self.time_text = self.border_crawl(self.ranking_page_url(self.league_count, 2), self.retry_count)
            self.bronze_u_border, self.bronze_l_border, self.time_text = self.border_crawl(self.ranking_page_url(self.league_count, 1), self.retry_count)
        
        self.driver.close()
        self.driver.quit()
        self.crawl_end = True
        return True

    def detail_crawl(self, retry_count):
        url = self.ranking_page_url()
        for _ in range(retry_count):
            self.driver.get(url)
            time.sleep(3)

            result = self.driver.find_elements_by_id("tournament")
            if len(result) == 0:
                continue

            self.league_count = int(re.sub(r"\D", "", result[0].text))
            dates_str = self.driver.find_elements_by_id("dates")[0].text
            self.start_date = parse(dates_str[5:21])
            self.end_date = parse(dates_str[22:])
            return True
        
        return False

    def border_crawl(self, url, retry_count):
        for i in range(retry_count):
            self.driver.get(url)
            time.sleep(3)
            idx = 0
            u_border = ""
            l_border = ""
            time_text = ""
            for td in self.driver.find_elements_by_xpath("//table[@class='table01'][2]/tbody/tr/td"):
                if idx == 0:
                    u_border = td.text
                if idx == 1:
                    l_border = td.text
                if idx == 2:
                    time_text = td.text
                idx += 1
            
            if u_border.isdecimal() or l_border.isdecimal():
                break
            
            if i == retry_count - 1:
                u_border = "取得に失敗しました。"
                l_border = "取得に失敗しました。"
        
        return u_border, l_border, time_text

    def tweet_text(self):
        if not self.crawl_end:
            return "クロールが終了していません。"

        return_text = ""
        if self.start_date == self.now_datetime():
            return "第%d回ゴールデンリーグ開始です。" % self.league_count
        if self.now_datetime() == self.end_date:
            return "第%d回ゴールデンリーグ終了です。現在集計中になります。" % self.league_count
        if self.now_datetime() == self.end_date + timedelta(hours=1):
            return_text = "第%d回ゴールデンリーグお疲れ様でした。\n最終結果\n\n" % self.league_count
        if self.start_date < self.now_datetime() < self.end_date:
            return_text = self.time_text + " 時点のボーダー:\n\n"
        if self.now_datetime() < self.start_date or self.end_date + timedelta(hours=1) < self.now_datetime():
            return ""
        
        return_text += "ゴールドクラス:\n"
        return_text += "降格ボーダー: " + self.gold_l_border + "\n\n"
        return_text += "シルバークラス:\n"
        return_text += "昇格ボーダー: " + self.silver_u_border + "\n"
        return_text += "降格ボーダー: " + self.silver_l_border + "\n\n"
        return_text += "ブロンズクラス:\n"
        return_text += "昇格ボーダー: " + self.bronze_u_border
        
        return return_text

    def generate_selenium_driver(self):
        options = webdriver.ChromeOptions()
        if not self.binary_location == '':
            options.binary_location = self.binary_location

        options.add_argument("--headless")
        options.add_argument("--disable-gpu")
        options.add_argument("--window-size=1280x1696")
        options.add_argument("--disable-application-cache")
        options.add_argument("--disable-infobars")
        options.add_argument("--no-sandbox")
        options.add_argument("--hide-scrollbars")
        options.add_argument("--enable-logging")
        options.add_argument("--log-level=0")
        options.add_argument("--v=99")
        options.add_argument("--single-process")
        options.add_argument("--ignore-certificate-errors")
        options.add_argument("--homedir=/tmp")

        self.driver = webdriver.Chrome(self.webdriver_path, options=options)

    def ranking_page_url(self, league_id=0, class_id=0):
        url = "https://p.eagate.573.jp/game/ddr/ddra20/p/ranking/index.html"
        if 0 < league_id and 0 < class_id:
            url += "?league_id=%d&class_id=%d" % league_id, class_id
        
        return url

    def now_datetime(self):
        if not hasattr(self, "now_time"):
            self.now_time = datetime(datetime.now().year, datetime.now().month, datetime.now().day, datetime.now().hour)

        return self.now_time
