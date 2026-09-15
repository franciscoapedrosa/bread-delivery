class Vehicle < ApplicationRecord
  belongs_to :distributor, class_name: "User", optional: true
  attr_accessor :photo
  before_validation :prepare_photo
  before_validation { self.registration = registration.to_s.upcase.gsub(/[^A-Z0-9]/, "") }
  validates :name, :registration, presence: true
  validates :registration, uniqueness: true, length: { maximum: 20 }
  validate :distributor_role
  validate :photo_error

  private

  def distributor_role
    errors.add(:base, "Escolha uma conta de distribuidor.") if distributor && !distributor.distributor?
  end

  def photo_error
    errors.add(:base, @photo_error) if @photo_error
  end

  def prepare_photo
    return if photo.blank?

    @photo_error = nil
    unless photo.respond_to?(:read) && photo.respond_to?(:size) && photo.size <= 2.megabytes
      @photo_error = "Escolha uma fotografia até 2 MB."
      return
    end
    photo.rewind
    bytes = photo.read(2.megabytes + 1)
    detected = if bytes.start_with?("\x89PNG\r\n\x1a\n".b)
      "image/png"
    elsif bytes.start_with?("\xff\xd8\xff".b)
      "image/jpeg"
    elsif bytes.start_with?("RIFF") && bytes.byteslice(8, 4) == "WEBP"
      "image/webp"
    end
    unless detected
      @photo_error = "Escolha uma fotografia JPEG, PNG ou WebP."
      return
    end
    self.photo_data = bytes
    self.photo_type = detected
  end
end
