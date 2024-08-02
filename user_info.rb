require 'rest-client'
require 'json'

# Replace these values with your own credentials
email = ''
password = ''
app_id = ''

# Authenticate and obtain a session token
response = RestClient.post('https://www.mediafire.com/api/2.1/user/get_session_token.php',
  email: email,
  password: password,
  application_id: app_id,
  format: 'json'
)

# Parse the JSON response
parsed_response = JSON.parse(response)

# Check if authentication was successful
if parsed_response['response']['result'] == 'Success'
  session_token = parsed_response['response']['session_token']
  user_info_url = "https://www.mediafire.com/api/user/get_info.php?session_token=#{session_token}"

  # Retrieve user information
  user_info_response = RestClient.get(user_info_url)
  user_info = JSON.parse(user_info_response)

  # Display user information
  display_name = user_info['response']['user_info']['display_name']
  puts "User Display Name: #{display_name}"
else
  puts "Authentication failed"
end
