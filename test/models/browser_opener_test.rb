# frozen_string_literal: true

require "test_helper"

class BrowserOpenerTest < ActiveSupport::TestCase
  class TestOpener < BrowserOpener
    attr_accessor :fake_os, :system_calls, :system_result, :raise_on_system

    def host_os
      fake_os || super
    end

    def system(*args)
      @system_calls ||= []
      @system_calls << args
      raise StandardError, "system failure" if raise_on_system
      system_result
    end
  end

  test "open returns true when system command succeeds on macos" do
    opener = TestOpener.new
    opener.fake_os = :macos
    opener.system_result = true

    assert_equal true, opener.open("http://localhost:3000")
    assert_equal [ [ "open", "http://localhost:3000" ] ], opener.system_calls
  end

  test "open returns true when system command succeeds on linux" do
    opener = TestOpener.new
    opener.fake_os = :linux
    opener.system_result = true

    assert_equal true, opener.open("http://localhost:3000")
    assert_equal [ [ "xdg-open", "http://localhost:3000" ] ], opener.system_calls
  end

  test "open returns true when system command succeeds on windows" do
    opener = TestOpener.new
    opener.fake_os = :windows
    opener.system_result = true

    assert_equal true, opener.open("http://localhost:3000")
    assert_equal [ [ "cmd", "/c", "start", "", "http://localhost:3000" ] ], opener.system_calls
  end

  test "open returns false when host_os is unknown" do
    opener = TestOpener.new
    opener.fake_os = :unknown

    assert_equal false, opener.open("http://localhost:3000")
    assert_nil opener.system_calls
  end

  test "open returns false when system command exits non-zero or fails" do
    opener = TestOpener.new
    opener.fake_os = :macos

    opener.system_result = false
    assert_equal false, opener.open("http://localhost:3000")

    opener.system_result = nil
    assert_equal false, opener.open("http://localhost:3000")
  end

  test "open returns false when system raises an error" do
    opener = TestOpener.new
    opener.fake_os = :macos
    opener.raise_on_system = true

    assert_equal false, opener.open("http://localhost:3000")
  end
end
