require 'date'
require 'selenium-webdriver'

class GoldenLeagueCrawler
  SELENIUM_OPTIONS = %w[--headless --disable-gpu --disable-extensions --disable-dev-shm-usage --window-size=1280x1696
                        --disable-application-cache --disable-infobars --no-sandbox --hide-scrollbars --single-process
                        --ignore-certificate-errors --homedir=/tmp].freeze

  # コンストラクタ
  # @param [String] konami_cookie_str KONAMIのWebページで使用しているM573SSIDに対応するcookieの値
  # @param [String] chromium_path 使用するHeadless-ChromiumのPATH
  # @param [String] webdriver_path 使用するHeadless-Chromiumに対応しているWebDriverのPATH
  # @param [Integer] retry_count クロール失敗時にリトライする回数
  def initialize(konami_cookie_str, chromium_path, webdriver_path, retry_count)
    @konami_cookie_str = konami_cookie_str
    @chromium_path = chromium_path
    @webdriver_path = webdriver_path
    @retry_count = retry_count

    generate_selenium_driver
  end

  # 必要な箇所までのクロール処理を行う。
  def run
    set_konami_cookie
    raise 'ゴールデンリーグのページに接続失敗しました。' unless crawl(ranking_page_url)

    return true unless now? || result_now?

    gold_class_crawl
    silver_class_crawl
    bronze_class_crawl
    @last_update = last_update
    @driver.quit
  end

  # クロール結果を元にツイート内容を返す。
  # @return [String] ツイート内容
  # @return [nil] ゴールデンリーグ開催期間外
  def tweet_text
    return start_now_tweet if start_now?

    return now_tweet if now?

    return end_now_tweet if end_now?

    return result_now_tweet if result_now?

    nil
  end

  private

  # urlのページをクロールする。
  # @param [String] url クロール対象のURL
  # @return [Boolean] クロール成功した場合はtrue, 失敗した場合はfalse
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

  # DDRのWebページにアクセスし、コナミアカウントのcookieを設定する。
  def set_konami_cookie
    raise 'DDRのWebページに接続失敗しました。' unless crawl(ddr_page_url)

    @driver.manage.add_cookie('name': 'M573SSID', 'value': @konami_cookie_str)
  end

  # ゴールドクラスの降格ボーダーをクロールしインスタンス変数に保存する。
  def gold_class_crawl
    raise 'ゴールドクラスのページに接続失敗しました。' unless crawl(ranking_page_url(league_count, 3))

    @gold_lower = lower_border
  end

  # シルバークラスの昇格/降格ボーダーをクロールしインスタンス変数に保存する。
  def silver_class_crawl
    raise 'シルバークラスのページに接続失敗しました。' unless crawl(ranking_page_url(league_count, 2))

    @silver_upper = upper_border
    @silver_lower = lower_border
  end

  # ブロンズクラスの昇格ボーダーをクロールしインスタンス変数に保存する。
  def bronze_class_crawl
    raise 'ブロンズクラスのページに接続失敗しました。' unless crawl(ranking_page_url(league_count, 1))

    @bronze_upper = upper_border
  end

  # 最新のゴールデンリーグの開始日時を返す。
  # @return [DateTime] ゴールデンリーグの開始日時
  def start_time
    @start_time ||= DateTime.parse(@driver.find_element(:id, 'dates').text[5..20])
  end

  # 最新のゴールデンリーグの終了日時を返す。
  # @return [DateTime] ゴールデンリーグの終了日時
  def end_time
    @end_time ||= DateTime.parse(@driver.find_element(:id, 'dates').text[22..37])
  end

  # 最後に開催されたリーグID または 開催中のリーグIDを返す。
  # @return [Integer] ゴールデンリーグのID
  def league_count
    @league_count ||= @driver.find_element(:id, 'tournament').text.gsub(/[^\d]/, '').to_i
  end

  # 現在表示しているページの昇格ボーダーの値を抜き出して返す。
  # @return [String] 現在表示しているページの昇格ボーダー
  def upper_border
    @driver.find_element(:xpath, '//table[@class="table01"][2]/tbody/tr[1]/td/p').text
  end

  # 現在表示しているページの降格ボーダーの値を抜き出して返す。
  # @return [String] 現在表示しているページの降格ボーダー
  def lower_border
    @driver.find_element(:xpath, '//table[@class="table01"][2]/tbody/tr[2]/td/p').text
  end

  # 現在表示しているページの集計日時の値を抜き出して返す。
  # @return [String] 現在表示しているページの集計日時
  def last_update
    @driver.find_element(:xpath, '//table[@class="table01"][2]/tbody/tr[3]/td/p').text
  end

  # ゴールデンリーグのランキング表示中かどうかを返す。
  # @return [Boolean] ゴールデンリーグ開催中ならtrue, 非開催中ならfalse
  def now?
    now_date = DateTime.parse(DateTime.now.strftime('%Y-%m-%d %H'))
    start_time < now_date && now_date < end_time
  end

  # ゴールデンリーグ開始直後かどうかを返す。
  # @return [Boolean] ゴールデンリーグ開始直後ならtrue, その他はfalse
  def start_now?
    start_time == DateTime.parse(DateTime.now.strftime('%Y-%m-%d %H'))
  end

  # ゴールデンリーグ終了直後かどうかを返す。
  # @return [Boolean] ゴールデンリーグ終了直後ならtrue, その他はfalse
  def end_now?
    end_time == DateTime.parse(DateTime.now.strftime('%Y-%m-%d %H'))
  end

  # 最終結果発表かどうかを返す。
  # @return [Boolean] ゴールデンリーグ集計終了直後ならtrue, その他はfalse
  def result_now?
    now = DateTime.parse(DateTime.now.strftime('%Y-%m-%d %H'))
    now.year == end_time.year && now.month == end_time.month && now.day == end_time.day && now.hour + 1 == end_time.hour
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

  # DDRのページのURLを返す
  # @return [String] DDRのページのURL
  def ddr_page_url
    'https://p.eagate.573.jp/game/ddr/ddra20/p'
  end

  # headless-chromeのWebDriverインスタンスを生成して@driver変数に保存する。
  def generate_selenium_driver
    Selenium::WebDriver::Chrome::Service.driver_path = @webdriver_path
    options = Selenium::WebDriver::Chrome::Options.new(binary: @chromium_path)

    SELENIUM_OPTIONS.each { |option| options.add_argument(option) }
    @driver = Selenium::WebDriver.for :chrome, options: options
  end

  # ゴールデンリーグ開始直後のツイート内容を返す。
  # @return [String] ツイート内容
  def start_now_tweet
    "第#{league_count}回ゴールデンリーグ開始です。"
  end

  # ゴールデンリーグ終了直後のツイート内容を返す。
  # @return [String] ツイート内容
  def end_now_tweet
    "第#{league_count}回ゴールデンリーグ終了です。現在集計中になります。"
  end

  # ゴールデンリーグ集計完了直後のツイート内容を返す。
  # @return [String] ツイート内容
  def result_now_tweet
    "第#{league_count}回ゴールデンリーグお疲れ様でした。\n最終結果\n\n#{score_text}"
  end

  # ゴールデンリーグ中のツイート内容を返す。
  # @return [String] ツイート内容
  def now_tweet
    "#{@last_update} 時点のボーダー:\n\n#{score_text}"
  end

  def score_text
    "ゴールドクラス:\n降格ボーダー: #{@gold_lower}\n\n" \
    "シルバークラス:\n昇格ボーダー: #{@silver_upper}\n降格ボーダー: #{@silver_lower}\n\n" \
    "ブロンズクラス:\n昇格ボーダー: #{@bronze_upper}\n"
  end
end
