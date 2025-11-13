module JointAccounts
  class Creator
    attr_reader :couple, :creator_user, :params, :errors

    def initialize(couple:, creator_user:, params:)
      @couple = couple
      @creator_user = creator_user
      @params = params
      @errors = []
    end

    def call
      validate_inputs
      return failure if @errors.any?

      ActiveRecord::Base.transaction do
        create_joint_account
        add_creator_as_member
        add_additional_members
        initialize_balances
      end

      success
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
      failure
    rescue StandardError => e
      @errors << "Failed to create joint account: #{e.message}"
      failure
    end

    private

    attr_reader :joint_account

    def validate_inputs
      @errors << "Couple is required" unless couple
      @errors << "Creator user is required" unless creator_user
      @errors << "Name is required" if params[:name].blank?
      
      if creator_user && couple && creator_user.couple_id != couple.id
        @errors << "Creator must be a member of the couple"
      end
    end

    def create_joint_account
      @joint_account = couple.joint_accounts.create!(
        name: params[:name],
        currency: params[:currency] || couple.default_currency,
        created_by: creator_user,
        status: :active,
        settings: params[:settings] || {}
      )
    end

    def add_creator_as_member
      joint_account.joint_account_memberships.create!(
        user: creator_user,
        role: :admin,
        active: true
      )
    end

    def add_additional_members
      member_ids = Array(params[:member_ids]).compact.uniq - [creator_user.id]
      
      member_ids.each do |user_id|
        user = couple.users.find_by(id: user_id)
        next unless user

        joint_account.joint_account_memberships.create!(
          user: user,
          role: :member,
          active: true
        )

        JointAccountMailer.joint_account_created(joint_account, user).deliver_later
      end
    end

    def initialize_balances
      joint_account.joint_account_memberships.each do |membership|
        joint_account.joint_account_balances.create!(
          user: membership.user,
          currency: joint_account.currency,
          balance_cents: 0,
          borrowed_from_account_cents: 0,
          lent_to_account_cents: 0
        )
      end
    end

    def success
      { success: true, joint_account: joint_account }
    end

    def failure
      { success: false, errors: @errors }
    end
  end
end

