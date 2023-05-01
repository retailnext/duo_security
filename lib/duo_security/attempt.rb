module DuoSecurity
  class Attempt
    def initialize(api, username)
      @api      = api
      @username = username
    end

    def login!
      preauth = @api.preauth(@username)
      return false unless preauth["factors"].key?('default')

      factor = preauth["factors"]["default"]
      @api.auth(@username, "auto", {"auto" => factor})
    rescue API::UnknownUser => e
      false
    end
  end
end
