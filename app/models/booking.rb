class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :room
  has_many :invoices, dependent: :destroy
  has_many :payments, through: :invoices, dependent: :destroy
  has_one :contract, dependent: :destroy

  enum status: [ :active, :inactive ]

  before_create :set_due_date, :update_room_occupants
  before_update :deactivate_tenant_account
  before_update :set_room_occupants_once_inactive_or_destroyed, if: :inactive?
  before_destroy :set_room_occupants_once_inactive_or_destroyed
  after_create :generate_contract
  after_update :update_contract_status, if: :saved_change_to_status?

  # validate :only_one_active_booking
  validate :stop_deactivation_if_invoice_is_unpaid
  validates :move_in_date, presence: true

  def set_processed_by(user_email)
    self.processed_by = user_email
    self.save!
  end

  def set_room_occupants_once_inactive_or_destroyed
    # return unless self.inactive?
    room = Room.find(self.room_id)
    if room.occupants_count > 0
      room.occupants_count -= 1
      room.save!
    end
  end
  
  def update_room_occupants
    room = Room.find(self.room_id)
    room.occupants_count += 1
    room.save!
  end

  def deactivate_tenant_account
    return unless self.inactive?
    tenant = User.find(self.user_id)
    tenant.inactive!
  end
  
  private

  def stop_deactivation_if_invoice_is_unpaid
    return unless self.inactive?

    unpaid_invoices = Invoice.where(booking_id: self.id).where(status: 'unpaid')
    if unpaid_invoices.any?
      errors.add("Booking has an unpaid invoice")
    end
  end

  # def only_one_active_booking
  #   return unless self.active?

  #   bookings = Booking.active
  #   if persisted?
  #     bookings = bookings.where('id != ?', id)
  #   end
  #   if bookings.exists?
  #     errors.add(:status, "Tenant currently has an active booking")
  #   end
  # end

  def set_due_date
    self.due_date = self.move_in_date + 1.month
  end

  def generate_contract
    contract = build_contract(
      tenant_first_name: user.first_name,
      tenant_last_name: user.last_name,
      tenant_address: user.address,
      room_code: room.room_code,
      monthly_rate: room.monthly_rate,
      valid_from: move_in_date,
      valid_to: move_out_date,
      branch_type: room.branch.branch_type,
      branch_address: room.branch.address,
      date_signed: Date.today
    )
    contract.save
  end

  def update_contract_status
    contract.update(status: status)
  end

end
