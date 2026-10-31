# frozen_string_literal: true

class User < ApplicationRecord
  has_many :documents, dependent: :destroy

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  def self.authenticate_by_token(token)
    find_by(token: token) if token.present?
  end

  private

  def generate_token
    self.token ||= "docn_#{SecureRandom.hex(16)}"
  end
end
