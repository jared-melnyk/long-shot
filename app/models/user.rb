class User < ApplicationRecord
  has_secure_password

  has_many :pool_users, dependent: :destroy
  has_many :pools, through: :pool_users
  has_many :picks, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
end
