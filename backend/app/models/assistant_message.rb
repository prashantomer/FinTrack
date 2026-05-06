class AssistantMessage < ApplicationRecord
  ROLES = %w[user assistant tool].freeze

  belongs_to :user
  has_one_attached :file

  validates :role, inclusion: { in: ROLES }
  validates :session_id, presence: true

  scope :in_session, ->(session_id) { where(session_id: session_id) }
  scope :pinned,     -> { where(pinned: true) }
  scope :chronological, -> { order(:created_at, :id) }
end
