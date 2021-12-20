# frozen_string_literal: true

require "uri"
require "net/http"

module Decidim
  module SpamDetection
    class ApiProxy
      URL = ENV.fetch("SPAM_DETECTION_API_URL", "http://localhost:8080/api")
      AUTH_TOKEN = ENV.fetch("SPAM_DETECTION_API_AUTH_TOKEN", "dummy")

      def self.send_request_in_batch(data_array, batch_size = 1000)
        responses = []
        data_array.each_slice(batch_size) do |subdata_array|
          responses << JSON.parse(send_request_to_api(subdata_array))
        end

        responses.flatten
      end

      def self.send_request_to_api(data)
        retries = [3, 5, 10]
        url = URI(URL)
        http = Net::HTTP.new(url.host, url.port)
        request = Net::HTTP::Post.new(url)
        request["Content-Type"] = "application/json"
        request["AUTH_TOKEN"] = AUTH_TOKEN
        request.body = JSON.dump(data)
        http.use_ssl = true if use_ssl?(url)
        response = http.request(request)
        response.read_body
      rescue Net::ReadTimeout
        raise Net::ReadTimeout if retries.empty?

        sleep retries.first
        retries.shift
        retry
      end

      def self.use_ssl?(url)
        url.scheme == "https"
      end
    end
  end
end
