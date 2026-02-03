module GoogleCalendar
  class RequestError < StandardError
    attr_reader :status

    def initialize(message, status)
      super(message)
      @status = status.to_i
    end

    def sync_token_invalid?
      status == 410
    end
  end
end
