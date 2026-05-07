# == Schema Information
#
# Table name: system_tasks
#
#  id                  :bigint           not null, primary key
#  last_completed_at   :datetime
#  last_completed_date :date
#  last_error          :text
#  last_status         :string(16)
#  name                :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_system_tasks_on_name  (name) UNIQUE
#
require "rails_helper"

RSpec.describe SystemTask, type: :model do
  describe ".named" do
    it "creates a row the first time and returns the same row thereafter" do
      first  = described_class.named("daily_pnl")
      second = described_class.named("daily_pnl")
      expect(second.id).to eq(first.id)
      expect(described_class.where(name: "daily_pnl").count).to eq(1)
    end
  end

  describe "#stale_for?" do
    it "is true when last_completed_date is nil" do
      task = described_class.create!(name: "x")
      expect(task.stale_for?(Date.current)).to be true
    end

    it "is true when last_completed_date is in the past" do
      task = described_class.create!(name: "x", last_completed_date: Date.current - 1)
      expect(task.stale_for?(Date.current)).to be true
    end

    it "is false when already completed for the given date" do
      task = described_class.create!(name: "x", last_completed_date: Date.current)
      expect(task.stale_for?(Date.current)).to be false
    end
  end

  describe "#mark_ok! / #mark_error!" do
    let(:task) { described_class.create!(name: "x") }

    it "stamps a successful run" do
      task.mark_ok!(at: Time.current, date: Date.new(2026, 5, 7))
      expect(task.last_status).to eq("ok")
      expect(task.last_completed_date).to eq(Date.new(2026, 5, 7))
      expect(task.last_error).to be_nil
    end

    it "stamps an error and truncates long messages" do
      long = "boom" * 1_000
      task.mark_ok!(at: 1.day.ago, date: Date.current - 1)
      task.mark_error!(long)
      expect(task.last_status).to eq("error")
      expect(task.last_error.length).to eq(2_000)
      expect(task.last_completed_date).to eq(Date.current - 1) # unchanged on error
    end
  end
end
