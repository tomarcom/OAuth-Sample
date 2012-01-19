class FacebookController < ApplicationController

  layout "service"

# http://developers.facebook.com/docs/authentication/
# http://developers.facebook.com/docs/reference/api/permissions/
# http://developers.facebook.com/docs/reference/api/
# http://developers.facebook.com/docs/reference/api/user/
# http://developers.facebook.com/docs/reference/api/FriendList/
# http://stackoverflow.com/questions/7717881/facebook-object-graph-https-request-from-ruby
# Facebook utilizes a two stage authentication
# stage 1 - User Authenticates and Allows Application Component Access. Returns an Access Code.
# Note: That the user grants the permissions requested in the scope variable of the authentication/authorization request.
# Stage 2 - The Stage 1 Access Code and the Application Id are utilized to request an Access Token, returns an Access Token.
# Note: This is a token for the user/app to access the permitted components. It expires and can be revoked!
# After a token has been acquired, one may utilize the Facebook API to access permitted components. i.e. User, FriendList

  def authorizeFacebookAccess
    # Retrieve Request Token from Yahoo and Re-Direct to Yahoo for Authentication
    credentials = loadOAuthConfig 'Facebook'
    #logger.info 'Service URL - ' + credentials['Service URL']
    #logger.info 'App ID - ' + credentials['App ID']
    #logger.info 'App Secret - ' + credentials['App Secret']
    
    auth_client = getAuthClient credentials
    auth_url = auth_client.auth_code.authorize_url( :redirect_uri => credentials['Callback URL'] )
    auth_scope = "scope=user_about_me,friends_about_me"
    url = "#{credentials['Service URL']}?client_id=#{credentials['App ID']}&#{auth_scope}&redirect_uri=#{credentials['Callback URL']}"
    redirect_to url

  end
  
  def retrieveFacebookContacts
    
    # Strip params
    if(params[:error] and params[:error] != '')
      flash[:error] = params[:error]
      if(params[:error_desciption] and params[:error_desciption] != '')
        flash[:error_desciption] = params[:error_desciption]
        redirect_to :auth_error
      end
    end
  
    if(params[:code] and params[:code] != '')
      access_code = params[:code]
      #logger.info 'Access Code  - ' + access_code
      access_token = getAppAccessToken access_code
      #logger.info 'Access Token - ' + access_token
    end
        
    # Data for Views
    @facebookMe = ''
    @facebookFriends = []
        
    if access_token
      # Acces Code and Accees Token Retrieved
      @facebookMe = getFacebookMe access_token
      #logger.info @facebookMe
            
      @facebookFriends = getFacebookFriends access_token
      #logger.info @facebookFriends
      
   end



  end

private

  
  def getAuthClient credentials

    OAuth2::Client.new( credentials['App ID'], credentials['App Secret'], :site => credentials['Service URL'] )
    
  end
      
  def getAppAccessToken access_code
    credentials = loadOAuthConfig 'Facebook'
    url = "https://graph.facebook.com/oauth/access_token?client_id=#{credentials['App ID']}&redirect_uri=#{credentials['Callback URL']}&client_secret=#{credentials['App Secret']}&code=#{CGI.escape(access_code)}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
    response = http.request(request)

    # Split the response into the access_token and the expires
    access_token = ""
    expires = ""
    data = response.body.split("&")
    cur_param = data[0].split("=")
    if CGI.unescape( cur_param[0] ) == "access_token"
      access_token = CGI.unescape( cur_param[1] )
    else
      
    end
    
    cur_param = data[1].split("=")
    if CGI.unescape( cur_param[0] ) == "expires"
      expires = CGI.unescape( cur_param[1] )
    else
      
    end
        
    access_token
    
  end
  
  def getFacebookMe access_token
    url = "https://graph.facebook.com/me?access_token=#{CGI.escape(access_token)}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
    response = http.request(request)
    data = response.body    
    parseMeResponse data
  end
  
  def getFacebookFriends access_token
    url = "https://graph.facebook.com/me/friends?access_token=#{CGI.escape(access_token)}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.path + "?" + uri.query)
    response = http.request(request)
    data = response.body
    parseFriendResponse data
  end
  
  def parseMeResponse data
    result = JSON.parse( data )
    #PP::pp result, $stderr, 50
    result['id']
  end

  def parseFriendResponse data
    result = JSON.parse( data )
    #PP::pp result, $stderr, 50
    friends = result['data']
    friends_cnt = friends.length

    facebookFriends = []
    for cnt in 0..friends_cnt-1 do
      friend = friends[cnt]
      friend_name = friend['name']
      friend_id = friend['id']
      #logger.info friend_name
      #logger.info friend_name
      friend = []
      friend << friend_name
      friend << friend_id
      facebookFriends << friend
    end
    
    facebookFriends
  end
  
end
