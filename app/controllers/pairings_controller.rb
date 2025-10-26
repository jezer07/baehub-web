class PairingsController < ApplicationController
  before_action :authenticate_user!

  def new
    if current_user.couple
      @couple = current_user.couple
    else
      @couple = Couple.new
      @couple.timezone = current_user.timezone.presence || "UTC"
    end
    @invitation = Invitation.new
    @active_invitations = current_user.couple ? current_user.couple.invitations.active : []
  end

  def create
    return redirect_to new_pairing_path, alert: "You are already linked with #{current_user.couple.name}." if current_user.couple

    @couple = Couple.new(couple_params)

    ActiveRecord::Base.transaction do
      @couple.save!
      current_user.update!(couple: @couple, solo_mode: false)
      log_activity(@couple, "#{current_user.name} created the couple space.")
    end

    redirect_to new_pairing_path, notice: "We created #{@couple.name}. Invite your partner with a fresh code below."
  rescue ActiveRecord::RecordInvalid => e
    @invitation = Invitation.new
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def join
    if current_user.couple
      redirect_to dashboard_path, alert: "You are already connected."
      return
    end

    @invitation = Invitation.active.find_by(code: join_params[:code].to_s.upcase)

    if @invitation.blank?
      redirect_to new_pairing_path, alert: "We could not find an active invite with that code."
      return
    end

    couple = @invitation.couple
    if couple.users.where.not(id: current_user.id).count >= 2
      redirect_to new_pairing_path, alert: "That invite has already been used."
      return
    end

    ActiveRecord::Base.transaction do
      current_user.update!(couple:, solo_mode: false)
      @invitation.update!(status: :redeemed, redeemed_at: Time.current)
      log_activity(couple, "#{current_user.name} joined the couple space.", subject: @invitation)
    end

    redirect_to dashboard_path, notice: "You're all linked! Time to plan magic together."
  end

  private

  def couple_params
    params.require(:couple).permit(:name, :anniversary_on, :timezone, :story, :default_currency)
  end

  def join_params
    params.require(:invitation).permit(:code)
  end

  def log_activity(couple, action, subject: nil)
    ActivityLog.create!(
      couple:,
      user: current_user,
      action:,
      subject:,
      metadata: { origin: "pairings" }
    )
  end
end
