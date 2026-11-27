# frozen_string_literal: true

module Organizations
  class AddManager
    include Dry::Monads[:result]

    def self.call(organization:, requester:, email:)
      new(organization, requester, email).call
    end

    def initialize(organization, requester, email)
      @organization = organization
      @requester = requester
      @email = email.downcase.strip
    end

    def call
      return Failure(:user_not_found) unless user
      return Failure(:cannot_add_owner) if user_is_owner?
      return Failure(:already_member) if user_already_member?

      CompanyMember.create!(
        organization: @organization,
        user: user,
        role: manager_role,
        added_by: @requester
      )

      UserMailer.manager_added(user, @organization, @requester).deliver_later

      Success(user)
    end

    private

    def user
      @user ||= User.find_by(email: @email)
    end

    def user_is_owner?
      @organization.company_members.exists?(user: user, role: Role.find_by(key: 'owner'))
    end

    def user_already_member?
      @organization.company_members.exists?(user: user)
    end

    def manager_role
      @manager_role ||= Role.find_by!(key: 'manager')
    end
  end
end
