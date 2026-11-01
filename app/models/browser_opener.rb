# frozen_string_literal: true

class BrowserOpener
  class << self
    def open(url)
      new.open(url)
    end
  end

  def open(url)
    result = case host_os
    when :macos then system("open", url)
    when :linux then system("xdg-open", url)
    when :windows then system("cmd", "/c", "start", "", url)
    else false
    end

    result == true
  rescue StandardError
    false
  end

  private

  def host_os
    case RUBY_PLATFORM
    when /darwin/ then :macos
    when /linux/ then :linux
    when /mswin|mingw|cygwin/ then :windows
    else :unknown
    end
  end
end
