require "csv"

namespace :db do
  namespace :seed do
    desc "Seed banks from db/seeds/banks.csv"
    task banks: :environment do
      csv_path = Rails.root.join("db/seeds/banks.csv")
      abort "banks.csv not found at #{csv_path}" unless File.exist?(csv_path)

      count = 0
      CSV.foreach(csv_path, headers: true) do |row|
        Bank.find_or_create_by!(short_name: row["short_name"]) do |b|
          b.name      = row["name"]
          b.is_system = row["is_system"]&.downcase == "true"
        end
        count += 1
      end
      puts "Seeded #{count} banks"
    end

    desc "Seed platforms from db/seeds/platforms.csv"
    task platforms: :environment do
      csv_path = Rails.root.join("db/seeds/platforms.csv")
      abort "platforms.csv not found at #{csv_path}" unless File.exist?(csv_path)

      count = 0
      CSV.foreach(csv_path, headers: true) do |row|
        Platform.find_or_create_by!(short_name: row["short_name"]) do |p|
          p.name          = row["name"]
          p.platform_type = row["type"] || row["platform_type"]
          p.is_system     = row["is_system"]&.downcase == "true"
        end
        count += 1
      end
      puts "Seeded #{count} platforms"
    end
  end
end
