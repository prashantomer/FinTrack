namespace :transactions do
  desc "Correct a transaction amount/type and recalculate account balance. Usage: rake transactions:correct[id]"
  task :correct, [ :id ] => :environment do |_, args|
    txn = Transaction.find(args[:id])
    puts "Transaction ##{txn.id}: #{txn.transaction_type} #{txn.amount} on #{txn.date}"
    puts "Description: #{txn.description}"
    print "New amount (blank to keep #{txn.amount}): "
    new_amount = $stdin.gets.chomp
    print "New type (credit/debit, blank to keep #{txn.transaction_type}): "
    new_type = $stdin.gets.chomp

    ActiveRecord::Base.transaction do
      # Reverse old balance delta
      if txn.linked_account_type.present? && txn.linked_account_id.present?
        account = txn.linked_account
        old_delta = txn.transaction_type == "credit" ? -txn.amount : txn.amount
        account.increment!(:balance, old_delta) if account
      end

      txn.amount           = new_amount.present? ? new_amount.to_f : txn.amount
      txn.transaction_type = new_type.present? ? new_type : txn.transaction_type
      txn.save!

      # Apply new balance delta
      if txn.linked_account_type.present? && txn.linked_account_id.present?
        account = txn.linked_account
        new_delta = txn.transaction_type == "credit" ? txn.amount : -txn.amount
        account.increment!(:balance, new_delta) if account
      end
    end

    puts "Transaction ##{txn.id} corrected."
  end

  desc "Deactivate a transaction and reverse its balance impact. Usage: rake transactions:deactivate[id]"
  task :deactivate, [ :id ] => :environment do |_, args|
    txn = Transaction.find(args[:id])
    abort "Transaction ##{txn.id} is already inactive" unless txn.is_active

    ActiveRecord::Base.transaction do
      if txn.linked_account_type.present? && txn.linked_account_id.present?
        account   = txn.linked_account
        reversal  = txn.transaction_type == "credit" ? -txn.amount : txn.amount
        account.increment!(:balance, reversal) if account
      end
      txn.update!(is_active: false)
    end

    puts "Transaction ##{txn.id} deactivated and balance reversed."
  end
end
