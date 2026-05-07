# == Schema Information
#
# Table name: assistant_messages
#
#  id             :bigint           not null, primary key
#  content        :text
#  latency_ms     :integer
#  model          :string
#  pinned         :boolean          default(FALSE), not null
#  provider       :string
#  role           :string           not null
#  token_estimate :integer
#  tokens_in      :integer
#  tokens_out     :integer
#  tool_arguments :jsonb
#  tool_name      :string
#  tool_result    :jsonb
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  session_id     :uuid             not null
#  user_id        :bigint           not null
#
# Indexes
#
#  idx_assistant_messages_pinned                       (user_id) WHERE (pinned IS TRUE)
#  index_assistant_messages_on_user_id                 (user_id)
#  index_assistant_messages_on_user_id_and_created_at  (user_id,created_at)
#  index_assistant_messages_on_user_id_and_session_id  (user_id,session_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
