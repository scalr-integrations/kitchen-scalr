require 'os'
require 'json'
require 'kitchen/driver/dbapi.rb'
require 'io/console'
module Kitchen
  module Driver
    module CredentialsManager
      extend DPAPI
      def loadCredentials()
        if OS.windows? then
          credentialsFilename = "\%APPDATA\%\\kitchen_scalr.cred"
          if File.file?(credentialsFilename) then
            #Load existing credentials
            encryptedCred = File.read(credentialsFilename)
            decryptedJson = decrypt(encryptedCred)
            cred = JSON.parse(decryptedJson)
            config[:scalr_api_key_id] = cred['API_KEY_ID']
            config[[:scalr_api_key_secret] = cred['API_KEY_SECRET']
          else
            #Prompt for credentials
            print 'Enter your API Key ID: '
            apiKeyId = gets.chomp
            print 'Enter you API Key secret: '
            apiKeySecret = STDIN.noecho(&:gets).chomp
            cred = {
              'API_KEY_ID' => apiKeyId,
              'API_KEY_SECRET' => apiKeySecret
            }
            decryptedJson = cred.to_json
            encryptedCred = encrypt(decryptedJson)
            File.write(credentialsFilename, encryptedCred)
            config[:scalr_api_key_id] = cred['API_KEY_ID']
            config[[:scalr_api_key_secret] = cred['API_KEY_SECRET']
          end
        else
          puts 'This OS is currently not supported'
        end
      end
    end
  end
end
