module CustomExceptions::Pdf
  class ValidationError < CustomExceptions::Base
    def initialize(message = 'PDF validation failed')
      super(message)
    end
  end
end
