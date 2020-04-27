# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table(:users) do
      add_column :xiv_character, String, null: true
    end

    comment_on :column, %i[users last_seen], 'Final Fantasy XIV character for this user'
  end

  down do
    alter_table(:users) do
      drop_column :xiv_character
    end
  end
end
