require 'selenium-webdriver'

class GoldenLeagueCrawler
  SELENIUM_OPTIONS = %w[--headless --disable-gpu --disable-extensions --disable-dev-shm-usage --window-size=1280x1696
                        --disable-application-cache --disable-infobars --no-sandbox --hide-scrollbars --single-process
                        --ignore-certificate-errors --homedir=/tmp].freeze

  def initialize(konami_cookie_str, webdriver_path, binary_location, retry_count)
    @konami_cookie_str = konami_cookie_str
    @webdriver_path = webdriver_path
    @binary_location = binary_location
    @retry_count = retry_count

    generate_selenium_driver
  end

  def crawl(url)
    count = 0

    begin
      sleep 2
      @driver.get(url)
    rescue
      count += 1 if count <= @retry_count
      retry if count <= @retry_count
    end

    count <= @retry_count
  end

  def run
    set_konami_cookie
  end

  # DDRのWebページにアクセスし、コナミアカウントのcookieを設定する。
  def set_konami_cookie
    raise 'DDRのWebページに接続失敗しました。' unless crawl(ddr_page_url)
    @driver.manage.add_cookie('name': 'M573SSID', 'value': @konami_cookie_str)
  end

  # DDRのゴールデンリーグのページのURLを返す。
  # league_idで指定したリーグとclass_idで指定したクラス(gold:3, silver:2, bronze:1)のページのURLを返す。
  # 指定しない場合は最新のリーグの所属リーグのページのURLを返す。
  #
  # @param [Integer] league_id 何回目のリーグかを示すリーグID
  # @param [Integer] class_id クラス毎に指定されている値(gold:3, silver:2, bronze:1)
  # @return [String] ゴールデンリーグのページのURL
  def ranking_page_url(league_id = -1, class_id = -1)
    url = "#{ddr_page_url}/ranking/index.html"
    url + (0 <= league_id && 0 <= class_id ? "?league_id=#{league_id}&class_id=#{class_id}" : '')
  end

  def ddr_page_url
    'https://p.eagate.573.jp/game/ddr/ddra20/p'
  end

  def generate_selenium_driver
    Selenium::WebDriver::Chrome::Service.driver_path = @webdriver_path
    options = Selenium::WebDriver::Chrome::Options.new(binary: @binary_location)

    SELENIUM_OPTIONS.each { |option| options.add_argument(option) }
    @driver = Selenium::WebDriver.for :chrome, options: options
  end
end
