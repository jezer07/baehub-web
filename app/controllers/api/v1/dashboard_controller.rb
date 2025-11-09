# app/controllers/api/v1/dashboard_controller.rb
module Api
  module V1
    class DashboardController < Api::BaseController
      # GET /api/v1/dashboard
      def show
        couple = current_user.couple

        if couple
          @tasks = couple.tasks.order(created_at: :desc).limit(6)
          @events = couple.events.future.order(starts_at: :asc).limit(4)
          @expenses = couple.expenses.recent.limit(4)
          @balance = couple.calculate_balance
          @activity_logs = couple.activity_logs.order(created_at: :desc).limit(10)
          @invitations = couple.invitations.where(status: "pending")

          render json: {
            tasks: @tasks.map { |task| task_summary(task) },
            events: @events.map { |event| event_summary(event) },
            expenses: @expenses.map { |expense| expense_summary(expense) },
            balance: @balance,
            activity_logs: @activity_logs.map { |log| activity_log_summary(log) },
            invitations: @invitations.map { |inv| invitation_summary(inv) }
          }
        else
          render json: {
            message: "No couple associated with this user",
            tasks: [],
            events: [],
            expenses: [],
            balance: {},
            activity_logs: [],
            invitations: []
          }
        end
      end

      private

      def task_summary(task)
        {
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          due_at: task.due_at,
          assignee: task.assignee ? { id: task.assignee.id, name: task.assignee.name } : nil,
          creator: { id: task.creator.id, name: task.creator.name },
          created_at: task.created_at,
          updated_at: task.updated_at
        }
      end

      def event_summary(event)
        {
          id: event.id,
          title: event.title,
          description: event.description,
          starts_at: event.starts_at,
          ends_at: event.ends_at,
          all_day: event.all_day,
          location: event.location,
          category: event.category,
          color: event.color,
          creator: { id: event.creator.id, name: event.creator.name },
          created_at: event.created_at
        }
      end

      def expense_summary(expense)
        {
          id: expense.id,
          title: expense.title,
          amount: expense.amount,
          currency: expense.couple.default_currency,
          incurred_on: expense.incurred_on,
          spender: { id: expense.spender.id, name: expense.spender.name },
          split_strategy: expense.split_strategy,
          created_at: expense.created_at
        }
      end

      def activity_log_summary(log)
        {
          id: log.id,
          action: log.action,
          user: log.user ? { id: log.user.id, name: log.user.name } : nil,
          subject_type: log.subject_type,
          subject_id: log.subject_id,
          metadata: log.metadata,
          created_at: log.created_at
        }
      end

      def invitation_summary(invitation)
        {
          id: invitation.id,
          code: invitation.code,
          sender: { id: invitation.sender.id, name: invitation.sender.name },
          recipient_email: invitation.recipient_email,
          expires_at: invitation.expires_at,
          status: invitation.status,
          created_at: invitation.created_at
        }
      end
    end
  end
end
