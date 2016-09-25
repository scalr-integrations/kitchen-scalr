require 'uri'
require 'time'
require 'openssl'
require 'base64'
require 'rest-client'

class ScalrAPI
	
	def initialize(url, key_id, key_secret)
	
		@api_url = url
		@api_key_id = key_id
		@api_key_secret = key_secret
	
	end
	
	def request(method, url, body='')

		#JSON encode body if set
		if body != ''
			body = body.to_json
		end
		
		#Split URL into components
		parts = URI.parse(@api_url + url)
		
		path = parts.path
		host = parts.host
		port = parts.port

		query = ''
		if parts.query != nil
			#Convert querystring into an array
			q = parts.query.split('&')
			
			#Sort the querystring array
			q.sort!
			
			#Convert querystring array back to string
			query = q.join('&')
		end
		
		#Create ISO 8601 date/time string
		time = Time.now.utc.iso8601 + '+00:00'
		
		#Collection of request data for generating signature
		request = [
			method,
			time,
			path,
			query,
			body
		]
		
		#Calculate signature based on request data
		signature = 'V1-HMAC-SHA256 ' + Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), @api_key_secret, request.join("\n"))).strip()
		
		#HTTP request headers
		headers = {
			'X-Scalr-Key-Id' => @api_key_id,
			'X-Scalr-Signature' => signature,
			'X-Scalr-Date' => time,
			'X-Scalr-Debug' => '1'
		}
		
		if body != ""
			headers['Content-Type'] = 'application/json'
		end

		response = ::RestClient::Request.execute(
			:method => method, 
			:url => @api_url + url,
			:headers => headers,
			:payload  => body
		)
		
		return JSON.parse(response)
	
	end
	
	#List items from API
	def list(url)
		data = []
		
		while url != nil do
			response = self.request('GET', url)
		
			data.concat response['data']
			url = response['pagination']['next']
		end
		
		return data
	end
	
	#Fetch a single item from API
	def fetch(url)
		response = self.request('GET', url)
		return response['data']
	end
	
	#Create item in API
	def create(url, data)
		response = self.request('POST', url, data)
		return response['data']
	end

	#Delete item from API
	def delete(url)
		response = self.request('DELETE', url)
		return true	
	end
	
	#Edit items in API
	def post(url, data)
		response = self.request('POST', url, data)
		return response['data']
	end

end