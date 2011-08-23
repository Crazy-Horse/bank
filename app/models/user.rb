class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :recoverable, :confirmable, :mobile_confirmable, :trackable, :validatable, :lockable, :oauth_authenticatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :email_confirmation, :password, :password_confirmation,
                  :gender, :address, :address_2, :phone, :phone_is_mobile, :mobile, :city,
                  :state, :zip, :country, :challenge_question, :challenge_answer, :status,
                  :first_name, :middle_name, :surname, :birth, :accept_transaction_token, :pin_attributes

  READ_ONLY_ATTRIBUTES_AFTER_COMPLETION =  [ :username, :account_type, :company_name, :company_id_number ]

  attr_accessor :email_confirmation, :accept_transaction_token

  # Validations
  PASSWORD_REGEX       = /[0-9]/
  USERNAME_REGEX       = /^[a-zA-Z][0-9a-zA-Z.,_\!\/\\\-\s+]*$/
  PHONE_REGEX          = /^[0-9.\-\(\)+\s]*$/
  COMPANY_ID_REGEX     = /^[0-9a-zA-Z.\-]*$/

  ### Account Creation: First Step

  validates :username,
    presence: true,
    uniqueness: true,
    length: { minimum: 2, maximum: 30 },
    format: { with: USERNAME_REGEX },
    reduce: true,
    allow_blank: true

  validates :password,
    format: { with: PASSWORD_REGEX },
    reduce: true,
    allow_blank: true,
    if: :password_required?

  validates :email,             confirmation: true, length: { minimum: 2, maximum: 100 }, format: { with: Mimo::AcceptableInputs::EMAIL_REGEX },          if: :email_changed?,    reduce: true
  validates :company_name,      presence: true,     length: { minimum: 2, maximum: 100 }, format: { with: Mimo::AcceptableInputs::GENERAL_FIELDS_REGEX }, if: :business_account?, reduce: true
  validates :company_id_number, presence: true,     length: { minimum: 2, maximum: 100 }, format: { with: COMPANY_ID_REGEX },     if: :business_account?, reduce: true

  RESERVED_USERNAME_LIST = ['root', 'admin', 'administrator']
  validate  :username_not_in_reserved_list

  VALID_ACCOUNT_TYPES = [ 'Personal', 'Business' ]
  validates :account_type, inclusion: { in: VALID_ACCOUNT_TYPES }


  ### Account Creation: Second Step

  validates :first_name, :surname, :address, :address_2, :city, :state, :zip, :challenge_answer,
    length: { minimum: 2, maximum: 100 },
    format: { with: Mimo::AcceptableInputs::GENERAL_FIELDS_REGEX },
    reduce: true,
    allow_blank: true

  validates :middle_name,
    length: { minimum: 1, maximum: 100 },
    format: { with: Mimo::AcceptableInputs::GENERAL_FIELDS_REGEX },
    reduce: true,
    allow_blank: true

  validates :first_name, :surname, :birth, :address, :city, :state, :zip,
    presence: true,
    if: :usable?

  validate :valid_birth

  validates :mobile, :phone,
    format: { with: PHONE_REGEX },
    length: { minimum: 2, maximum: 100 },
    reduce: true,
    allow_blank: true, reduce: true, if: :usable?

  validates :mobile, presence: true,    if: Proc.new { |u| u.usable? && (u.personal_account? || u.phone.blank?) }
  validates :phone,  presence: true,    if: Proc.new { |u| u.usable? && u.business_account? && u.mobile.blank? }
  validates :gender, inclusion: { in: [ 'Male', 'Female' ] },   if: :usable?

  validates :pin,
    presence: true,
    associated: :pin

  COUNTRIES = [ 'United States of America', 'Nigeria' ]
  validates :country, inclusion: { in: COUNTRIES },             if: :usable?

  QUESTIONS = [ 'What is your favorite book?', 'What is your favorite TV show?',
                'What is your favorite color?', 'In what city were you born?',
                "What is your best friend's first name?", 'What is the name of your favorite pet?' ]
  validates :challenge_question, inclusion: { in: QUESTIONS },  if: :usable?
  validates :challenge_answer,   presence: true,                if: :usable?

  # Relationships
  has_many :accounts,       foreign_key: :owner_id
  has_many :bank_accounts,  foreign_key: :owner_id
  has_many :credentials

  has_many :sent_requests,      :foreign_key => 'requestor_id',
                                :class_name => 'Request',
                                :dependent => :destroy
  has_many :requestors,         :through => :sent_requests

  has_many :received_requests,  :foreign_key => 'requestee_id',
                                :class_name => 'Request',
                                :dependent => :destroy
  has_many :requestees,         :through => :received_requests

  has_one :pin
  accepts_nested_attributes_for :pin

  # Callbacks
  after_create     :create_account
  before_save      :confirm_user_from_transaction
  after_save       :async_complete_transactions, if: :completed_and_confirmed?
  after_initialize :set_email_based_on_token

  def generate_token
    credentials.new.tap do |credential|
      credential.access_token = SecureRandom.base64(32).tr('+/=', 'xyz')
      credential.save!
    end
  end

  def full_name
    "#{first_name} #{middle_name.first + '. ' if middle_name.present?}#{surname}"
  end

  def personal_account?
    account_type == 'Personal'
  end

  def business_account?
    account_type == 'Business'
  end

  def completed_and_confirmed?
    completed? && confirmed?
  end

  def usable?
    !new_record?
  end

  def completed?
    status == 'completed'
  end

  def complete
    self.status = 'completed'
  end

  def complete!
    update_attribute :status, 'completed'
  end

  def wallet
    accounts.first
  end

  def balance
    # Currency hard-coded ATM. If we gonna handle other currencies in the future, we can take a look at the Money gem
    Balance.new currency: 'NGN', balance: wallet.try(:balance)
  end

  # This method is used to tell SimpleForm if a field should be set as disabled or not.
  def read_only_attribute?(attribute)
    !mass_assignment_authorizer.include?(attribute)
  end

  def send_changed_email_notification(old_email)
    UserMailer.changed_email_notification(old_email, self).deliver
  end

  def send_received_request(request)
    UserMailer.received_request(request, self).deliver
  end

  def send_paid_request(request)
    UserMailer.paid_request(request, self).deliver
  end

  def send_pending_sent_transfer_completed(transaction)
    UserMailer.pending_sent_transfer_completed(transaction).deliver
  end

  def send_pending_received_transfer_completed(transaction)
    UserMailer.pending_received_transfer_completed(transaction).deliver
  end

  def update_with_password!(attributes)
    valid = update_with_password(attributes)
    if attributes[:password].blank?
      valid = false
      errors.add(:password, :blank)
    end
    valid
  end

  def transaction
    @transaction ||= Transaction.find_by_accept_token(accept_transaction_token)
  end

  def pending_transactions
    @pending_transactions ||= Transaction.where(destination_user_id: nil).where(destination_user_field: email).where(status: 'pending')
  end

  # This won't check any validation, like if user is completed or confirmed.
  def complete_transactions!
    pending_transactions.each do |transaction|
      ActiveRecord::Base.transaction do
        transaction.entries.create!(amount: transaction.amount, entry_type: 'D', transaction: transaction, account: Account.mimo_assets)
        transaction.entries.create!(amount: transaction.amount, entry_type: 'C', transaction: transaction, account: wallet)
        transaction.destination_user = self
        transaction.complete! unless transaction.completed?
      end
      transaction.source_user.send_pending_sent_transfer_completed(transaction)
      self.send_pending_received_transfer_completed(transaction)
    end
  end

  protected
  # Do not prevent from login on account with an uncofirmed email.
  def confirmation_required?
    false
  end

  private
  def async_complete_transactions
    Resque.enqueue(CompleteTransactions, self.id)
  end

  def confirm_user_from_transaction
    self.confirmed_at = Time.now if accept_transaction_token.present? && transaction.present?
  end

  def set_email_based_on_token
    self.email = transaction.try(:destination_user_field) if email.blank? && accept_transaction_token.present?
  end

  def create_account
    self.accounts.create(name: 'Wallet')
  end

  def username_not_in_reserved_list
    errors.add(:username, :reserved) if RESERVED_USERNAME_LIST.include?(username.try(:downcase))
  end

  def valid_birth
    errors.add(:birth, :invalid) unless birth.blank? || (Time.parse('1/1/1900') < birth && birth < Date.today - 16.years)
  end

  # attributes that shouldn't be accessible after the user is completed
  def mass_assignment_authorizer(role = :default)
    super + (!completed? ? READ_ONLY_ATTRIBUTES_AFTER_COMPLETION : [])
  end
end
