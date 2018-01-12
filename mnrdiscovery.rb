#!/usr/bin/env ruby
require 'optparse'
require 'logger'
require 'net/http'
require 'json'
require 'nokogiri'
require 'openssl'

class MnrClient
  DEFAULT_OPTIONS={
    url:     'https://localhost:58443',
    user:     'admin',
    password: 'changeme',
    log:      false,
    url_root: '/centralized-management',
    verbose:  false,
    timeout:  600,
  }
  def initialize args
    OptionParser.new do |o|
      o.on "-U", "--url [https://localhost",  "frontend url"    do |u| options[:url]=u      end
      o.on "-u", "--user [username]",  "frontend username"      do |u| options[:user]=u     end
      o.on "-p", "--password [*****]", "frontend password"      do |p| options[:password]=p end
      o.on "--timeout [s]", Integer, "timeout for requests (s)" do |t| options[:timeout]=t  end
      o.on "-t","--type [device type]", "specify type"          do |t| options[:type]=t     end
      o.on "--csv [file]", "write results in a csv file"        do |f| options[:csv]=f      end
      o.on "-v","--verbose","verbose output"                    do options[:verbose]=true   end
      o.on "-l", "--log", "log http requests"                   do options[:log]=true       end
    end.parse args
  end
  def options
    @options||=DEFAULT_OPTIONS.dup
  end
  def logger
    @logger||=Logger.new(STDOUT).tap do |l|
      l.level= options[:verbose] ? 0 : 1
    end
  end
  def http
    uri = URI(options[:url])
    @http||=Net::HTTP.new(uri.host, uri.port).tap do |h|
      h.set_debug_output(STDOUT) if options[:log]
      h.use_ssl = uri.scheme == 'https'
      h.verify_mode = OpenSSL::SSL::VERIFY_NONE
      h.open_timeout=options[:timeout]
      h.read_timeout=options[:timeout]
    end
  end
  def login
    logger.debug 'initial cookie'
    g=get '/'
    logger.debug 'login'
    post('/j_security_check', data: {j_username: options[:user], j_password: options[:password]}) do |response, request|
      unless response.kind_of? Net::HTTPRedirection
        logger.error 'login error (expected redirection, got %s/%s),  exiting' % [response.code,response.message]
        exit 1
      end
      # TODO use the proper redirection in response['location']
      get '/'
    end
  end
  def get_version
    x = get '/info/about'
    v = Nokogiri::HTML(x).at_css('.product-version li').content
    v[/((\d)+\.(\d)+)/,1]
  end
  def logout
    get '/session/logout'
  end
  def get url, params: nil, &blk
    r=request(url,params:params)
    execute_request r,&blk
  end
  def post url, data: nil, headers: {}, &blk
    r=request url,data: data,headers: headers
    execute_request r,&blk
  end
  private
  def request url, data: nil, headers: {}, params: nil
    u=options[:url_root]+url
    if data
      r=Net::HTTP::Post.new(u,headers.update(cookie_jar))
      r.set_form_data(data)
      r
    else
      if params
        u=u+'?'+URI.encode_www_form(params)
      end
      r=Net::HTTP::Get.new(u,headers.update(cookie_jar))
      r
    end
  end
  def execute_request r, &blk
    x=http.request r
    update_cookie_jar x
    if blk
      blk.call x,r
    else
      x.body
    end
  end
  def cookie_jar
    @jar||=Hash.new
  end
  def update_cookie_jar r
    sc=r.to_hash['set-cookie']
    if sc
      cookie_jar['Cookie']=sc.map do |x| x[/^.*?;/] end.join
    end
  end
end

class Net::HTTPResponse
  def cookiesX
    #self.to_hash['set-cookie'].map do |x| x[/^.*?;/] end.join
    self.to_hash['set-cookie'].map do |x| x[/^.*?;/] end.each_with_object({}) do |s,o| s=~/(.+)=(.+);/; o[$1]=$2 end
  end
  def set_cookie
    self.to_hash['set-cookie'].map do |x| x[/^.*?;/] end.each_with_object({}) do |s,o| s=~/(.+)=(.+);/; o[$1]=$2 end
  end
end

class Nokogiri::XML::Element
  # h=Nokogiri::HTML <<-EOS
  #   <table id="z">
  #     <thead>
  #       <tr><th>a</th><th>b</th></tr>
  #     </thead>
  #     <tbody>
  #       <tr><td>1</td><td>2</td></tr>
  #       <tr><td>3</td><td>4</td></tr>
  #     </tbody>
  #   </table>
  # EOS
  # h.at_css('#z').table
  # => [{"a"=>"1", "b"=>"2"}, {"a"=>"3", "b"=>"4"}]
  # the optional block will be called for each th/td element, its return will be used as key for th / value for td
  def table &blk
    raise ArgumentError unless 'table'==name
    blk||=:text
    h=at_xpath('./thead/tr').xpath('./th').map(&blk)
    xpath('./tbody/tr').map do |e| h.zip(e.xpath('./td').map(&blk)).to_h end
  end
  def attributes_hash
    attributes.each_with_object({}) do |(k,v),o|
      o[k]=v.to_s
    end
  end
  def question_answer
    begin
      if    inp=at_css('input')         ; if inp.attr('class') then JSON.parse(inp.attr('value')) rescue '' else inp.attr('value') end
      elsif res=at_css('.test-result')  ; res.attributes_hash
      else                              ; text
      end
    end
  end
  def elements_attrs
    r=css('input').each_with_object({}) do |e,o|
      o[e['name']]=e['value']
    end
    r.empty? ? text : r
  end
end

# autovivifying hash, think: perl hashes
class AutoHash < Hash
  def default k=nil
    store k,self.class.new
  end
  # AutoHash.new.store_at(1,2,3,4,5).store_at(1,2,3,44,55).store_at(7,8,9)
  # => {1=>{2=>{3=>{4=>5, 44=>55}}}, 7=>{8=>9}}
  def store_at e,*a,v
    a.empty? ? store(e,v) : self[e].store_at(*a,v)
    self
  end
  # returns the value of a leaf only
  def leaf e,*a
    if has_key? e
      val=fetch e
      sub=val.kind_of? self.class
      if a.empty?
        sub ? nil : val
      elsif sub
        val.leaf *a
      else
        nil
      end
    else
      nil
    end
  end
end

class Hash
  # {"cat"=>123,"dog"=>456,"cow"=>789}.translate_keys({"cat"=>"meow","cow"=>"moooooooo"},keep_unmatched: false)
  # => {"meow"=>123, "moooooooo"=>789}
  # {"Tomato"=>"red","CiTrUS"=>"yellow"}.translate_keys &:downcase
  # => {"tomato"=>"red", "citrus"=>"yellow"}
  def translate_keys h=nil, keep_unmatched: true, &blk
    raise ArgumentError if (blk and h) or (!blk and h.nil?)
    blk||=proc do |x|
      if    h.key? x       ; h[x]
      elsif keep_unmatched ; x
      else                 ; nil
      end
    end
    each_with_object({}) do |(k,v),o|
      nk=blk.call(k)
      o[nk]=v if nk or keep_unmatched
    end
  end
end

class String
  COLORS={
    red:    31,
    green:  32,
    yellow: 33,
  }
  def color c
    col=COLORS[c]
    raise ArgumentError unless col
    STDOUT.tty? ? "\033[%dm%s\033[0m" % [col,self] : self
  end
  # *VERY* crude & incomplete, but enough for us
  def camel_case upper: true
    split(/-|_/).map(&:capitalize).tap do |x| x.first.downcase! unless upper end.join('')
  end
  def lower_camel_case
    camel_case upper: false
  end
  def pluralize c
    c.to_i==1 ? self : self+'s'
  end
end

module Discovery
  class ObjectHash < Hash
    @@mnr_version='4.1'
    def initialize h
      h.each_with_object(self) do |(k,v),o| o[k]=v end
    end
    def self.set_mnr_version v
      @@mnr_version = v
    end
    def self.get_mnr_version
      @@mnr_version
    end
    def parse_root_device root, *rest
      if @@mnr_version.to_f >= 4.1
        self.dig(root.split(' ').last, *rest)
      else
        self.dig(root, *rest)
      end
    end
  end
  class CSVFile
    def initialize f
      if f
        @file=File.open f,'w'
      end
    end
    def << *a
      if @file
        @file << a.join(';')+"\n"
      end
    end
  end
  class Device < ObjectHash
    attr_reader :type
    def initialize h,t
      @type=t
      super h
    end
    def friendly_name
      answers.friendly_name || 'no_friendly_name'
    end
    def answers
      @answers||=self.translate_keys(keep_unmatched:false) do |k|
        if md=/^#{type.request['exportId']}\.(?<list>.+)/.match(k)
          md['list'].split('.')
        end
      end.each_with_object(Discovery::Answers.new) do |(k,v),o|
        o.store_at *k,v unless v.to_s.empty?
      end.tap do |a| Discovery.logger.debug a end
    end
    def test
      Discovery.client.post('/discocenter/devicemgmt/test', data: test_payload, headers: {"content-type"=>"application/json"}) do |response,_|
        JSON.parse(response.body)["testResult"]
      end.tap do |x| Discovery.logger.debug x end
    rescue Net::ReadTimeout
      {'status'=> 'TIMEOUT'}
    end
    def test_payload
      type.request.dup.update(
        jsonRows: [
          {
            instance:     self['Instance'],
            server:       self['Server'],
            isDeleted:    false,
            isModified:   false,
            jsonAnswers:  answers.to_json
          }
        ].to_json
      )
    end
    def details
      Discovery.logger.debug self
      tr=test
      res=case tr["status"]
          when "0","SUCCESS"    ; "SUCCESS".color :green
          when "1","FAILED"     ; "FAILED".color  :red
          when "TIMEOUT"        ; "TIMEOUT".color :red
          else                  ; "UNKNOWN".color :yellow
          end
      det=[type.parse_root_device('Device Type','device-name'),self['Server'],self['Instance'],friendly_name,tr["status"]]
      Discovery.logger.info "%-25s%-25s%-25s%-25s [%s]" % det
      det
    end
  end
  class Type < ObjectHash
    def wanted?
      t=Discovery.client.options[:type]
      not t or t==self.parse_root_device("Device Type","device-name")
    end
    def request
      @request||=self.parse_root_device("Device Type").translate_keys(&:lower_camel_case)
    end
    def devices
      @devices||=Discovery.client.get('/discocenter/devicemgmt/get', params: self.request) do |response,_|
        Nokogiri::HTML(response.body).at_css('#devices-running').table(&:question_answer)
      end.map do |h|
        Device.new h,self
      end
    end
    def device_details
      devices.map do |d|
        d=d.details
      end
    end
  end
  class Answers < AutoHash
    FRIENDLY_NAME_CANDIDATES=[
      %w{primary vcenter host},
      %w{host},
      %w{hostname},
      %w{serialnb},
      %w{friendlyname},
    ]
    def friendly_name
      FRIENDLY_NAME_CANDIDATES.each do |c|
        l=self.leaf *c
        return l if l
      end
      nil
    end
  end
  class << self
    def client
      @client||=MnrClient.new ARGV
    end
    def logger
      client.logger
    end
    def start
      ObjectHash.set_mnr_version(client.get_version)
      client.login
      type_details
      device_details
      client.logout
    end
    def type_details
      types.each do |t|
        count=t.parse_root_device("Device Count")
        logger.info "%-25s%6d %s" % [t.parse_root_device("Device Type","device-name"),count,'device'.pluralize(count)]
      end
    end
    def types
      @types||=proc do
        logger.debug 'getting device type list'
        client.get('/discocenter/devicemgmt/list') do |response,_|
          Nokogiri::HTML(response.body).at_css('#device-types').table(&:elements_attrs).map do |h|
          Type.new h
        end
        end
      end.call
    end
    def device_details
      logger.debug 'getting device details'
      csv=CSVFile.new Discovery.client.options[:csv]
      csv << %w{#type server instance device result}
      types.select(&:wanted?).map do |t|
        t.device_details
      end.flatten(1).each do |l|
        csv << l
      end
    end
  end
end

Discovery.start
