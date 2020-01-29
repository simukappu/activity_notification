class AdminsController < ApplicationController
  before_action :set_admin, only: [:show]

  # GET /admins
  def index
    render json: {
      users: Admin.all.as_json(include: :user)
    }
  end

  # GET /admins/:id
  def show
    render json: @admin.as_json(include: :user)
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin
      @admin = Admin.find(params[:id])
    end
end
