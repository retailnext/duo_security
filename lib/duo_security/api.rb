require 'cgi'
require 'httparty'

module DuoSecurity
  class API
    class UnknownUser < StandardError; end

    FACTORS = ["auto", "passcode", "phone", "sms", "push"]

    include HTTParty
    ssl_ca_file File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "data", "ca-bundle.crt"))

    def initialize(host, secret_key, integration_key)
      @host = host
      @skey = secret_key
      @ikey = integration_key

      self.class.base_uri "https://#{@host}/rest/v1"
    end

    def ping
      response = self.class.get("/ping")
      response.parsed_response.fetch("response") == "pong"
    end

    def check
      auth = sign("get", @host, "/rest/v1/check", {}, @skey, @ikey)
      response = self.class.get("/check", headers: {"Authorization" => auth})

      # TODO use parsed_response.fetch(...) when content-type is set correctly
      response["response"] == "valid"
    end

    def preauth(user)
      response = post("/preauth", {"user" => user})["response"]

      raise UnknownUser, response.fetch("status") if response.fetch("result") == "enroll"

      return response
    end

    def auth(user, factor, factor_params)
      raise ArgumentError.new("Factor should be one of #{FACTORS.join(", ")}") unless FACTORS.include?(factor)

      params = {"user" => user, "factor" => factor}.merge(factor_params)
      response = post("/auth",params)

      response["response"]["result"] == "allow"
    end

    protected

    def post(path, params = {})
      auth = sign("post", @host, "/rest/v1#{path}", params, @skey, @ikey)
      self.class.post(path, headers: {"Authorization" => auth}, body: params)
    end

    def hmac_sha1(key, data)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new('sha1'), key, data.to_s)
    end

    def sign(method, host, path, params, skey, ikey)
      canon = [method.upcase, host.downcase, path]

      args = []
      for key in params.keys.sort
        val = params[key]
        args << "#{CGI.escape(key)}=#{CGI.escape(val)}"
      end

      canon << args.join("&")
      canon = canon.join("\n")

      sig = hmac_sha1(skey, canon)
      auth = "#{ikey}:#{sig}"

      encoded = Base64.encode64(auth).split("\n").join("")

      return "Basic #{encoded}"
    end
  end
end