class YahooController < ApplicationController

  layout "service"

# How to OAuth
# http://mojodna.net/2009/05/20/updating-ruby-consumers-and-providers-to-oauth-10a.html
# How to Hack Yahoo OAuth
# http://groups.google.com/group/oauth-ruby/browse_thread/thread/4059b81775752caf

# http://developer.yahoo.com/oauth/
# http://developer.yahoo.com/oauth/guide/oauth-guide.html
# http://developer.yahoo.com/oauth/guide/oauth-scopes.html
# http://developer.yahoo.com/social/rest_api_guide/uri-general.html

  def authorizeYahooAccess
    # Retrieve Request Token from Yahoo and Re-Direct to Yahoo for Authentication
    begin
      credentials = loadOAuthConfig 'Yahoo'
    rescue
    end
    #logger.info 'Service URL - ' + credentials['Service URL']
    #logger.info 'Consumer Key - ' + credentials['Consumer Key']
    #logger.info 'Consumer Secret - ' + credentials['Consumer Secret']
    if credentials
      auth_consumer = getAuthConsumer credentials            
      request_token = auth_consumer.get_request_token(:oauth_callback => credentials['Callback URL'] )
      if request_token.callback_confirmed?
         #Store Token and Secret to Session
         session[:request_token] = request_token.token
         session[:request_token_secret] = request_token.secret
         # Redirect to Yahoo Authorization
         got_request_token = true
      else
         flash.now[:error] = 'Error Retrieving OAuth Request Token from Yahoo'      
      end
    end
    
    if credentials and got_request_token  
      redirect_to request_token.authorize_url  
    else
      redirect_to :action => :index
    end
  end

  def retrieveYahooContacts    
    # Retrieve Token and Verifier from URL
    oauth_token = params[:oauth_token]
    oauth_verifier = params[:oauth_verifier]

    # Useful Debugging Information?
    #flash.now[:request_token] = "Request Token - " + session[:request_token]
    #flash.now[:request_token_secret] = "Request Token Secret - " + session[:request_token_secret]
    #flash.now[:oauth_token] = "OAuth Token - " + oauth_token
    #flash.now[:oauth_verifier] = "OAuth Verifier - " + oauth_verifier
    
    # Load Yahoo Credentials from comfig/oauth-config.yml
    credentials = loadOAuthConfig 'Yahoo'

    # Factory a OAuth Consumer - Yahoo Authorization Consumer requires using query_string scheme
    auth_consumer = getAuthConsumer credentials
    # Factory Request Token
    got_request_token = false
    begin
      request_token = OAuth::RequestToken.new(auth_consumer, session[:request_token], session[:request_token_secret])
      got_request_token = true
    rescue
      flash.now[:error] = 'Error Retrieving OAuth Request Token from Yahoo'
    end  
    # Exchange Request Token for Access Token
    got_access_token = false
    if got_request_token
      begin
        access_token = request_token.get_access_token(:oauth_verifier => oauth_verifier)
        got_access_token = true
      rescue
        flash.now[:error] = 'Error Retrieving OAuth Access Token from Yahoo'
      end  
    end
    
    # Retrieve Yahoo GUID  and Contacts
    @yahooGUId = ''
    @yahooName = ''
    @yahooContacts = []
    if got_request_token and got_access_token
      # Factory a OAuth Consumer - Yahoo API Consumer requires using header scheme and a realm
      access_token.consumer = getAPIConsumer credentials
      @yahooGUId = getYahooGUID access_token
      profile = getYahooProfile @yahooGUId, access_token
      @yahooName = profile['profile']['nickname']
      @yahooContacts = getYahooContacts @yahooGUId, access_token
    end
  end

  private

  
  def getAuthConsumer credentials
    OAuth::Consumer.new(credentials['Consumer Key'],
      credentials['Consumer Secret'],
        { :site => credentials['Service URL'],
        :yahoo_hack => true,
        :scheme => :query_string,
        :http_method => :get,
        :request_token_path => '/oauth/v2/get_request_token',
        :access_token_path => '/oauth/v2/get_token',
        :authorize_path => '/oauth/v2/request_auth'
        })        
  end
  
  def getAPIConsumer credentials
    OAuth::Consumer.new(credentials['Consumer Key'],
      credentials['Consumer Secret'],
        { :site => 'http://social.yahooapis.com/',
        :yahoo_hack => true,
        :scheme => :header,
        :realm => 'yahooapis.com',
        :http_method => :get,
        :request_token_path => '/oauth/v2/get_request_token',
        :access_token_path => '/oauth/v2/get_token',
        :authorize_path => '/oauth/v2/request_auth'
        })    
  end
  
  def getYahooGUID access_token
    response = access_token.get('/v1/me/guid?format=json') 
    data = response.body
    result = JSON.parse(data)
    result['guid']['value']    
  end

  def getYahooProfile guid, access_token
    profile_url = "/v1/user/" + guid + "/profile?format=json"
    response = access_token.get(profile_url)
    data = response.body
    profile = JSON.parse(data)
    #PP::pp profile, $stderr, 50
  end

  def getYahooContacts guid, access_token
    contacts_url = "/v1/user/" + guid + "/contacts?format=json"
    response = access_token.get(contacts_url)
    data = response.body
    contacts = JSON.parse(data)
    #PP::pp contacts, $stderr, 50
    
    parseContactsResponse contacts
  end
  
  def parseContactsResponse data

    contacts = data['contacts']['contact']
    contact_cnt = data['contacts']['total']
    yahooContacts = []
    for cnt in 0..contact_cnt-1 do
      contact = contacts[cnt]
      contact_id = contact['id']
      contactURI = contact['uri']
      fields = contact['fields']
      #logger.info fields
      #logger.info fields.length
      contactHasEMail = false
      givenName = ''
      familyName = ''
      email = ''
      fields.length.times do |field|
        #logger.info fields[field]['uri']
        #['giveName'] + " " + fields[field]['value']['familyName']
        if fields[field]['type'] == 'name' then
          givenName = fields[field]['value']['givenName']
          familyName = fields[field]['value']['familyName']
        end
        if fields[field]['type'] == 'email' then
          contactHasEMail = true
          email = fields[field]['value']
        end
      end
      if contactHasEMail then
        contact = []
        contact << contactURI
        contact << familyName
        contact << givenName
        contact << email        
        yahooContacts << contact
      end
    end
    yahooContacts
  end
  
end