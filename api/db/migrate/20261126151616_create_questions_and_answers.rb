# frozen_string_literal: true

class CreateQuestionsAndAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.string :target_type, null: false
      t.bigint :target_id
      t.text :text, null: false
      t.boolean :is_hidden, null: false, default: false

      t.timestamps
    end

    add_index :questions, %i[target_type target_id created_at], name: 'index_questions_on_target'
    add_check_constraint :questions, "target_type IN ('Event', 'Organization', 'Platform')",
                         name: 'chk_questions_target_type'
    add_check_constraint :questions, 'char_length(text) >= 1 AND char_length(text) <= 2000',
                         name: 'chk_questions_text_length'

    create_table :answers do |t|
      t.references :question, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.text :text, null: false

      t.timestamps
    end

    add_index :answers, %i[question_id created_at]
    add_check_constraint :answers, 'char_length(text) >= 1 AND char_length(text) <= 2000',
                         name: 'chk_answers_text_length'
  end
end
