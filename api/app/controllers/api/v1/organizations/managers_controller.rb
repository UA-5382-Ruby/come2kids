# frozen_string_literal: true

module Api
  module V1
    module Organizations
      class ManagersController < ApplicationController
        before_action :authenticate_user!
        before_action :set_organization

        def index
          authorize @organization, :show_managers?

          members = @organization.company_members
                                 .joins(:role)
                                 .where(roles: { key: 'manager' })
                                 .includes(:user)

          render json: {
            managers: members.map do |cm|
              {
                id: cm.user.id,
                email: cm.user.email,
                first_name: cm.user.first_name,
                last_name: cm.user.last_name,
                role: cm.role.key,
                added_at: cm.added_at
              }
            end
          }
        end

        def create
          authorize @organization, :add_manager?

          result = ::Organizations::AddManager.call(
            organization: @organization,
            requester: current_user,
            email: params.require(:email)
          )

          case result
          when Dry::Monads::Success
            render json: {
              message: I18n.t('organizations.manager_added'),
              manager: {
                id: result.value!.id,
                email: result.value!.email,
                first_name: result.value!.first_name,
                last_name: result.value!.last_name
              }
            }, status: :created
          when Dry::Monads::Failure
            handle_failure(result.failure)
          end
        end

        def destroy
          authorize @organization, :remove_manager?

          result = ::Organizations::RemoveManager.call(
            organization: @organization,
            requester: current_user,
            user_id: params[:user_id]
          )

          case result
          when Dry::Monads::Success
            render json: { message: I18n.t('organizations.manager_removed') }
          when Dry::Monads::Failure
            handle_failure(result.failure)
          end
        end

        private

        def set_organization
          @organization = Organization.find(params[:organization_id])
        end

        def handle_failure(error)
          case error
          when :user_not_found
            render json: { code: 'USER_NOT_FOUND', message: I18n.t('errors.organizations.user_not_found') }, status: :not_found
          when :already_member
            render json: { code: 'ALREADY_MEMBER', message: I18n.t('errors.organizations.already_member') }, status: :unprocessable_content
          when :cannot_add_owner
            render json: { code: 'CANNOT_ADD_OWNER', message: I18n.t('errors.organizations.cannot_add_owner') }, status: :unprocessable_content
          when :not_a_member
            render json: { code: 'NOT_A_MEMBER', message: I18n.t('errors.organizations.not_a_member') }, status: :not_found
          when :cannot_remove_owner
            render json: { code: 'CANNOT_REMOVE_OWNER', message: I18n.t('errors.organizations.cannot_remove_owner') }, status: :forbidden
          else
            render json: { code: 'VALIDATION_ERROR', message: I18n.t('api_errors.validation_error') }, status: :unprocessable_content
          end
        end
      end
    end
  end
end
