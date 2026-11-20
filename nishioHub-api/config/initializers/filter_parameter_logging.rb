Rails.application.config.filter_parameters += %i[
  inquiry credentials passw secret token _key crypt salt certificate otp ssn
]
