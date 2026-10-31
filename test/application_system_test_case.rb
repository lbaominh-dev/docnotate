require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ] do |driver_option|
    driver_option.add_argument("--headless=new")
  end
end

module WindowResizeCDPFallback
  def resize_to(width, height)
    super
    if @session&.driver&.browser&.respond_to?(:execute_cdp)
      current_w = @session.evaluate_script("window.innerWidth") rescue nil
      if current_w && current_w != width && width < 500
        @session.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: height, deviceScaleFactor: 1, mobile: false)
      elsif current_w && width >= 500
        @session.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride") rescue nil
      end
    end
  end
end
Capybara::Window.prepend(WindowResizeCDPFallback)
