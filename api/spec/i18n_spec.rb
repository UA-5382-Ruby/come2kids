# frozen_string_literal: true

require 'rails_helper'

RSpec.describe I18n do
  def flatten_keys(hash, prefix = '')
    hash.flat_map do |key, value|
      value.is_a?(Hash) ? flatten_keys(value, "#{prefix}#{key}.") : [ "#{prefix}#{key}" ]
    end
  end

  %w[event_mailer moderation_revisions].each do |domain|
    it "keeps #{domain} uk and en keys identical" do
      uk = YAML.load_file(Rails.root.join("config/locales/#{domain}.uk.yml")).values.first
      en = YAML.load_file(Rails.root.join("config/locales/#{domain}.en.yml")).values.first
      expect(flatten_keys(uk).sort).to eq(flatten_keys(en).sort)
    end
  end
end
