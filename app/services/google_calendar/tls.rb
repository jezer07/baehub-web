require "openssl"

module GoogleCalendar
  module Tls
    # Some environments (VPNs/proxies/enterprise networks) can break CRL fetching and cause
    # "unable to get certificate CRL" errors. Most clients do not require CRL checks.
    # You can opt back in by setting GOOGLE_TLS_ENABLE_CRL=1.
    def self.configure(http)
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      store = OpenSSL::X509::Store.new
      store.set_default_paths

      # Allow explicitly pinning a CA file path (useful in dev).
      ca_file = ENV["SSL_CERT_FILE"]
      if ca_file && !ca_file.empty? && File.exist?(ca_file)
        store.add_file(ca_file)
      end

      enable_crl = ENV["GOOGLE_TLS_ENABLE_CRL"].to_s == "1"
      store.flags = enable_crl ? OpenSSL::X509::V_FLAG_CRL_CHECK : 0

      http.cert_store = store
      http
    end
  end
end
