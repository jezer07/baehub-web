class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!
  before_action :set_task, only: [ :show, :edit, :update, :destroy, :toggle_completion ]

  def index
    @tasks = current_user.couple.tasks
    @tasks = @tasks.by_status(params[:status]) if params[:status].present?
    @tasks = @tasks.assigned_to(params[:assignee_id].to_i) if params[:assignee_id].present?
    @tasks = @tasks.where("DATE(due_at) = ?", params[:due_on]) if params[:due_on].present?

    # Apply sorting
    case params[:sort]
    when "status_asc"
      @tasks = @tasks.order(:status)
    when "due_at_asc"
      @tasks = @tasks.order(due_at: :asc)
    when "due_at_desc"
      @tasks = @tasks.order(due_at: :desc)
    when "priority_desc"
      priority_order = Task.priorities.invert.stringify_keys
      @tasks = @tasks.sort_by { |t| -priority_order[t.priority] }
    else
      @tasks = @tasks.order(:status).by_due_date
    end
  end

  def show
  end

  def new
    @task = current_user.couple.tasks.build
    @task.creator = current_user
  end

  def create
    @task = current_user.couple.tasks.build(task_params)
    @task.creator = current_user

    Task.transaction do
      if @task.save
        log_task_activity("created task '#{@task.title}'", @task)
        redirect_to(params[:redirect_to].presence || tasks_path, notice: "Task created successfully.")
      else
        flash.now[:alert] = @task.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    @task.errors.add(:base, e.message)
    flash.now[:alert] = @task.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    Task.transaction do
      if @task.update(task_params)
        activity_message = if @task.saved_changes.key?("status")
          "changed '#{@task.title}' status from #{@task.saved_changes['status'][0].humanize} to #{@task.saved_changes['status'][1].humanize}"
        elsif @task.saved_changes.key?("assignee_id")
          "reassigned '#{@task.title}' to #{@task.assignee&.name || 'unassigned'}"
        else
          "updated task '#{@task.title}'"
        end
        log_task_activity(activity_message, @task)
        redirect_to @task, notice: "Task updated successfully."
      else
        flash.now[:alert] = @task.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end
  rescue StandardError => e
    @task.errors.add(:base, e.message)
    flash.now[:alert] = @task.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  def destroy
    Task.transaction do
      @task.destroy
      log_task_activity("deleted task '#{@task.title}'", @task)
      redirect_to tasks_path, notice: "Task deleted successfully."
    end
  rescue StandardError => e
    redirect_to tasks_path, alert: "Error deleting task: #{e.message}"
  end

  def toggle_completion
    new_status = @task.done? ? :todo : :done
    Task.transaction do
      @task.update!(status: new_status)
      log_task_activity("marked '#{@task.title}' as #{new_status.to_s.humanize.downcase}", @task)
      respond_to do |format|
        format.html { redirect_back(fallback_location: tasks_path, notice: "Task marked as #{new_status.to_s.humanize.downcase}.") }
        format.turbo_stream
      end
    end
  rescue StandardError => e
    respond_to do |format|
      format.html { redirect_back(fallback_location: tasks_path, alert: "Error updating task: #{e.message}") }
      format.turbo_stream { render turbo_stream: turbo_stream.prepend("flash-messages", partial: "shared/flash", locals: { type: :alert, message: "Error updating task: #{e.message}" }) }
    end
  end

  private

  def ensure_couple!
    return if current_user.couple

    redirect_to new_pairing_path, alert: "Create your shared space before managing tasks."
    nil
  end

  def set_task
    @task = current_user.couple.tasks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to tasks_path, alert: "Task not found."
    nil
  end

  def task_params
    params.require(:task).permit(:title, :description, :status, :priority, :due_at, :assignee_id)
  end

  def log_task_activity(action, task)
    ActivityLog.create!(
      couple: current_user.couple,
      user: current_user,
      action: action,
      subject: task,
      metadata: { origin: "tasks" }
    )
  end
end
