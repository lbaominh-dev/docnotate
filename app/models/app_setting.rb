class AppSetting < ApplicationRecord
  THEMES = %w[system light dark].freeze
  DEFAULT_THEME = "system".freeze

  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.get(key)
    find_by(key: key)&.value
  end

  def self.set(key, value)
    record = find_or_initialize_by(key: key)
    record.update!(value: value)
    record
  end

  def self.theme
    get("theme") || DEFAULT_THEME
  end

  def self.theme=(val)
    val = val.to_s.presence_in(THEMES) || DEFAULT_THEME
    set("theme", val)
  end
end
