class Document < ApplicationRecord
  include Documents::FileTypeable, Documents::AstParseable,
          Documents::FileSyncable, Documents::Commentable,
          Documents::ContentOutline,
          Documents::TableOfContents, Documents::Assets,
          Documents::Filterable

  belongs_to :user, optional: true

  validates :file_path, presence: true, uniqueness: { scope: :user_id }
  validates :file_type, presence: true
  validates :content, presence: true

  belongs_to :current_version, class_name: "DocumentVersion", optional: true
  has_many :document_versions, dependent: :destroy
  has_many :document_nodes, through: :current_version
  has_many :comments, dependent: :destroy

  scope :recently_opened, -> { where.not(last_opened_at: nil).order(last_opened_at: :desc) }

  before_destroy :clear_current_version_reference, prepend: true

  def display_name = name.presence || File.basename(file_path)

  def touch_last_opened!
    update_column(:last_opened_at, Time.current)
  end

  private

  def clear_current_version_reference
    update_column(:current_version_id, nil) if current_version_id.present?
  end
end
