class UsersController < ApplicationController
  before_action :set_user, only: [:show]

  # GET /users
  def index
    render json: {
      users: User.all
    }
  end

  # GET /users/:id
  def show
    render json: @user
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end
end
