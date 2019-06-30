import time
from selenium import webdriver


class GoldenLeagueCrawler:

    def __init__(self, cookie_value, webdriver_path, binary_location=''):
        self.cookie_value = cookie_value
        self.webdriver_path = webdriver_path
        self.binary_location = binary_location

    def crawl(self):
        self.generate_selenium_driver()
        self.driver.get("https://p.eagate.573.jp/game/ddr/ddra20/")
        time.sleep(3)
        self.driver.add_cookie({'name': 'M573SSID', 'value': self.cookie_value})
        self.gold_u_border, self.gold_l_border, self.time_text = self.border_crawl("https://p.eagate.573.jp/game/ddr/ddra20/p/ranking/index.html?league_id=3&class_id=3")
        self.silver_u_border, self.silver_l_border, self.time_text = self.border_crawl("https://p.eagate.573.jp/game/ddr/ddra20/p/ranking/index.html?league_id=3&class_id=2")
        self.bronze_u_border, self.bronze_l_border, self.time_text = self.border_crawl("https://p.eagate.573.jp/game/ddr/ddra20/p/ranking/index.html?league_id=3&class_id=1")

    def border_crawl(self, url):
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
        
        return u_border, l_border, time_text

    def tweet_text(self):
        return_text = self.time_text + " 時点のボーダー:\n\n"
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
