class UsersController < Devise::RegistrationsController
  before_filter :authenticate_user!
  skip_before_filter :check_need_for_additional_information, only: [:additional_information, :update]

  def additional_information
    @user = current_user
    redirect_to profile_path if @user.completed?
  end

  def new
    @user = build_resource(accept_transaction_token: params[:accept_token])
    respond_with_navigational(resource){ render_with_scope :new }
  end

  def update
    @user = current_user
    old_email = @user.email
    @user.assign_attributes(params[:user])

    valid_captcha = (@user.completed? || verify_recaptcha(model: @user, message: "Captcha doesn't match. Please try again."))

    email_changed = @user.email_changed? # Need to check it before save

    if valid_captcha && @user.save
      redirect_to profile_path, notice: (@user.completed? ? I18n.t('devise.registrations.updated') : I18n.t('devise.registrations.created'))
      @user.send_confirmation_instructions if !@user.completed? || email_changed
      @user.send_changed_email_notification(old_email) if email_changed
      @user.complete! unless @user.completed?
    else
      flash.delete(:recaptcha_error)
      render @user.completed? ? 'profiles/show' : :additional_information
    end
  end

  protected
  # Remove flash message when going from the first step to the second step of the registration
  def set_flash_message(key, kind, options={})
    super unless kind == :signed_up
  end
end
