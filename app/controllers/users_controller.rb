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
    @user.build_customer(bread_quantity: 1)
  end

  def edit
    @user.build_customer(bread_quantity: 1) unless @user.customer
  end

  def create
    @user = User.new(user_params)
    @user.role = requested_role
    assign_customer_profile
    if @user.save
      redirect_to @user, notice: "Utilizador criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = user_params
    attributes = attributes.except(:password, :password_confirmation) if attributes[:password].blank?

    @user.assign_attributes(attributes)
    @user.role = requested_role
    assign_customer_profile

    if @user.save
      redirect_to @user, notice: "Utilizador atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
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

  def assign_customer_profile
    return unless @user.customer?

    existing_id = params.require(:user)[:existing_customer_id]
    if @user.new_record? && existing_id.present?
      @user.customer = Customer.where(user_id: nil).find(existing_id)
    else
      profile = @user.customer || @user.build_customer(bread_quantity: 1)
      profile.assign_attributes(params.require(:user).fetch(:customer_attributes, ActionController::Parameters.new).permit(:name, :address))
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def requested_role
    role = params.require(:user).fetch(:role, nil)
    role if User::ROLES.include?(role)
  end
end
