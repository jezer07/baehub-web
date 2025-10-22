class InvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!

  def create
    invitation = current_user.couple.invitations.create!(
      sender: current_user,
      recipient_email: invitation_params[:recipient_email],
      message: invitation_params[:message],
      expires_at: expires_at_from_params
    )

    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: "created an invitation",
      subject: invitation,
      metadata: { origin: "invitations#create" }
    )

    redirect_back fallback_location: new_pairing_path, notice: "Fresh invite ready to share: #{invitation.code}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: new_pairing_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    invitation = current_user.couple.invitations.find(params[:id])

    invitation.update!(status: :revoked, revoked_at: Time.current)

    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: "revoked an invitation",
      subject: invitation,
      metadata: { origin: "invitations#destroy" }
    )

    redirect_back fallback_location: new_pairing_path, notice: "Invitation revoked."
  end

  private

  def ensure_couple!
    return if current_user.couple

    redirect_to new_pairing_path, alert: "Create your shared space before sending invites."
  end

  def invitation_params
    params.require(:invitation).permit(:recipient_email, :message, :expires_in_hours)
  end

  def expires_at_from_params
    hours = invitation_params[:expires_in_hours].presence&.to_i
    hours = 72 if hours.nil? || hours <= 0
    Time.current + hours.hours
  end
end
