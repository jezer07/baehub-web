# app/controllers/api/v1/tasks_controller.rb
module Api
  module V1
    class TasksController < Api::BaseController
      before_action :set_couple
      before_action :set_task, only: [ :show, :update, :destroy, :toggle_completion ]

      # GET /api/v1/tasks
      def index
        @tasks = @couple.tasks.order(created_at: :desc)

        # Apply filters
        @tasks = @tasks.by_status(params[:status]) if params[:status].present?
        @tasks = @tasks.assigned_to(params[:assignee_id]) if params[:assignee_id].present?
        @tasks = @tasks.by_due_date(params[:due_date]) if params[:due_date].present?

        # Apply sorting
        case params[:sort_by]
        when "due_date"
          @tasks = @tasks.order(due_at: :asc)
        when "priority"
          @tasks = @tasks.order(priority: :desc)
        when "created_at"
          @tasks = @tasks.order(created_at: :desc)
        end

        render json: { tasks: @tasks.map { |task| task_detail(task) } }
      end

      # GET /api/v1/tasks/:id
      def show
        render json: { task: task_detail(@task) }
      end

      # POST /api/v1/tasks
      def create
        @task = @couple.tasks.build(task_params)
        @task.creator = current_user

        if @task.save
          log_activity("created", @task)
          render json: { task: task_detail(@task) }, status: :created
        else
          render_errors(@task.errors.full_messages)
        end
      end

      # PATCH/PUT /api/v1/tasks/:id
      def update
        if @task.update(task_params)
          log_activity("updated", @task)
          render json: { task: task_detail(@task) }
        else
          render_errors(@task.errors.full_messages)
        end
      end

      # DELETE /api/v1/tasks/:id
      def destroy
        @task.destroy
        log_activity("deleted", @task)

        render json: { message: "Task deleted successfully" }
      end

      # POST /api/v1/tasks/:id/toggle_completion
      def toggle_completion
        new_status = @task.status == "done" ? "todo" : "done"
        @task.update!(status: new_status)

        if new_status == "done"
          @task.update!(completed_at: Time.current)
        else
          @task.update!(completed_at: nil)
        end

        log_activity("toggled_completion", @task)

        render json: { task: task_detail(@task) }
      end

      private

      def set_couple
        @couple = current_user.couple
        render_error("No couple associated with this user", :forbidden) unless @couple
      end

      def set_task
        @task = @couple.tasks.find(params[:id])
      end

      def task_params
        params.require(:task).permit(:title, :description, :status, :priority, :due_at, :assignee_id)
      end

      def task_detail(task)
        {
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          priority: task.priority,
          due_at: task.due_at,
          completed_at: task.completed_at,
          assignee: task.assignee ? {
            id: task.assignee.id,
            name: task.assignee.name,
            email: task.assignee.email
          } : nil,
          creator: {
            id: task.creator.id,
            name: task.creator.name,
            email: task.creator.email
          },
          created_at: task.created_at,
          updated_at: task.updated_at
        }
      end

      def log_activity(action, task)
        @couple.activity_logs.create!(
          user: current_user,
          action: "task_#{action}",
          subject: task,
          metadata: { title: task.title }
        )
      end
    end
  end
end
