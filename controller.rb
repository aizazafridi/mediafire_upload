require 'open-uri'
require 'json'
require 'digest'
require 'net/http'
require 'streamio-ffmpeg'
require 'nokogiri'

# Method that gets the session token from mediafire account
# session_token is used in API endpoints for security
def get_token
  appid = '4511'
  email = '[mediafire_username]'
  passwd = '[mediafire password]'
  signature = Digest::SHA1.hexdigest("#{email}#{passwd}#{appid}")
  params = {
    'email' => email,
    'password' => passwd,
    'application_id' => appid,
    'signature' => signature,
    'response_format' => 'json'
  }
  url = URI.parse("https://www.mediafire.com/api/user/get_session_token.php")
  url.query = URI.encode_www_form(params)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(url.request_uri)
  response = http.request(request)
  if response.code.to_i == 200
    json = response.body
    obj = JSON.parse(json)
    session = obj['response']['session_token']
    #puts "Session Token: #{session}"
  else
    puts "HTTP request failed with status code #{response.code}"
  end
  return session
end

# Method that gets the mediafire user information
def get_info(session)
  url = URI.parse("https://www.mediafire.com/api/user/get_info.php")
  # Create a URI with the session token as a parameter
  url.query = URI.encode_www_form('session_token' => session)
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  request = Net::HTTP::Get.new(url.request_uri)
  response = http.request(request)
  if response.code.to_i == 200
    json = response.body
    puts json
    #user_info = JSON.parse(json)
    #puts "User Information: #{user_info}"
  else
    puts "HTTP request failed with status code #{response.code}"
  end
end

# Method that extracts a png image from a video file and save it
def extract_first_frame(video_path)
  output_image_path = 'first_frame.png'
  begin
    movie = FFMPEG::Movie.new(video_path)
    # Get the first frame and save it as an image (PNG or JPEG)
    frame = movie.screenshot(output_image_path, seek_time: 5)
    if frame
      puts "First frame extracted and saved as #{output_image_path}"
    else
      puts "Failed to extract the first frame."
    end
    return output_image_path
  rescue Errno::ENOENT => e
    puts "Error: #{e.message}"
    no_path = ""
    return no_path
  rescue StandardError => e
    puts "Error: #{e.message}"
    no_path = ""
    return no_path
  end
end

# Method that uploads image to mediafire
def upload_image(session_token,file_path, file_name)
  key = ''
  path = 'Imgs'
  # Read the file and get its size
  file_contents = File.read(file_path)
  file_size = file_contents.bytesize
  # Set up the URL
  url = URI.parse("http://www.mediafire.com/api/upload/upload.php?session_token=#{session_token}&path=#{path}")
  # Set up the request
  request = Net::HTTP::Post.new(url.request_uri)
  # Set the headers
  request['x-filename'] = file_name
  request['x-filesize'] = file_size.to_s
  # Set the request body
  request.body = file_contents
  # Make the POST request
  http = Net::HTTP.new(url.host, url.port)
  response = http.request(request)
  # Get the response
  # Process the result
  if response.code.to_i == 200
    result = response.body
    # Parse the XML response
    doc = Nokogiri::XML(result)
    # Extract the value of the <key> element
    key = doc.at('key').text
  else
    puts 'File upload failed.'
  end
  return key
end

# Method that polls the current upload and get the quickkey once upload is completed
# quickkey is used to get file info including view and download links
def poll_upload(session_token,key)
  quickkey = ''
  # Set up the URL for checking upload status
  url = URI.parse("https://www.mediafire.com/api/upload/poll_upload.php?session_token=#{session_token}&key=#{key}")
  upload_status = -1  # Initialize status to a non-completed value
  while upload_status != 99
    # Make the GET request to check upload status
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true  # Use HTTPS
    response = http.get(url.request_uri)
    if response.code.to_i == 200
      # Parse the Response
      #upload_status = JSON.parse(response.body)
      xml_doc = Nokogiri::XML(response.body)
      upload_status = xml_doc.at('status').text.to_i
      if upload_status == 99
        puts 'upload complete'
        quickkey = xml_doc.at('quickkey').text
      else
        puts 'upload not complete yet, polling again'
        sleep(5)
      end
    else
      puts 'Failed to retrieve upload status. HTTP Status Code: ' + response.code
      break  # Exit the loop on failure
    end
  end
  return quickkey
end

# Method that returns the file url
def get_file_url(session_token,quickkey)
  file_url = ''
  # Set up the URL
  url = URI.parse("https://www.mediafire.com/api/file/get_info.php?quick_key=#{quickkey}&session_token=#{session_token}")
  # Make the GET request
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true  # Use HTTPS
  response = http.get(url.request_uri)
  if response.code.to_i == 200
      xml_doc = Nokogiri::XML(response.body)
      file_url = xml_doc.at('links normal_download').text
  else
    puts 'Failed to retrieve file info.' +response.code
    puts response
  end
  return file_url
end

# Extract frame from the video file
video_path = '[mediafire_video_path]'
extract_first_frame(video_path)

# Get session_token
session = get_token

#Upload file, get the upload key
key = upload_image(session,'first_frame.png')

#Poll upload, when upload is complete get the quickkey
quickkey = poll_upload(session,key)

#Get uploaded file information
file_url = get_file_url(session,quickkey)
puts file_url

# Get user info
#get_info(session)
