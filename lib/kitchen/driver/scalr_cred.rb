require 'os'
require 'json'
if OS.windows? then
  require 'kitchen/driver/dbapi.rb'
end
require 'io/console'
module Kitchen
  module Driver
    module CredentialsManager
      if OS.windows? then
        include DPAPI
      end
      def loadCredentials()
        if OS.windows? then
          credentialsFilename = ENV['APPDATA'] + "\\kitchen_scalr.cred"
          if File.file?(credentialsFilename) then
            #Load existing credentials
            encryptedCred = File.open(credentialsFilename, "rb") {|f| f.read}
            decryptedJson = decrypt(encryptedCred)
            cred = JSON.parse(decryptedJson[0])
            config[:scalr_api_key_id] = cred['API_KEY_ID']
            config[:scalr_api_key_secret] = cred['API_KEY_SECRET']
          else
            #Prompt for credentials
            print 'Enter your API Key ID: '
            apiKeyId = STDIN.gets.chomp
            print 'Enter you API Key secret: '
            apiKeySecret = STDIN.noecho(&:gets).chomp
            cred = {
              'API_KEY_ID' => apiKeyId,
              'API_KEY_SECRET' => apiKeySecret
            }
            decryptedJson = cred.to_json
            encryptedCred = encrypt(decryptedJson)
            File.binwrite(credentialsFilename, encryptedCred)
            config[:scalr_api_key_id] = cred['API_KEY_ID']
            config[:scalr_api_key_secret] = cred['API_KEY_SECRET']
          end
        else
          puts 'This OS is currently not supported'
        end
      end
    end
  end
end
