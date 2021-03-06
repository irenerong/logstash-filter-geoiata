# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "sqlite3"

# This example filter will replace the contents of the default 
# message field with whatever you specify in the configuration.
#
# It is only intended to be used as an example.
class LogStash::Filters::Geoiata < LogStash::Filters::Base

  # Setting the config_name here is required. This is how you
  # configure this filter from your Logstash config.
  #
  # filter {
  #   example {
  #     message => "My message..."
  #   }
  # }
  #
  config_name "geoiata"
  
  # add location information by refering to the source field in message 
  config :source, :validate => :string, :required => true
  # target field in the event, defaut to geoip, but i should add a tag maybe
  # it's always better to specify the field name
  config :target, :validate => :string, :default =>'geoip'
  # specify which fields of geoinfo you want add into event[@target]
  config :fields, :validate => :array

  
	class City < Struct.new(:airport,:country_code,:is_airport,:city_code,
				:longitude,:latitude,:region_code,:time_zone,:city_name)
		def to_hash
			Hash[each_pair.to_a]
		end
	end

  public
  def register
    # Add instance variables 
  end # def register

  public
  def filter(event)
	if event[@source].nil?
		raise "there's no source provided to find the location"
    	else
		code = event[@source]
    	end
	
	geo_data=get_location_data(code)
	# this code should return a city class object
	
	return if geo_data.nil? || !geo_data.repond_to?(:to_hash)
	
	apply_geo_data(geo_data,event)
	

    # filter_matched should go in the last line of our successful code
    filter_matched(event)
  end # def filter

  def get_location_data(code)

	# connect to database
	db = SQLite3::Database.new "MonitoringLss.db"
#here we can add a cache service of frequent used code , and with the maximum size of cache
	# prepare the query
	stm = db.prepare "SELECT * FROM CRB_CITY WHERE CODE = ? "
	stm.bind_param 1, code
	# we only have one reponse, so we do one time next
	rs = stm.execute
	row = rs.next_hash # if there's no rows, nil will be returned
	# traite the exception
	rescue SQLite3::Exception => e
	puts "exception occured"
	puts e

	# close the connection
	ensure
	stm.close if stm
	db.close if db
	# intialize a new city object (and return)
	if !row.nil?
	City(row['CODE'],row['REL_COUNTRY_CODE'],row['IS_AIRPORT'],row['REL_CITY_CODE'],
	row['LONGITUDE'],row['LATITUDE'],row['REL_REGION_CODE'],
	row['REL_TIME_ZONE_GRP'],row['CITY_NAME'])
	else 
	nil
	end


  end # def get_location_data

  def apply_geo_data(geo_data,event)
	#convert city class to hash
	geo_data_hash=geo_data.to_hash
	#initial event[@target] as an array
	event[@target]={} if event[@target].nil?
	# test if there're both longitude and altitude information
	if geo_data_hash.key?(:latitude) && geo_data_hash.key?(:longitude)
	geo_data_hash[:location] = [geo_data_hash[:longitude].to_f,geo_data_hash[:latitude].to_f]
	else
	# if no geojson type data could form, log this information
	@logger.debug? and @logger.debug("don't have geopoint type info")
	end
	# write each pair to sub field of event[@target]
	geo_data_hash.each do |key,value|
		next if value.nil? ||(value.is_a(string) && value.empty?)
		if @fields.nil ? || @fields.empty?|| @fields.include?(key.to_s)
		# fields could be specified in the configuration, if there's no fields specified, we add all key_pair of geo_data_hash
		#TODO maybe should consider the encoding form of value
		event[@target][key.to_s]=value
		end# end if fields
	end # each do

  end # def apply_geo_data


end # class LogStash::Filters::Geoiata
