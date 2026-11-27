# frozen_string_literal: true

module Organizations
  class RemoveManager
    include Dry::Monads[:result]

    def self.call(organization:, requester:, user_id:)
      new(organization, requester, user_id).call
    end

    def initialize(organization, requester, user_id)
      @organization = organization
      @requester = requester
      @user_id = user_id
    end

    def call
      member = @organization.company_members.find_by(user_id: @user_id)

      return Failure(:not_a_member) unless member
      return Failure(:cannot_remove_owner) if member.role.key == 'owner'

      member.destroy!
      Success(true)
    end
  end
end
