class ClassifyLinkedAccountTypes < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE transactions SET linked_account_type = 'Account'     WHERE linked_account_type = 'account'"
    execute "UPDATE transactions SET linked_account_type = 'TermAccount' WHERE linked_account_type = 'term_account'"
  end

  def down
    execute "UPDATE transactions SET linked_account_type = 'account'      WHERE linked_account_type = 'Account'"
    execute "UPDATE transactions SET linked_account_type = 'term_account' WHERE linked_account_type = 'TermAccount'"
  end
end
