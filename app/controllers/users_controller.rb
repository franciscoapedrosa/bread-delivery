class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]
  before_action :require_admin!

  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to @user, notice: "Utilizador criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if params[:user][:password].blank?
      if @user.update(user_params.except(:password, :password_confirmation))
        redirect_to @user, notice: "Utilizador atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    else
      if @user.update(user_params)
        redirect_to @user, notice: "Utilizador atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "Não pode eliminar a sua própria conta."
    elsif @user.destroy
      redirect_to users_path, notice: "Utilizador eliminado com sucesso."
    else
      redirect_to users_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role)
  end
end
