require 'bundler/setup'
require 'eventmachine'
require 'active_record'
require 'yaml'
require 'syslog/logger'
load File.expand_path('../../app/models/whois_record.rb', __FILE__)

module WhoisServer
  def logger
    @logger ||= Syslog::Logger.new 'whois'
  end

  def dbconfig
    return @dbconfig unless @dbconfig.nil?
    begin
      dbconf = YAML.load(File.open(File.expand_path('../../config/database.yml', __FILE__)))
      @dbconfig = dbconf[ENV['WHOIS_ENV']]
    rescue NoMethodError => e
      logger.fatal "\n----> Please inspect config/database.yml for issues! Error: #{e}\n\n"
    end
  end

  def connection
    @connection ||= ActiveRecord::Base.establish_connection(dbconfig)
  end

  def receive_data(data)
    connection
    whois_record = WhoisRecord.where(name: data.strip).first
    logger.info "#{Time.now} requested: #{data} ; Whois record id was: #{whois_record.try(:id)}"
    if whois_record.nil?
      send_data no_entries_msg
    elsif whois_record.body.blank?
      logger.info "No whois body for whois record id #{whois_record.try(:id)}"
      send_data no_body_msg 
    else
      send_data whois_record.body
    end
    close_connection_after_writing
  end

  private

  def no_entries_msg
    "\nDomain not found" + footer_msg
  end

  def no_body_msg
    "\nThere was a technical issue with whois body, please try again later!" +
    footer_msg
  end

  def footer_msg
    "\n\nEstonia .ee Top Level Domain WHOIS server\n" \
    "More information at http://internet.ee\n"
  end
end

EventMachine.run do
  EventMachine.start_server '0.0.0.0', 43, WhoisServer
  EventMachine.set_effective_user ENV['WHOIS_USER'] || 'whois'
end
