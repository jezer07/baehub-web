# app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < Api::BaseController
      # GET /api/v1/users/profile
      def profile
        render json: { user: user_detail(current_user) }
      end

      # PATCH /api/v1/users/profile
      def update_profile
        if current_user.update(user_params)
          render json: { user: user_detail(current_user) }
        else
          render_errors(current_user.errors.full_messages)
        end
      end

      # PATCH /api/v1/users/password
      def update_password
        if current_user.valid_password?(params[:current_password])
          if current_user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
            render json: { message: "Password updated successfully" }
          else
            render_errors(current_user.errors.full_messages)
          end
        else
          render_error("Current password is incorrect", :unauthorized)
        end
      end

      # GET /api/v1/users/couple
      def couple_info
        if current_user.couple
          render json: { couple: couple_detail(current_user.couple) }
        else
          render json: { couple: nil, message: "No couple associated" }
        end
      end

      # POST /api/v1/users/couple/join
      def join_couple
        invitation = Invitation.find_by(code: params[:code], status: "pending")

        if invitation.nil?
          return render_error("Invalid invitation code", :not_found)
        end

        if invitation.expired?
          return render_error("Invitation has expired", :unprocessable_entity)
        end

        ActiveRecord::Base.transaction do
          current_user.update!(couple: invitation.couple, role: "partner")
          invitation.update!(status: "redeemed", redeemed_at: Time.current)

          invitation.couple.activity_logs.create!(
            user: current_user,
            action: "joined_couple",
            subject: invitation.couple,
            metadata: { via_invitation: invitation.code }
          )
        end

        render json: {
          message: "Successfully joined couple",
          couple: couple_detail(current_user.couple)
        }
      end

      # POST /api/v1/users/couple/create
      def create_couple
        couple = Couple.new(couple_params)

        ActiveRecord::Base.transaction do
          if couple.save
            current_user.update!(couple: couple, role: "partner")

            couple.activity_logs.create!(
              user: current_user,
              action: "created_couple",
              subject: couple,
              metadata: { name: couple.name }
            )

            render json: {
              message: "Couple created successfully",
              couple: couple_detail(couple)
            }, status: :created
          else
            render_errors(couple.errors.full_messages)
          end
        end
      end

      # POST /api/v1/users/couple/invite
      def create_invitation
        unless current_user.couple
          return render_error("You must be in a couple to send invitations", :forbidden)
        end

        invitation = current_user.couple.invitations.build(
          sender: current_user,
          recipient_email: params[:recipient_email],
          message: params[:message]
        )

        if invitation.save
          render json: { invitation: invitation_detail(invitation) }, status: :created
        else
          render_errors(invitation.errors.full_messages)
        end
      end

      private

      def user_params
        params.require(:user).permit(:name, :timezone, :preferred_color, :avatar_url, :prefers_dark_mode)
      end

      def couple_params
        params.require(:couple).permit(:name, :timezone, :anniversary_on, :story, :default_currency)
      end

      def user_detail(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          timezone: user.timezone,
          preferred_color: user.preferred_color,
          avatar_url: user.avatar_url,
          prefers_dark_mode: user.prefers_dark_mode,
          role: user.role,
          solo_mode: user.solo_mode,
          coupled: user.paired?,
          couple_id: user.couple_id,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end

      def couple_detail(couple)
        {
          id: couple.id,
          name: couple.name,
          slug: couple.slug,
          timezone: couple.timezone,
          anniversary_on: couple.anniversary_on,
          story: couple.story,
          default_currency: couple.default_currency,
          members: couple.users.map { |u| { id: u.id, name: u.name, email: u.email } },
          created_at: couple.created_at,
          updated_at: couple.updated_at
        }
      end

      def invitation_detail(invitation)
        {
          id: invitation.id,
          code: invitation.code,
          recipient_email: invitation.recipient_email,
          message: invitation.message,
          status: invitation.status,
          expires_at: invitation.expires_at,
          sender: {
            id: invitation.sender.id,
            name: invitation.sender.name
          },
          created_at: invitation.created_at
        }
      end
    end
  end
end
